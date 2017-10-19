# ===================================================================================
# Func: CreateUserProfileServiceApplication
# Desc: Create the User Profile Service Application
# ===================================================================================
Function CreateUserProfileServiceApplication([xml]$xmlinput) {
  # Based on http://sharepoint.microsoft.com/blogs/zach/Lists/Posts/Post.aspx?ID=50
  Try {
      Get-MajorVersionNumber $xmlinput
      $userProfile = $xmlinput.Configuration.ServiceApps.UserProfileServiceApp
      $mySiteWebApp = $xmlinput.Configuration.WebApplications.WebApplication | Where-Object {$_.Type -eq "MySiteHost"}
      $dbPrefix = Get-DBPrefix $xmlinput
      # If we have asked to create a MySite Host web app, use that as the MySite host location
      if ($mySiteWebApp) {
          $mySiteName = $mySiteWebApp.name
          $mySiteURL = ($mySiteWebApp.url).TrimEnd("/")
          $mySitePort = $mySiteWebApp.port
          $mySiteDBServer = $mySiteWebApp.Database.DBServer
          # If we haven't specified a DB Server then just use the default used by the Farm
          If ([string]::IsNullOrEmpty($mySiteDBServer)) {
              $mySiteDBServer = $xmlinput.Configuration.Farm.Database.DBServer
          }
          $mySiteDB = $dbPrefix + $mySiteWebApp.Database.Name
          $mySiteAppPoolAcct = Get-SPManagedAccountXML $xmlinput -CommonName "MySiteHost"
          if ([string]::IsNullOrEmpty($mySiteAppPoolAcct.username)) {throw " - `"MySiteHost`" managed account not found! Check your XML."}
      }
      $portalWebApp = $xmlinput.Configuration.WebApplications.WebApplication | Where-Object {$_.Type -eq "Portal"} | Select-Object -First 1
      $portalAppPoolAcct = Get-SPManagedAccountXML $xmlinput -CommonName "Portal"
      if ([string]::IsNullOrEmpty($portalAppPoolAcct.username)) {throw " - `"Portal`" managed account not found! Check your XML."}
      $farmAcct = $xmlinput.Configuration.Farm.Account.Username
      $farmAcctPWD = $xmlinput.Configuration.Farm.Account.Password
      # Get the content access accounts of each Search Service Application in the XML (in case there are multiple)
      foreach ($searchServiceApplication in $xmlinput.Configuration.ServiceApps.EnterpriseSearchService.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication) {
          [array]$contentAccessAccounts += $searchServiceApplication.ContentAccessAccount
      }
      If (($farmAcctPWD -ne "") -and ($farmAcctPWD -ne $null)) {$farmAcctPWD = (ConvertTo-SecureString $farmAcctPWD -AsPlainText -force)}
      $mySiteTemplate = $mySiteWebApp.SiteCollections.SiteCollection.Template
      $mySiteLCID = $mySiteWebApp.SiteCollections.SiteCollection.LCID
      $userProfileServiceName = $userProfile.Name
      $userProfileServiceProxyName = $userProfile.ProxyName
      $spservice = Get-SPManagedAccountXML $xmlinput -CommonName "spservice"
      If ($userProfileServiceName -eq $null) {$userProfileServiceName = "User Profile Service Application"}
      If ($userProfileServiceProxyName -eq $null) {$userProfileServiceProxyName = $userProfileServiceName}
      If (!$farmCredential) {[System.Management.Automation.PsCredential]$farmCredential = GetFarmCredentials $xmlinput}
      if (((Get-WmiObject Win32_OperatingSystem).Version -like "6.2*" -or (Get-WmiObject Win32_OperatingSystem).Version -like "6.3*") -and ($env:spVer -eq "14")) {
          Write-Host -ForegroundColor White " - Skipping setting the web app directory path name (not currently working on Windows 2012 w/SP2010)..."
          $pathSwitch = @{}
      }
      else {
          # Set the directory path for the web app to something a bit more friendly
          ImportWebAdministration
          # Get the default root location for web apps (first from IIS itself, then failing that, from the registry)
          $iisWebDir = (Get-ItemProperty "IIS:\Sites\Default Web Site\" -Name physicalPath -ErrorAction SilentlyContinue) -replace ("%SystemDrive%", "$env:SystemDrive")
          if ([string]::IsNullOrEmpty($iisWebDir)) {
              $iisWebDir = (Get-Item -Path HKLM:\SOFTWARE\Microsoft\InetStp).GetValue("PathWWWRoot") -replace ("%SystemDrive%", "$env:SystemDrive")
          }
          If (!([string]::IsNullOrEmpty($iisWebDir))) {
              $pathSwitch = @{Path = "$iisWebDir\wss\VirtualDirectories\$webAppName-$port"}
          }
          else {$pathSwitch = @{}
          }
      }
      # Only set $hostHeaderSwitch to blank if the UseHostHeader value exists has explicitly been set to false
      if (!([string]::IsNullOrEmpty($webApp.UseHostHeader)) -and $webApp.UseHostHeader -eq $false) {
          $hostHeaderSwitch = @{}
      }
      else {$hostHeaderSwitch = @{HostHeader = $hostHeader}
      }

      If ((ShouldIProvision $userProfile -eq $true) -and (Get-Command -Name New-SPProfileServiceApplication -ErrorAction SilentlyContinue)) {
          WriteLine
          Write-Host -ForegroundColor White " - Provisioning $($userProfile.Name)"
          $applicationPool = Get-HostedServicesAppPool $xmlinput
          # get the service instance
          $profileServiceInstances = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.Office.Server.Administration.UserProfileServiceInstance"}
          $profileServiceInstance = $profileServiceInstances | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
          If (-not $?) { Throw " - Failed to find User Profile Service instance" }
          # Start Service instance
          Write-Host -ForegroundColor White " - Starting User Profile Service instance..."
          If (($profileServiceInstance.Status -eq "Disabled") -or ($profileServiceInstance.Status -ne "Online")) {
              $profileServiceInstance.Provision()
              If (-not $?) { Throw " - Failed to start User Profile Service instance" }
              # Wait
              Write-Host -ForegroundColor Cyan " - Waiting for User Profile Service..." -NoNewline
              While ($profileServiceInstance.Status -ne "Online") {
                  Write-Host -ForegroundColor Cyan "." -NoNewline
                  Start-Sleep 1
                  $profileServiceInstances = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.Office.Server.Administration.UserProfileServiceInstance"}
                  $profileServiceInstance = $profileServiceInstances | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
              }
              Write-Host -BackgroundColor Green -ForegroundColor Black $($profileServiceInstance.Status)
          }
          # Create a Profile Service Application
          If ((Get-SPServiceApplication | Where-Object {$_.GetType().ToString() -eq "Microsoft.Office.Server.Administration.UserProfileApplication"}) -eq $null) {
              # Create MySites Web Application if it doesn't already exist, and we've specified to create one
              $getSPWebApplication = Get-SPWebApplication | Where-Object {$_.DisplayName -eq $mySiteName}
              If ($getSPWebApplication -eq $null -and ($mySiteWebApp)) {
                  Write-Host -ForegroundColor White " - Creating Web App `"$mySiteName`"..."
                  New-SPWebApplication -Name $mySiteName -ApplicationPoolAccount $($mySiteAppPoolAcct.username) -ApplicationPool $mySiteAppPool -DatabaseServer $mySiteDBServer -DatabaseName $mySiteDB -Url $mySiteURL -Port $mySitePort -SecureSocketsLayer:$mySiteUseSSL @hostHeaderSwitch @pathSwitch | Out-Null
              }
              Else {
                  Write-Host -ForegroundColor White " - My Site host already provisioned."
              }

              # Create MySites Site Collection
              If ((Get-SPContentDatabase | Where-Object {$_.Name -eq $mySiteDB}) -eq $null -and ($mySiteWebApp)) {
                  Write-Host -ForegroundColor White " - Creating My Sites content DB..."
                  $newMySitesDB = New-SPContentDatabase -DatabaseServer $mySiteDBServer -Name $mySiteDB -WebApplication "$mySiteURL`:$mySitePort"
                  If (-not $?) { Throw " - Failed to create My Sites content DB" }
              }
              If (!(Get-SPSite -Limit ALL | Where-Object {(($_.Url -like "$mySiteURL*") -and ($_.Port -eq "$mySitePort"))}) -and ($mySiteWebApp)) {
                  Write-Host -ForegroundColor White " - Creating My Sites site collection $mySiteURL`:$mySitePort..."
                  # Verify that the Language we're trying to create the site in is currently installed on the server
                  $mySiteCulture = [System.Globalization.CultureInfo]::GetCultureInfo(([convert]::ToInt32($mySiteLCID)))
                  $mySiteCultureDisplayName = $mySiteCulture.DisplayName
                  $installedOfficeServerLanguages = (Get-Item "HKLM:\Software\Microsoft\Office Server\$env:spVer.0\InstalledLanguages").GetValueNames() | Where-Object {$_ -ne ""}
                  If (!($installedOfficeServerLanguages | Where-Object {$_ -eq $mySiteCulture.Name})) {
                      Throw " - You must install the `"$mySiteCulture ($mySiteCultureDisplayName)`" Language Pack before you can create a site using LCID $mySiteLCID"
                  }
                  Else {
                      $newMySitesCollection = New-SPSite -Url "$mySiteURL`:$mySitePort" -OwnerAlias $farmAcct -SecondaryOwnerAlias $env:USERDOMAIN\$env:USERNAME -ContentDatabase $mySiteDB -Description $mySiteName -Name $mySiteName -Template $mySiteTemplate -Language $mySiteLCID | Out-Null
                      If (-not $?) {Throw " - Failed to create My Sites site collection"}
                      # Assign SSL certificate, if required
                      If ($mySiteUseSSL) {
                          # Strip out any protocol and/or port values
                          $SSLHostHeader, $null = $mySiteHostLocation -replace "http://", "" -replace "https://", "" -split ":"
                          $SSLPort = $mySitePort
                          $SSLSiteName = $mySiteName
                          if (((Get-WmiObject Win32_OperatingSystem).Version -like "6.2*" -or (Get-WmiObject Win32_OperatingSystem).Version -like "6.3*") -and ($env:spVer -eq "14")) {
                              Write-Host -ForegroundColor White " - Assigning certificate(s) in a separate PowerShell window..."
                              Start-Process -FilePath "$PSHOME\powershell.exe" -Verb RunAs -ArgumentList "-Command `". $env:dp0\AutoSPInstallerFunctions.ps1`; AssignCert $SSLHostHeader $SSLPort $SSLSiteName; Start-Sleep 10`"" -Wait
                          }
                          else {AssignCert $SSLHostHeader $SSLPort $SSLSiteName}
                      }
                  }
              }

              # Create Service App
              Write-Host -ForegroundColor White " - Creating $userProfileServiceName..."
              CreateUPSAsAdmin $xmlinput
              Write-Host -ForegroundColor Cyan " - Waiting for $userProfileServiceName..." -NoNewline
              $profileServiceApp = Get-SPServiceApplication | Where-Object {$_.DisplayName -eq $userProfileServiceName}
              While ($profileServiceApp.Status -ne "Online") {
                  [int]$UPSWaitTime = 0
                  # Wait 2 minutes for either the UPS to be created, or the UAC prompt to time out
                  While (($UPSWaitTime -lt 120) -and ($profileServiceApp.Status -ne "Online")) {
                      Write-Host -ForegroundColor Cyan "." -NoNewline
                      Start-Sleep 1
                      $profileServiceApp = Get-SPServiceApplication | Where-Object {$_.DisplayName -eq $userProfileServiceName}
                      [int]$UPSWaitTime += 1
                  }
                  # If it still isn't Online after 2 minutes, prompt to try again
                  If (!($profileServiceApp)) {
                      Write-Host -ForegroundColor Cyan "."
                      Write-Warning "Timed out waiting for service creation (maybe a UAC prompt?)"
                      Write-Host "`a`a`a" # System beeps
                      Pause "try again"
                      CreateUPSAsAdmin $xmlinput
                      Write-Host -ForegroundColor Cyan " - Waiting for $userProfileServiceName..." -NoNewline
                      $profileServiceApp = Get-SPServiceApplication | Where-Object {$_.DisplayName -eq $userProfileServiceName}
                  }
                  Else {break}
              }
              Write-Host -BackgroundColor Green -ForegroundColor Black $($profileServiceApp.Status)
              # Wait a few seconds for the CreateUPSAsAdmin function to complete
              Start-Sleep 30

              # Get our new Profile Service App
              $profileServiceApp = Get-SPServiceApplication | Where-Object {$_.DisplayName -eq $userProfileServiceName}
              If (!($profileServiceApp)) {Throw " - Could not get $userProfileServiceName!"; }

              # Create Proxy
              Write-Host -ForegroundColor White " - Creating $userProfileServiceName Proxy..."
              $profileServiceAppProxy = New-SPProfileServiceApplicationProxy -Name "$userProfileServiceProxyName" -ServiceApplication $profileServiceApp -DefaultProxyGroup
              If (-not $?) { Throw " - Failed to create $userProfileServiceName Proxy" }

              Write-Host -ForegroundColor White " - Granting rights to ($userProfileServiceName):"
              # Create a variable that contains the guid for the User Profile service for which you want to delegate permissions
              $serviceAppIDToSecure = Get-SPServiceApplication $($profileServiceApp.Id)

              # Create a variable that contains the list of administrators for the service application
              $profileServiceAppSecurity = Get-SPServiceApplicationSecurity $serviceAppIDToSecure -Admin
              # Create a variable that contains the permissions for the service application
              $profileServiceAppPermissions = Get-SPServiceApplicationSecurity $serviceAppIDToSecure

              # Create variables that contains the claims principals for current (Setup) user, genral service account, MySite App Pool, Portal App Pool and Content Access accounts
              # Then give 'Full Control' permissions to the current (Setup) user, general service account, MySite App Pool, Portal App Pool account and content access account claims principals
              $currentUserAcctPrincipal = New-SPClaimsPrincipal -Identity $env:USERDOMAIN\$env:USERNAME -IdentityType WindowsSamAccountName
              $spServiceAcctPrincipal = New-SPClaimsPrincipal -Identity $($spservice.username) -IdentityType WindowsSamAccountName
              Grant-SPObjectSecurity $profileServiceAppSecurity -Principal $currentUserAcctPrincipal -Rights "Full Control"
              Grant-SPObjectSecurity $profileServiceAppPermissions -Principal $currentUserAcctPrincipal -Rights "Full Control"
              Grant-SPObjectSecurity $profileServiceAppPermissions -Principal $spServiceAcctPrincipal -Rights "Full Control"
              If ($mySiteAppPoolAcct) {
                  Write-Host -ForegroundColor White "  - $($mySiteAppPoolAcct.username)..."
                  $mySiteAppPoolAcctPrincipal = New-SPClaimsPrincipal -Identity $($mySiteAppPoolAcct.username) -IdentityType WindowsSamAccountName
                  Grant-SPObjectSecurity $profileServiceAppSecurity -Principal $mySiteAppPoolAcctPrincipal -Rights "Full Control"
              }
              If ($portalAppPoolAcct) {
                  Write-Host -ForegroundColor White "  - $($portalAppPoolAcct.username)..."
                  $portalAppPoolAcctPrincipal = New-SPClaimsPrincipal -Identity $($portalAppPoolAcct.username) -IdentityType WindowsSamAccountName
                  Grant-SPObjectSecurity $profileServiceAppSecurity -Principal $portalAppPoolAcctPrincipal -Rights "Full Control"
              }
              If ($contentAccessAccounts) {
                  foreach ($contentAccessAcct in $contentAccessAccounts) {
                      # Give 'Retrieve People Data for Search Crawlers' permissions to the Content Access claims principal
                      Write-Host -ForegroundColor White "  - $contentAccessAcct..."
                      $contentAccessAcctPrincipal = New-SPClaimsPrincipal -Identity $contentAccessAcct -IdentityType WindowsSamAccountName
                      Grant-SPObjectSecurity $profileServiceAppSecurity -Principal $contentAccessAcctPrincipal -Rights "Retrieve People Data for Search Crawlers"
                  }
              }

              # Apply the changes to the User Profile service application
              Set-SPServiceApplicationSecurity $serviceAppIDToSecure -objectSecurity $profileServiceAppSecurity -Admin
              Set-SPServiceApplicationSecurity $serviceAppIDToSecure -objectSecurity $profileServiceAppPermissions
              Write-Host -ForegroundColor White " - Done granting rights."

              # Add link to resources list
              AddResourcesLink "User Profile Administration" ("_layouts/ManageUserProfileServiceApplication.aspx?ApplicationID=" + $profileServiceApp.Id)

              If ($portalAppPoolAcct) {
                  # Grant the Portal App Pool account rights to the Profile and Social DBs
                  $profileDB = $dbPrefix + $userProfile.Database.ProfileDB
                  $socialDB = $dbPrefix + $userProfile.Database.SocialDB
                  Write-Host -ForegroundColor White " - Granting $($portalAppPoolAcct.username) rights to $mySiteDB..."
                  Get-SPDatabase | Where-Object {$_.Name -eq $mySiteDB} | Add-SPShellAdmin -UserName $($portalAppPoolAcct.username)
                  Write-Host -ForegroundColor White " - Granting $($portalAppPoolAcct.username) rights to $profileDB..."
                  Get-SPDatabase | Where-Object {$_.Name -eq $profileDB} | Add-SPShellAdmin -UserName $($portalAppPoolAcct.username)
                  Write-Host -ForegroundColor White " - Granting $($portalAppPoolAcct.username) rights to $socialDB..."
                  Get-SPDatabase | Where-Object {$_.Name -eq $socialDB} | Add-SPShellAdmin -UserName $($portalAppPoolAcct.username)
              }
              Write-Host -ForegroundColor White " - Enabling the Activity Feed Timer Job.."
              If ($profileServiceApp) {Get-SPTimerJob | Where-Object {$_.TypeName -eq "Microsoft.Office.Server.ActivityFeed.ActivityFeedUPAJob"} | Enable-SPTimerJob}

              Write-Host -ForegroundColor White " - Done creating $userProfileServiceName."
          }
          # Start User Profile Synchronization Service
          # Get User Profile Service
          $profileServiceApp = Get-SPServiceApplication | Where-Object {$_.DisplayName -eq $userProfileServiceName}
          If ($profileServiceApp -and ($userProfile.StartProfileSync -eq $true)) {
              If ($userProfile.EnableNetBIOSDomainNames -eq $true) {
                  Write-Host -ForegroundColor White " - Enabling NetBIOS domain names for $userProfileServiceName..."
                  $profileServiceApp.NetBIOSDomainNamesEnabled = 1
                  $profileServiceApp.Update()
              }
              # Get User Profile Synchronization Service
              Write-Host -ForegroundColor White " - Checking User Profile Synchronization Service..." -NoNewline
              if ($env:SPVer -lt "16") {
                  # Since User Profile Sync seems to only apply to SP2010/2013
                  $profileSyncServices = @(Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.Office.Server.Administration.ProfileSynchronizationServiceInstance"})
                  $profileSyncService = $profileSyncServices | Where-Object {MatchComputerName $_.Parent.Address $env:COMPUTERNAME}
                  # Attempt to start only if there are no online Profile Sync Service instances in the farm as we don't want to start multiple Sync instances (running against the same Profile Service at least)
                  If (!($profileSyncServices | Where-Object {$_.Status -eq "Online"})) {
                      # Inspired by http://technet.microsoft.com/en-us/library/ee721049.aspx
                      If (!($farmAcct)) {$farmAcct = (Get-SPFarm).DefaultServiceAccount}
                      If (!($farmAcctPWD)) {
                          Write-Host -ForegroundColor White "`n"
                          $farmAcctPWD = Read-Host -Prompt " - Please (re-)enter the Farm Account Password" -AsSecureString
                      }
                      Write-Host -ForegroundColor White "`n"
                      # Check for an existing UPS credentials timer job (e.g. from a prior provisioning attempt), and delete it
                      $UPSCredentialsJob = Get-SPTimerJob | Where-Object {$_.Name -eq "windows-service-credentials-FIMSynchronizationService"}
                      If ($UPSCredentialsJob.Status -eq "Online") {
                          Write-Host -ForegroundColor White " - Deleting existing sync credentials timer job..."
                          $UPSCredentialsJob.Delete()
                      }
                      UpdateProcessIdentity $profileSyncService
                      $profileSyncService.Update()
                      Write-Host -ForegroundColor White " - Waiting for User Profile Synchronization Service..." -NoNewline
                      # Provision the User Profile Sync Service
                      $profileServiceApp.SetSynchronizationMachine($env:COMPUTERNAME, $profileSyncService.Id, $farmAcct, (ConvertTo-PlainText $farmAcctPWD))
                      If (($profileSyncService.Status -ne "Provisioning") -and ($profileSyncService.Status -ne "Online")) {Write-Host -ForegroundColor Cyan "`n - Waiting for User Profile Synchronization Service to start..." -NoNewline}
                      # Monitor User Profile Sync service status
                      While ($profileSyncService.Status -ne "Online") {
                          While ($profileSyncService.Status -ne "Provisioning") {
                              Write-Host -ForegroundColor Cyan "." -NoNewline
                              Start-Sleep 1
                              $profileSyncService = @(Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.Office.Server.Administration.ProfileSynchronizationServiceInstance"}) | Where-Object {MatchComputerName $_.Parent.Address $env:COMPUTERNAME}
                          }
                          If ($profileSyncService.Status -eq "Provisioning") {
                              Write-Host -BackgroundColor Green -ForegroundColor Black $($profileSyncService.Status)
                              Write-Host -ForegroundColor Cyan " - Provisioning User Profile Sync Service, please wait..." -NoNewline
                          }
                          While ($profileSyncService.Status -eq "Provisioning" -and $profileSyncService.Status -ne "Disabled") {
                              Write-Host -ForegroundColor Cyan "." -NoNewline
                              Start-Sleep 1
                              $profileSyncService = @(Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.Office.Server.Administration.ProfileSynchronizationServiceInstance"}) | Where-Object {MatchComputerName $_.Parent.Address $env:COMPUTERNAME}
                          }
                          If ($profileSyncService.Status -ne "Online") {
                              Write-Host -ForegroundColor Red ".`a`a"
                              Write-Host -BackgroundColor Red -ForegroundColor Black " - User Profile Synchronization Service could not be started!"
                              break
                          }
                          Else {
                              Write-Host -BackgroundColor Green -ForegroundColor Black $($profileSyncService.Status)
                              # Need to recycle the Central Admin app pool before we can do anything with the User Profile Sync Service
                              Write-Host -ForegroundColor White " - Recycling Central Admin app pool..."
                              # From http://sharepoint.nauplius.net/2011/09/iisreset-not-required-after-starting.html
                              $appPool = gwmi -Namespace "root\MicrosoftIISv2" -class "IIsApplicationPool" | Where-Object {$_.Name -eq "W3SVC/APPPOOLS/SharePoint Central Administration v4"}
                              If ($appPool) {
                                  $appPool.Recycle()
                              }
                              $newlyProvisionedSync = $true
                          }
                      }

                      # Attempt to create a sync connection only on a successful, newly-provisioned User Profile Sync service
                      # We don't have the ability to check for existing connections and we don't want to overwrite/duplicate any existing sync connections
                      # Note that this isn't really supported anyhow, and that only SharePoint 2010 Service Pack 1 and above includes the Add-SPProfileSyncConnection cmdlet
                      If ((CheckFor2010SP1) -and ($userProfile.CreateDefaultSyncConnection -eq $true) -and ($newlyProvisionedSync -eq $true)) {
                          Write-Host -ForegroundColor White " - Creating a default Profile Sync connection..."
                          $profileServiceApp = Get-SPServiceApplication | Where-Object {$_.DisplayName -eq $userProfileServiceName}
                          # Thanks to Codeplex user Reshetkov for this ingenious one-liner to build the default domain OU
                          $connectionSyncOU = "DC=" + $env:USERDNSDOMAIN -replace "\.", ",DC="
                          $syncConnectionDomain, $syncConnectionAcct = ($userProfile.SyncConnectionAccount) -split "\\"
                          $addProfileSyncCmd = @"
Add-PsSnapin Microsoft.SharePoint.PowerShell
Write-Host -ForegroundColor White " - Creating default Sync connection..."
`$syncConnectionAcctPWD = (ConvertTo-SecureString -String `'$($userProfile.SyncConnectionAccountPassword)`' -AsPlainText -Force)
Add-SPProfileSyncConnection -ProfileServiceApplication $($profileServiceApp.Id) -ConnectionForestName $env:USERDNSDOMAIN -ConnectionDomain $syncConnectionDomain -ConnectionUserName "$syncConnectionAcct" -ConnectionSynchronizationOU "$connectionSyncOU" -ConnectionPassword `$syncConnectionAcctPWD
If (!`$?)
{
Write-Host "Press any key to exit..."
`$null = `$host.UI.RawUI.ReadKey(`"NoEcho,IncludeKeyDown`")
}
Else {Write-Host -ForegroundColor White " - Done.";Start-Sleep 15}
"@
                          $addProfileScriptFile = "$((Get-Item $env:TEMP).FullName)\AutoSPInstaller-AddProfileSyncCmd.ps1"
                          $addProfileSyncCmd | Out-File $addProfileScriptFile
                          if (((Get-WmiObject Win32_OperatingSystem).Version -like "6.2*" -or (Get-WmiObject Win32_OperatingSystem).Version -like "6.3*") -and ($env:spVer -eq "14")) {
                              $versionSwitch = "-Version 2"
                          }
                          else {$versionSwitch = ""}
                          # Run our Add-SPProfileSyncConnection script as the Farm Account - doesn't seem to work otherwise
                          Start-Process -WorkingDirectory $PSHOME -FilePath "powershell.exe" -Credential $farmCredential -ArgumentList "-ExecutionPolicy Bypass -Command Start-Process -WorkingDirectory `"'$PSHOME'`" -FilePath `"'powershell.exe'`" -ArgumentList `"'$versionSwitch -ExecutionPolicy Bypass $addProfileScriptFile'`" -Verb Runas" -Wait
                          # Give Add-SPProfileSyncConnection time to complete before continuing
                          Start-Sleep 120
                          Remove-Item -LiteralPath $addProfileScriptFile -Force -ErrorAction SilentlyContinue
                      }
                  }
                  Else {Write-Host -ForegroundColor White "Already started."}
                  # Make the FIM services dependent on the SQL Server service if we are provisioning User Profile Sync and SQL is co-located with SharePoint on this machine
                  $dbServerUPSA = $xmlinput.Configuration.ServiceApps.UserProfileServiceApp.Database.DBServer
                  if ([string]::IsNullOrEmpty($dbServerUPSA)) {
                      $dbServerUPSA = $xmlinput.Configuration.Farm.Database.DBServer
                  }
                  $upAlias = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\MSSQLServer\Client\ConnectTo" -Name $dbServerUPSA -ErrorAction SilentlyContinue
                  # Grab the values for the SQL alias, if one exists
                  $upDBInstance = $upAlias.$dbServerUPSA
                  if ([string]::IsNullOrEmpty($upDBInstance)) {
                      # Alias not found; maybe we are using an actual machine name
                      $upDBInstance = $dbServerUPSA
                  }
                  # Proceed if the database instance specified for the UPSA maps to the local machine name and the service was provisioned successfully
                  $profileSyncServices = @(Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.Office.Server.Administration.ProfileSynchronizationServiceInstance"})
                  if ($upDBInstance -like "*$env:COMPUTERNAME*" -and ($profileSyncServices | Where-Object {$_.Status -eq "Online"})) {
                      # Sets the Forefront Identity Manager Services to depend on the SQL Server service
                      # For all-in-one environments where FIM may not start automatically, e.g. Development VMs
                      Write-Host -ForegroundColor White " - Setting Forefront Identity Manager services to depend on SQL Server."
                      Write-Host -ForegroundColor White " - This is helpful when the SQL instance for the User Profile Service is co-located."
                      & "$env:windir\System32\sc.exe" config FIMService depend= MSSQLSERVER
                      & "$env:windir\System32\sc.exe" config FIMService start= delayed-auto
                      & "$env:windir\System32\sc.exe" config FIMSynchronizationService depend= Winmgmt/FIMService
                      & "$env:windir\System32\sc.exe" config FIMSynchronizationService start= delayed-auto
                  }
              }
              else {Write-Host -ForegroundColor White "Not applicable to SharePoint 2016."}
          }
          Else {
              Write-Host -ForegroundColor White " - Could not get User Profile Service, or StartProfileSync is False."
          }
          WriteLine
      }
  }
  Catch {
      Write-Output $_
      Throw " - Error Provisioning the User Profile Service Application"
  }
}