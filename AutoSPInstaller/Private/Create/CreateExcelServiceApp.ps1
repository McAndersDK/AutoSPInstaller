Function CreateExcelServiceApp ([xml]$xmlinput) {
  $officeServerPremium = $xmlinput.Configuration.Install.SKU -replace "Enterprise", "1" -replace "Standard", "0"
  If ((ShouldIProvision $xmlinput.Configuration.EnterpriseServiceApps.ExcelServices -eq $true) -and ($env:SPVer -le "15")) {
      WriteLine
      if ($officeServerPremium -eq "1") {
          Try {
              $excelAppName = $xmlinput.Configuration.EnterpriseServiceApps.ExcelServices.Name
              $portalWebApp = $xmlinput.Configuration.WebApplications.WebApplication | Where-Object {$_.Type -eq "Portal"} | Select-Object -First 1
              $portalURL = ($portalWebApp.URL).TrimEnd("/")
              $portalPort = $portalWebApp.Port
              Write-Host -ForegroundColor White " - Provisioning $excelAppName..."
              $applicationPool = Get-HostedServicesAppPool $xmlinput
              Write-Host -ForegroundColor White " - Checking local service instance..."
              # Get the service instance
              $excelServiceInstances = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.Office.Excel.Server.MossHost.ExcelServerWebServiceInstance"}
              $excelServiceInstance = $excelServiceInstances | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
              If (-not $?) { Throw " - Failed to find the service instance" }
              # Start Service instances
              If ($excelServiceInstance.Status -eq "Disabled") {
                  Write-Host -ForegroundColor White " - Starting $($excelServiceInstance.TypeName)..."
                  $excelServiceInstance.Provision()
                  If (-not $?) { Throw " - Failed to start $($excelServiceInstance.TypeName) instance" }
                  # Wait
                  Write-Host -ForegroundColor Cyan " - Waiting for $($excelServiceInstance.TypeName)..." -NoNewline
                  While ($excelServiceInstance.Status -ne "Online") {
                      Write-Host -ForegroundColor Cyan "." -NoNewline
                      Start-Sleep 1
                      $excelServiceInstances = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.Office.Excel.Server.MossHost.ExcelServerWebServiceInstance"}
                      $excelServiceInstance = $excelServiceInstances | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
                  }
                  Write-Host -BackgroundColor Green -ForegroundColor Black ($excelServiceInstance.Status)
              }
              Else {
                  Write-Host -ForegroundColor White " - $($excelServiceInstance.TypeName) already started."
              }
              # Create an Excel Service Application
              If ((Get-SPServiceApplication | Where-Object {$_.GetType().ToString() -eq "Microsoft.Office.Excel.Server.MossHost.ExcelServerWebServiceApplication"}) -eq $null) {
                  # Create Service App
                  Write-Host -ForegroundColor White " - Creating $excelAppName..."
                  # Check if our new cmdlets are available yet,  if not, re-load the SharePoint PS Snapin
                  If (!(Get-Command New-SPExcelServiceApplication -ErrorAction SilentlyContinue)) {
                      Write-Host -ForegroundColor White " - Re-importing SP PowerShell Snapin to enable new cmdlets..."
                      Remove-PSSnapin Microsoft.SharePoint.PowerShell
                      Load-SharePoint-PowerShell
                  }
                  $excelServiceApp = New-SPExcelServiceApplication -name $excelAppName -ApplicationPool $($applicationPool.Name) -Default
                  If (-not $?) { Throw " - Failed to create $excelAppName" }
                  Write-Host -ForegroundColor White " - Configuring service app settings..."
                  Set-SPExcelFileLocation -Identity "http://" -LocationType SharePoint -IncludeChildren -Address $portalURL`:$portalPort -ExcelServiceApplication $excelAppName -ExternalDataAllowed 2 -WorkbookSizeMax 10 | Out-Null
                  $caUrl = (Get-Item -Path "HKLM:\SOFTWARE\Microsoft\Shared Tools\Web Server Extensions\$env:spVer.0\WSS").GetValue("CentralAdministrationURL")
                  New-SPExcelFileLocation -LocationType SharePoint -IncludeChildren -Address $caUrl -ExcelServiceApplication $excelAppName -ExternalDataAllowed 2 -WorkbookSizeMax 10 | Out-Null

                  # Configure unattended accounts, based on:
                  # http://blog.falchionconsulting.com/index.php/2010/10/service-accounts-and-managed-service-accounts-in-sharepoint-2010/
                  If (($xmlinput.Configuration.EnterpriseServiceApps.ExcelServices.UnattendedIDUser) -and ($xmlinput.Configuration.EnterpriseServiceApps.ExcelServices.UnattendedIDPassword)) {
                      Write-Host -ForegroundColor White " - Setting unattended account credentials..."

                      # Reget application to prevent update conflict error message
                      $excelServiceApp = Get-SPExcelServiceApplication

                      # Get account credentials
                      $excelAcct = $xmlinput.Configuration.EnterpriseServiceApps.ExcelServices.UnattendedIDUser
                      $excelAcctPWD = $xmlinput.Configuration.EnterpriseServiceApps.ExcelServices.UnattendedIDPassword
                      If (!($excelAcct) -or $excelAcct -eq "" -or !($excelAcctPWD) -or $excelAcctPWD -eq "") {
                          Write-Host -BackgroundColor Gray -ForegroundColor DarkCyan " - Prompting for Excel Unattended Account:"
                          $unattendedAccount = $host.ui.PromptForCredential("Excel Setup", "Enter Excel Unattended Account Credentials:", "$excelAcct", "NetBiosUserName" )
                      }
                      Else {
                          $secPassword = ConvertTo-SecureString "$excelAcctPWD" -AsPlaintext -Force
                          $unattendedAccount = New-Object System.Management.Automation.PsCredential $excelAcct, $secPassword
                      }

                      # Set the group claim and admin principals
                      $groupClaim = New-SPClaimsPrincipal -Identity "nt authority\authenticated users" -IdentityType WindowsSamAccountName
                      $adminPrincipal = New-SPClaimsPrincipal -Identity "$($env:userdomain)\$($env:username)" -IdentityType WindowsSamAccountName

                      # Set the field values
                      $secureUserName = ConvertTo-SecureString $unattendedAccount.UserName -AsPlainText -Force
                      $securePassword = $unattendedAccount.Password
                      $credentialValues = $secureUserName, $securePassword

                      # Set the Target App Name and create the Target App
                      $name = "$($excelServiceApp.ID)-ExcelUnattendedAccount"
                      Write-Host -ForegroundColor White " - Creating Secure Store Target Application $name..."
                      $secureStoreTargetApp = New-SPSecureStoreTargetApplication -Name $name `
                          -FriendlyName "Excel Services Unattended Account Target App" `
                          -ApplicationType Group `
                          -TimeoutInMinutes 3

                      # Set the account fields
                      $usernameField = New-SPSecureStoreApplicationField -Name "User Name" -Type WindowsUserName -Masked:$false
                      $passwordField = New-SPSecureStoreApplicationField -Name "Password" -Type WindowsPassword -Masked:$false
                      $fields = $usernameField, $passwordField

                      # Get the service context
                      $subId = [Microsoft.SharePoint.SPSiteSubscriptionIdentifier]::Default
                      $context = [Microsoft.SharePoint.SPServiceContext]::GetContext($excelServiceApp.ServiceApplicationProxyGroup, $subId)

                      # Check to see if the Secure Store App already exists
                      $secureStoreApp = Get-SPSecureStoreApplication -ServiceContext $context -Name $name -ErrorAction SilentlyContinue
                      If ($secureStoreApp -eq $null) {
                          # Doesn't exist so create.
                          Write-Host -ForegroundColor White " - Creating Secure Store Application..."
                          $secureStoreApp = New-SPSecureStoreApplication -ServiceContext $context `
                              -TargetApplication $secureStoreTargetApp `
                              -Administrator $adminPrincipal `
                              -CredentialsOwnerGroup $groupClaim `
                              -Fields $fields
                      }
                      # Update the field values
                      Write-Host -ForegroundColor White " - Updating Secure Store Group Credential Mapping..."
                      Update-SPSecureStoreGroupCredentialMapping -Identity $secureStoreApp -Values $credentialValues

                      # Set the unattended service account application ID
                      Set-SPExcelServiceApplication -Identity $excelServiceApp -UnattendedAccountApplicationId $name
                  }
                  Else {
                      Write-Host -ForegroundColor Yellow " - Unattended account credentials not supplied in configuration file - skipping."
                  }
              }
              Else {
                  Write-Host -ForegroundColor White " - $excelAppName already provisioned."
              }
              Write-Host -ForegroundColor White " - Done creating $excelAppName."
          }
          Catch {
              Write-Output $_
              Throw " - Error provisioning Excel Service Application"
          }
      }
      else {
          Write-Warning "You have specified a non-Enterprise SKU in `"$(Split-Path -Path $inputFile -Leaf)`". However, SharePoint requires the Enterprise SKU and corresponding PIDKey to provision Excel Services."
      }
      WriteLine
  }
}