# ===================================================================================
# Func: CreateUPSAsAdmin
# Desc: Create the User Profile Service Application itself as the Farm Admin account, in a session with elevated privileges
#       This incorporates the workaround by @harbars & @glapointe http://www.harbar.net/archive/2010/10/30/avoiding-the-default-schema-issue-when-creating-the-user-profile.aspx
#       Modified to work within AutoSPInstaller (to pass our script variables to the Farm Account credential's PowerShell session)
# ===================================================================================

Function CreateUPSAsAdmin([xml]$xmlinput) {
  Try {
      $mySiteWebApp = $xmlinput.Configuration.WebApplications.WebApplication | Where-Object {$_.Type -eq "MySiteHost"}
      $mySiteManagedPath = $userProfile.MySiteManagedPath
      # If we have asked to create a MySite Host web app, use that as the MySite host location
      if ($mySiteWebApp) {
          $mySiteURL = ($mySiteWebApp.url).TrimEnd("/")
          $mySitePort = $mySiteWebApp.port
          $mySiteHostLocation = $mySiteURL + ":" + $mySitePort
      }
      else {
          # Use the value provided in the $userProfile node
          $mySiteHostLocation = $userProfile.MySiteHostLocation
      }
      if ([string]::IsNullOrEmpty($mySiteManagedPath)) {
          # Don't specify the MySiteManagedPath switch if it was left blank. This will effectively use the default path of "personal/sites"
          # Note that an empty hashtable doesn't seem to work here so we just put an empty string
          $mySiteManagedPathSwitch = ""
      }
      else {
          # Attempt to use the path we specified in the XML
          $mySiteManagedPathSwitch = "-MySiteManagedPath `"$mySiteManagedPath`"" # This format required to parse properly in the script block below
      }
      $farmAcct = $xmlinput.Configuration.Farm.Account.Username
      $userProfileServiceName = $userProfile.Name
      $dbServer = $userProfile.Database.DBServer
      # If we haven't specified a DB Server then just use the default used by the Farm
      If ([string]::IsNullOrEmpty($dbServer)) {
          $dbServer = $xmlinput.Configuration.Farm.Database.DBServer
      }
      # Set the ProfileDBServer, SyncDBServer and SocialDBServer to the same value ($dbServer). Maybe in the future we'll want to get more granular...?
      $profileDBServer = $dbServer
      $syncDBServer = $dbServer
      $socialDBServer = $dbServer
      $dbPrefix = Get-DBPrefix $xmlinput
      $profileDB = $dbPrefix + $userProfile.Database.ProfileDB
      $syncDB = $dbPrefix + $userProfile.Database.SyncDB
      $socialDB = $dbPrefix + $userProfile.Database.SocialDB
      $applicationPool = Get-HostedServicesAppPool $xmlinput
      If (!$farmCredential) {[System.Management.Automation.PsCredential]$farmCredential = GetFarmCredentials $xmlinput}
      $scriptFile = "$((Get-Item $env:TEMP).FullName)\AutoSPInstaller-ScriptBlock.ps1"
      # Write the script block, with expanded variables to a temporary script file that the Farm Account can get at
      Write-Output "Write-Host -ForegroundColor White `"Creating $userProfileServiceName as $farmAcct...`"" | Out-File $scriptFile -Width 400
      Write-Output "Add-PsSnapin Microsoft.SharePoint.PowerShell" | Out-File $scriptFile -Width 400 -Append
      Write-Output "`$newProfileServiceApp = New-SPProfileServiceApplication -Name `"$userProfileServiceName`" -ApplicationPool `"$($applicationPool.Name)`" -ProfileDBServer $profileDBServer -ProfileDBName $profileDB -ProfileSyncDBServer $syncDBServer -ProfileSyncDBName $syncDB -SocialDBServer $socialDBServer -SocialDBName $socialDB -MySiteHostLocation $mySiteHostLocation $mySiteManagedPathSwitch" | Out-File $scriptFile -Width 400 -Append
      Write-Output "If (`-not `$?) {Write-Error `" - Failed to create $userProfileServiceName`"; Write-Host `"Press any key to exit...`"; `$null = `$host.UI.RawUI.ReadKey`(`"NoEcho,IncludeKeyDown`"`)}" | Out-File $scriptFile -Width 400 -Append
      # Grant the current install account rights to the newly-created Profile DB - needed since it's going to be running PowerShell commands against it
      Write-Output "`$profileDBId = Get-SPDatabase | Where-Object {`$_.Name -eq `"$profileDB`"}" | Out-File $scriptFile -Width 400 -Append
      Write-Output "Add-SPShellAdmin -UserName `"$env:USERDOMAIN\$env:USERNAME`" -database `$profileDBId" | Out-File $scriptFile -Width 400 -Append
      # Grant the current install account rights to the newly-created Social DB as well
      Write-Output "`$socialDBId = Get-SPDatabase | Where-Object {`$_.Name -eq `"$socialDB`"}" | Out-File $scriptFile -Width 400 -Append
      Write-Output "Add-SPShellAdmin -UserName `"$env:USERDOMAIN\$env:USERNAME`" -database `$socialDBId" | Out-File $scriptFile -Width 400 -Append
      # Add the -Version 2 switch in case we are installing SP2010 on Windows Server 2012 or 2012 R2
      if (((Get-WmiObject Win32_OperatingSystem).Version -like "6.2*" -or (Get-WmiObject Win32_OperatingSystem).Version -like "6.3*") -and ($env:spVer -eq "14")) {
          $versionSwitch = "-Version 2"
      }
      else {$versionSwitch = ""}
      If (Confirm-LocalSession) {
          # Create the UPA as usual if this isn't a remote session
          # Start a process under the Farm Account's credentials, then spawn an elevated process within to finally execute the script file that actually creates the UPS
          Start-Process -WorkingDirectory $PSHOME -FilePath "powershell.exe" -Credential $farmCredential -ArgumentList "-ExecutionPolicy Bypass -Command Start-Process -WorkingDirectory `"'$PSHOME'`" -FilePath `"'powershell.exe'`" -ArgumentList `"'$versionSwitch -ExecutionPolicy Bypass $scriptFile'`" -Verb Runas" -Wait
      }
      else {
          # Do some fancy stuff to get this to work over a remote session
          Write-Host -ForegroundColor White " - Enabling remoting to $env:COMPUTERNAME..."
          Enable-WSManCredSSP -Role Client -Force -DelegateComputer $env:COMPUTERNAME | Out-Null # Yes that's right, we're going to "remote" into the local computer...
          Start-Sleep 10
          Write-Host -ForegroundColor White " - Creating temporary `"remote`" session to $env:COMPUTERNAME..."
          $UPSession = New-PSSession -Name "UPS-Session" -Authentication Credssp -Credential $farmCredential -ComputerName $env:COMPUTERNAME -ErrorAction SilentlyContinue
          If (!$UPSession) {
              # Try again
              Write-Warning "Couldn't create remote session to $env:COMPUTERNAME; trying again..."
              CreateUPSAsAdmin $xmlinput
          }
          # Pass the value of $scriptFile to the new session
          Invoke-Command -ScriptBlock {param ($value) Set-Variable -Name ScriptFile -Value $value} -ArgumentList $scriptFile -Session $UPSession
          Write-Host -ForegroundColor White " - Creating $userProfileServiceName under `"remote`" session..."
          # Start a (local) process (on our "remote" session), then spawn an elevated process within to finally execute the script file that actually creates the UPS
          Invoke-Command -ScriptBlock {Start-Process -FilePath "$PSHOME\powershell.exe" -ArgumentList "-ExecutionPolicy Bypass $scriptFile" -Verb Runas} -Session $UPSession
      }
  }
  Catch {
      Write-Output $_
      Pause "exit"
  }
  finally {
      # Delete the temporary script file if we were successful in creating the UPA
      $profileServiceApp = Get-SPServiceApplication | Where-Object {$_.DisplayName -eq $userProfileServiceName}
      If ($profileServiceApp) {Remove-Item -LiteralPath $scriptFile -Force}
  }
}