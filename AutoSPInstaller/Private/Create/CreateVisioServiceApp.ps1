Function CreateVisioServiceApp ([xml]$xmlinput) {
  $officeServerPremium = $xmlinput.Configuration.Install.SKU -replace "Enterprise", "1" -replace "Standard", "0"
  $serviceConfig = $xmlinput.Configuration.EnterpriseServiceApps.VisioService
  If (ShouldIProvision $serviceConfig -eq $true) {
      WriteLine
      if ($officeServerPremium -eq "1") {
          $serviceInstanceType = "Microsoft.Office.Visio.Server.Administration.VisioGraphicsServiceInstance"
          CreateGenericServiceApplication -ServiceConfig $serviceConfig `
              -ServiceInstanceType $serviceInstanceType `
              -ServiceName $serviceConfig.Name `
              -ServiceProxyName $serviceConfig.ProxyName `
              -ServiceGetCmdlet "Get-SPVisioServiceApplication" `
              -ServiceProxyGetCmdlet "Get-SPVisioServiceApplicationProxy" `
              -ServiceNewCmdlet "New-SPVisioServiceApplication" `
              -ServiceProxyNewCmdlet "New-SPVisioServiceApplicationProxy"

          If (Get-Command -Name Get-SPVisioServiceApplication -ErrorAction SilentlyContinue) {
              # http://blog.falchionconsulting.com/index.php/2010/10/service-accounts-and-managed-service-accounts-in-sharepoint-2010/
              If ($serviceConfig.UnattendedIDUser -and $serviceConfig.UnattendedIDPassword) {
                  Write-Host -ForegroundColor White " - Setting unattended account credentials..."

                  $serviceApplication = Get-SPServiceApplication -name $serviceConfig.Name

                  # Get account credentials
                  $visioAcct = $xmlinput.Configuration.EnterpriseServiceApps.VisioService.UnattendedIDUser
                  $visioAcctPWD = $xmlinput.Configuration.EnterpriseServiceApps.VisioService.UnattendedIDPassword
                  If (!($visioAcct) -or $visioAcct -eq "" -or !($visioAcctPWD) -or $visioAcctPWD -eq "") {
                      Write-Host -BackgroundColor Gray -ForegroundColor DarkCyan " - Prompting for Visio Unattended Account:"
                      $unattendedAccount = $host.ui.PromptForCredential("Visio Setup", "Enter Visio Unattended Account Credentials:", "$visioAcct", "NetBiosUserName" )
                  }
                  Else {
                      $secPassword = ConvertTo-SecureString "$visioAcctPWD" -AsPlaintext -Force
                      $unattendedAccount = New-Object System.Management.Automation.PsCredential $visioAcct, $secPassword
                  }

                  # Set the group claim and admin principals
                  $groupClaim = New-SPClaimsPrincipal -Identity "nt authority\authenticated users" -IdentityType WindowsSamAccountName
                  $adminPrincipal = New-SPClaimsPrincipal -Identity "$($env:userdomain)\$($env:username)" -IdentityType WindowsSamAccountName

                  # Set the field values
                  $secureUserName = ConvertTo-SecureString $unattendedAccount.UserName -AsPlainText -Force
                  $securePassword = $unattendedAccount.Password
                  $credentialValues = $secureUserName, $securePassword

                  # Set the Target App Name and create the Target App
                  $name = "$($serviceApplication.ID)-VisioUnattendedAccount"
                  Write-Host -ForegroundColor White " - Creating Secure Store Target Application $name..."
                  $secureStoreTargetApp = New-SPSecureStoreTargetApplication -Name $name `
                      -FriendlyName "Visio Services Unattended Account Target App" `
                      -ApplicationType Group `
                      -TimeoutInMinutes 3

                  # Set the account fields
                  $usernameField = New-SPSecureStoreApplicationField -Name "User Name" -Type WindowsUserName -Masked:$false
                  $passwordField = New-SPSecureStoreApplicationField -Name "Password" -Type WindowsPassword -Masked:$false
                  $fields = $usernameField, $passwordField

                  # Get the service context
                  $subId = [Microsoft.SharePoint.SPSiteSubscriptionIdentifier]::Default
                  $context = [Microsoft.SharePoint.SPServiceContext]::GetContext($serviceApplication.ServiceApplicationProxyGroup, $subId)

                  # Check to see if the Secure Store App already exists
                  $secureStoreApp = Get-SPSecureStoreApplication -ServiceContext $context -Name $name -ErrorAction SilentlyContinue
                  If (!($secureStoreApp)) {
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
                  Write-Host -ForegroundColor White " - Setting Application ID for Visio Service..."
                  $serviceApplication | Set-SPVisioExternalData -UnattendedServiceAccountApplicationID $name
              }
              Else {
                  Write-Host -ForegroundColor Yellow " - Unattended account credentials not supplied in configuration file - skipping."
              }
          }
      }
      else {
          Write-Warning "You have specified a non-Enterprise SKU in `"$(Split-Path -Path $inputFile -Leaf)`". However, SharePoint requires the Enterprise SKU and corresponding PIDKey to provision Visio Services."
      }
      WriteLine
  }

}