# ===================================================================================
# Func: ConfigureFarmAdmin
# Desc: Sets up the farm account and adds to Local admins if needed
# ===================================================================================
Function ConfigureFarmAdmin([xml]$xmlinput) {
  # Per Spencer Harbar, the farm account needs to be a local admin when provisioning distributed cache, so if it's being requested for provisioning we'll add it to Administrators here
  If (($xmlinput.Configuration.Farm.Account.AddToLocalAdminsDuringSetup -eq $true) -or (ShouldIProvision $xmlinput.Configuration.ServiceApps.UserProfileServiceApp -eq $true) -or (ShouldIProvision $xmlinput.Configuration.Farm.Services.DistributedCache -eq $true)) {
      WriteLine
      # Add to Admins Group
      $farmAcct = $xmlinput.Configuration.Farm.Account.Username
      Write-Host -ForegroundColor White " - Adding $farmAcct to local Administrators" -NoNewline
      If ($xmlinput.Configuration.Farm.Account.LeaveInLocalAdmins -ne $true) {Write-Host -ForegroundColor White " (only for install)..."}
      Else {Write-Host -ForegroundColor White " ..."}
      $farmAcctDomain, $farmAcctUser = $farmAcct -Split "\\"
      Try {
          $builtinAdminGroup = Get-AdministratorsGroup
          ([ADSI]"WinNT://$env:COMPUTERNAME/$builtinAdminGroup,group").Add("WinNT://$farmAcctDomain/$farmAcctUser")
          If (-not $?) {Throw}
          # Restart the SPTimerV4 service if it's running, so it will pick up the new credential
          If ((Get-Service -Name SPTimerV4).Status -eq "Running") {
              Write-Host -ForegroundColor White " - Restarting SharePoint Timer Service..."
              Restart-Service SPTimerV4
          }
      }
      Catch {Write-Host -ForegroundColor White " - $farmAcct is already a member of `"$builtinAdminGroup`"."}
      WriteLine
  }
}