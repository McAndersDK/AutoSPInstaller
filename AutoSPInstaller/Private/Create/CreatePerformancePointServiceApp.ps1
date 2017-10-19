Function CreatePerformancePointServiceApp ([xml]$xmlinput) {
  $officeServerPremium = $xmlinput.Configuration.Install.SKU -replace "Enterprise", "1" -replace "Standard", "0"
  $serviceConfig = $xmlinput.Configuration.EnterpriseServiceApps.PerformancePointService
  If (ShouldIProvision $serviceConfig -eq $true) {
      WriteLine
      if ($officeServerPremium -eq "1") {
          $dbServer = $serviceConfig.Database.DBServer
          # If we haven't specified a DB Server then just use the default used by the Farm
          If ([string]::IsNullOrEmpty($dbServer)) {
              $dbServer = $xmlinput.Configuration.Farm.Database.DBServer
          }
          $dbPrefix = Get-DBPrefix $xmlinput
          $serviceDB = $dbPrefix + $serviceConfig.Database.Name
          $serviceInstanceType = "Microsoft.PerformancePoint.Scorecards.BIMonitoringServiceInstance"
          CreateGenericServiceApplication -ServiceConfig $serviceConfig `
              -ServiceInstanceType $serviceInstanceType `
              -ServiceName $serviceConfig.Name `
              -ServiceProxyName $serviceConfig.ProxyName `
              -ServiceGetCmdlet "Get-SPPerformancePointServiceApplication" `
              -ServiceProxyGetCmdlet "Get-SPServiceApplicationProxy" `
              -ServiceNewCmdlet "New-SPPerformancePointServiceApplication" `
              -ServiceProxyNewCmdlet "New-SPPerformancePointServiceApplicationProxy"

          $application = Get-SPPerformancePointServiceApplication | Where-Object {$_.Name -eq $serviceConfig.Name}
          If ($application) {
              $farmAcct = $xmlinput.Configuration.Farm.Account.Username
              Write-Host -ForegroundColor White " - Granting $farmAcct rights to database $serviceDB..."
              Get-SPDatabase | Where-Object {$_.Name -eq $serviceDB} | Add-SPShellAdmin -UserName $farmAcct
              Write-Host -ForegroundColor White " - Setting PerformancePoint Data Source Unattended Service Account..."
              $performancePointAcct = $serviceConfig.UnattendedIDUser
              $performancePointAcctPWD = $serviceConfig.UnattendedIDPassword
              If (!($performancePointAcct) -or $performancePointAcct -eq "" -or !($performancePointAcctPWD) -or $performancePointAcctPWD -eq "") {
                  Write-Host -BackgroundColor Gray -ForegroundColor DarkCyan " - Prompting for PerformancePoint Unattended Service Account:"
                  $performancePointCredential = $host.ui.PromptForCredential("PerformancePoint Setup", "Enter PerformancePoint Unattended Account Credentials:", "$performancePointAcct", "NetBiosUserName" )
              }
              Else {
                  $secPassword = ConvertTo-SecureString "$performancePointAcctPWD" -AsPlaintext -Force
                  $performancePointCredential = New-Object System.Management.Automation.PsCredential $performancePointAcct, $secPassword
              }
              $application | Set-SPPerformancePointSecureDataValues -DataSourceUnattendedServiceAccount $performancePointCredential

              If (!(CheckFor2010SP1)) {
                  # Only need this if our environment isn't up to Service Pack 1 for SharePoint 2010
                  # Rename the performance point service application database
                  Write-Host -ForegroundColor White " - Renaming Performance Point Service Application Database"
                  $settingsDB = $application.SettingsDatabase
                  $newDB = $serviceDB
                  $sqlServer = ($settingsDB -split "\\\\")[0]
                  $oldDB = ($settingsDB -split "\\\\")[1]
                  If (!($newDB -eq $oldDB)) {
                      # Check if it's already been renamed, in case we're running the script again
                      Write-Host -ForegroundColor White " - Renaming Performance Point Service Application Database"
                      RenameDatabase -sqlServer $sqlServer -oldName $oldDB -newName $newDB
                      Set-SPPerformancePointServiceApplication  -Identity $serviceConfig.Name -SettingsDatabase $newDB | Out-Null
                  }
                  Else {
                      Write-Host -ForegroundColor White " - Database already named: $newDB"
                  }
              }
          }
      }
      else {
          Write-Warning " You have specified a non-Enterprise SKU in `"$(Split-Path -Path $inputFile -Leaf)`". However, SharePoint requires the Enterprise SKU and corresponding PIDKey to provision PerformancePoint Services."
      }
      WriteLine
  }
}