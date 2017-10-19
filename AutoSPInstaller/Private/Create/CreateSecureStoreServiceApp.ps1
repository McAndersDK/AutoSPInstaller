Function CreateSecureStoreServiceApp {
  # Secure Store Service Application will be provisioned even if it's been marked false, if any of these service apps have been requested (and for the correct version of SharePoint), as it's a dependency.
  If ((ShouldIProvision $xmlinput.Configuration.ServiceApps.SecureStoreService -eq $true) -or `
      ((ShouldIProvision $xmlinput.Configuration.EnterpriseServiceApps.ExcelServices -eq $true) -and ($env:SPVer -le "15")) -or `
      (ShouldIProvision $xmlinput.Configuration.EnterpriseServiceApps.VisioService -eq $true) -or `
      (ShouldIProvision $xmlinput.Configuration.EnterpriseServiceApps.PerformancePointService -eq $true) -or `
      (ShouldIProvision $xmlinput.Configuration.ServiceApps.BusinessDataConnectivity -eq $true) -or `
      ((ShouldIProvision $xmlinput.Configuration.OfficeWebApps.ExcelService -eq $true) -and ($xmlinput.Configuration.OfficeWebApps.Install -eq $true)) `
  ) {
      WriteLine
      Try {
          If (!($farmPassphrase) -or ($farmPassphrase -eq "")) {
              $farmPassphrase = GetFarmPassPhrase $xmlinput
          }
          $secureStoreServiceAppName = $xmlinput.Configuration.ServiceApps.SecureStoreService.Name
          $secureStoreServiceAppProxyName = $xmlinput.Configuration.ServiceApps.SecureStoreService.ProxyName
          If ($secureStoreServiceAppName -eq $null) {$secureStoreServiceAppName = "Secure Store Service"}
          If ($secureStoreServiceAppProxyName -eq $null) {$secureStoreServiceAppProxyName = $secureStoreServiceAppName}
          $dbServer = $xmlinput.Configuration.ServiceApps.SecureStoreService.Database.DBServer
          # If we haven't specified a DB Server then just use the default used by the Farm
          If ([string]::IsNullOrEmpty($dbServer)) {
              $dbServer = $xmlinput.Configuration.Farm.Database.DBServer
          }
          $dbPrefix = Get-DBPrefix $xmlinput
          $secureStoreDB = $dbPrefix + $xmlinput.Configuration.ServiceApps.SecureStoreService.Database.Name
          Write-Host -ForegroundColor White " - Provisioning Secure Store Service Application..."
          $applicationPool = Get-HostedServicesAppPool $xmlinput
          # Get the service instance
          $secureStoreServiceInstances = Get-SPServiceInstance | Where-Object {$_.GetType().Equals([Microsoft.Office.SecureStoreService.Server.SecureStoreServiceInstance])}
          $secureStoreServiceInstance = $secureStoreServiceInstances | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
          If (-not $?) { Throw " - Failed to find Secure Store service instance" }
          # Start Service instance
          If ($secureStoreServiceInstance.Status -eq "Disabled") {
              Write-Host -ForegroundColor White " - Starting Secure Store Service Instance..."
              $secureStoreServiceInstance.Provision()
              If (-not $?) { Throw " - Failed to start Secure Store service instance" }
              # Wait
              Write-Host -ForegroundColor Cyan " - Waiting for Secure Store service..." -NoNewline
              While ($secureStoreServiceInstance.Status -ne "Online") {
                  Write-Host -ForegroundColor Cyan "." -NoNewline
                  Start-Sleep 1
                  $secureStoreServiceInstances = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.Office.SecureStoreService.Server.SecureStoreServiceInstance"}
                  $secureStoreServiceInstance = $secureStoreServiceInstances | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
              }
              Write-Host -BackgroundColor Green -ForegroundColor Black $($secureStoreServiceInstance.Status)
          }
          # Create Service Application
          $getSPSecureStoreServiceApplication = Get-SPServiceApplication | Where-Object {$_.GetType().Equals([Microsoft.Office.SecureStoreService.Server.SecureStoreServiceApplication])}
          If ($getSPSecureStoreServiceApplication -eq $null) {
              Write-Host -ForegroundColor White " - Creating Secure Store Service Application..."
              New-SPSecureStoreServiceApplication -Name $secureStoreServiceAppName -PartitionMode:$false -Sharing:$false -DatabaseServer $dbServer -DatabaseName $secureStoreDB -ApplicationPool $($applicationPool.Name) -AuditingEnabled:$true -AuditLogMaxSize 30 | Out-Null
              Write-Host -ForegroundColor White " - Creating Secure Store Service Application Proxy..."
              Get-SPServiceApplication | Where-Object {$_.GetType().Equals([Microsoft.Office.SecureStoreService.Server.SecureStoreServiceApplication])} | New-SPSecureStoreServiceApplicationProxy -Name $secureStoreServiceAppProxyName -DefaultProxyGroup | Out-Null
              Write-Host -ForegroundColor White " - Done creating Secure Store Service Application."
          }
          Else {Write-Host -ForegroundColor White " - Secure Store Service Application already provisioned."}

          $secureStore = Get-SPServiceApplicationProxy | Where-Object {$_.GetType().Equals([Microsoft.Office.SecureStoreService.Server.SecureStoreServiceApplicationProxy])}
          Start-Sleep 5
          Write-Host -ForegroundColor White " - Creating the Master Key..."
          Update-SPSecureStoreMasterKey -ServiceApplicationProxy $secureStore.Id -Passphrase $farmPassphrase
          Start-Sleep 5
          Write-Host -ForegroundColor White " - Creating the Application Key..."
          Update-SPSecureStoreApplicationServerKey -ServiceApplicationProxy $secureStore.Id -Passphrase $farmPassphrase -ErrorAction SilentlyContinue
          Start-Sleep 5
          If (!$?) {
              # Try again...
              Write-Host -ForegroundColor White " - Creating the Application Key (2nd attempt)..."
              Update-SPSecureStoreApplicationServerKey -ServiceApplicationProxy $secureStore.Id -Passphrase $farmPassphrase
          }
      }
      Catch {
          Write-Output $_
          Throw " - Error provisioning secure store application"
      }
      Write-Host -ForegroundColor White " - Done creating/configuring Secure Store Service Application."
      WriteLine
  }
}