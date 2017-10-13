# ===================================================================================
# FUNC: AddManagedAccounts
# DESC: Adds existing accounts to SharePoint managed accounts and creates local profiles for each
# TODO: Make this more robust, prompt for blank values etc.
# ===================================================================================
Function AddManagedAccounts([xml]$xmlinput) {
  WriteLine
  Write-Host -ForegroundColor White " - Adding Managed Accounts..."
  If ($xmlinput.Configuration.Farm.ManagedAccounts) {
      # Get the members of the local Administrators group
      $builtinAdminGroup = Get-AdministratorsGroup
      $adminGroup = ([ADSI]"WinNT://$env:COMPUTERNAME/$builtinAdminGroup,group")
      # This syntax comes from Ying Li (http://myitforum.com/cs2/blogs/yli628/archive/2007/08/30/powershell-script-to-add-remove-a-domain-user-to-the-local-administrators-group-on-a-remote-machine.aspx)
      $localAdmins = $adminGroup.psbase.invoke("Members") | ForEach-Object {$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)}
      # Ensure Secondary Logon service is enabled and started
      If (!((Get-Service -Name seclogon).Status -eq "Running")) {
          Write-Host -ForegroundColor White " - Enabling Secondary Logon service..."
          Set-Service -Name seclogon -StartupType Manual
          Write-Host -ForegroundColor White " - Starting Secondary Logon service..."
          Start-Service -Name seclogon
      }

      ForEach ($account in $xmlinput.Configuration.Farm.ManagedAccounts.ManagedAccount) {
          $username = $account.username
          $password = $account.Password
          $password = ConvertTo-SecureString "$password" -AsPlaintext -Force
          $alreadyAdmin = $false
          # The following was suggested by Matthias Einig (http://www.codeplex.com/site/users/view/matein78)
          # And inspired by http://toddcarter.net/post/2010/05/03/give-your-application-pool-accounts-a-profile/ & http://blog.brainlitter.com/archive/2010/06/08/how-to-revolve-event-id-1511-windows-cannot-find-the-local-profile-on-windows-server-2008.aspx
          Try {
              $credAccount = New-Object System.Management.Automation.PsCredential $username, $password
              $managedAccountDomain, $managedAccountUser = $username -Split "\\"
              Write-Host -ForegroundColor White "  - Account `"$managedAccountDomain\$managedAccountUser`:"
              Write-Host -ForegroundColor White "   - Creating local profile for $username..."
              # Add managed account to local admins (very) temporarily so it can log in and create its profile
              If (!($localAdmins -contains $managedAccountUser)) {
                  $builtinAdminGroup = Get-AdministratorsGroup
                  Write-Host -ForegroundColor White "   - Adding to local Admins (*temporarily*)..." -NoNewline
                  ([ADSI]"WinNT://$env:COMPUTERNAME/$builtinAdminGroup,group").Add("WinNT://$managedAccountDomain/$managedAccountUser")
                  Write-Host -ForegroundColor White "OK."
              }
              Else {
                  $alreadyAdmin = $true
              }
              # Spawn a command window using the managed account's credentials, create the profile, and exit immediately
              Start-Process -WorkingDirectory "$env:SYSTEMROOT\System32\" -FilePath "cmd.exe" -ArgumentList "/C" -LoadUserProfile -NoNewWindow -Credential $credAccount
              # Remove managed account from local admins unless it was already there
              $builtinAdminGroup = Get-AdministratorsGroup
              If (-not $alreadyAdmin) {
                  Write-Host -ForegroundColor White "   - Removing from local Admins..." -NoNewline
                  ([ADSI]"WinNT://$env:COMPUTERNAME/$builtinAdminGroup,group").Remove("WinNT://$managedAccountDomain/$managedAccountUser")
                  if (!$?) {
                      Write-Host -ForegroundColor White "."
                      Write-Host -ForegroundColor Yellow "   - Could not remove `"$managedAccountDomain\$managedAccountUser`" from local Admins."
                      Write-Host -ForegroundColor Yellow "   - Please remove it manually."
                  }
                  else {Write-Host -ForegroundColor White "OK."}
              }
              Write-Host -ForegroundColor Green "  - Done."
          }
          Catch {
              $_
              Write-Host -ForegroundColor White "."
              Write-Warning "Could not create local user profile for $username"
              break
          }
          $managedAccount = Get-SPManagedAccount | Where-Object {$_.UserName -eq $username}
          If ($managedAccount -eq $null) {
              Write-Host -ForegroundColor White "   - Registering managed account $username..."
              If ($username -eq $null -or $password -eq $null) {
                  Write-Host -BackgroundColor Gray -ForegroundColor DarkCyan "   - Prompting for Account: "
                  $credAccount = $host.ui.PromptForCredential("Managed Account", "Enter Account Credentials:", "", "NetBiosUserName" )
              }
              Else {
                  $credAccount = New-Object System.Management.Automation.PsCredential $username, $password
              }
              New-SPManagedAccount -Credential $credAccount | Out-Null
              If (-not $?) { Throw "   - Failed to create managed account" }
          }
          Else {
              Write-Host -ForegroundColor White "   - Managed account $username already exists."
          }
      }
  }
  Write-Host -ForegroundColor White " - Done Adding Managed Accounts."
  WriteLine
}