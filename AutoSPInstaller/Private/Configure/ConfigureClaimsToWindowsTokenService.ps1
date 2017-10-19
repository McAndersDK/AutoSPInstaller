Function ConfigureClaimsToWindowsTokenService {
  # C2WTS is required by Excel Services, Visio Services and PerformancePoint Services; if any of these are being provisioned we should start it.
  If ((ShouldIProvision $xmlinput.Configuration.Farm.Services.ClaimsToWindowsTokenService -eq $true) -or `
      (ShouldIProvision $xmlinput.Configuration.EnterpriseServiceApps.ExcelServices -eq $true) -or `
      (ShouldIProvision $xmlinput.Configuration.EnterpriseServiceApps.VisioService -eq $true) -or `
      (ShouldIProvision $xmlinput.Configuration.EnterpriseServiceApps.PerformancePointService -eq $true) -or `
      ((ShouldIProvision $xmlinput.Configuration.OfficeWebApps.ExcelService -eq $true) -and ($xmlinput.Configuration.OfficeWebApps.Install -eq $true))) {
      WriteLine
      # Ensure Claims to Windows Token Service is started
      $claimsServices = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.SharePoint.Administration.Claims.SPWindowsTokenServiceInstance"}
      $claimsService = $claimsServices | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
      If ($claimsService.Status -ne "Online") {
          Try {
              Write-Host -ForegroundColor White " - Starting $($claimsService.DisplayName)..."
              if ($xmlinput.Configuration.Farm.Services.ClaimsToWindowsTokenService.UpdateAccount -eq $true) {
                  UpdateProcessIdentity $claimsService
                  $claimsService.Update()
                  # Add C2WTS account (currently the generic service account) to local admins
                  $builtinAdminGroup = Get-AdministratorsGroup
                  $adminGroup = ([ADSI]"WinNT://$env:COMPUTERNAME/$builtinAdminGroup,group")
                  # This syntax comes from Ying Li (http://myitforum.com/cs2/blogs/yli628/archive/2007/08/30/powershell-script-to-add-remove-a-domain-user-to-the-local-administrators-group-on-a-remote-machine.aspx)
                  $localAdmins = $adminGroup.psbase.invoke("Members") | ForEach-Object {$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)}
                  $spservice = Get-SPManagedAccountXML $xmlinput -CommonName "spservice"
                  $managedAccountGen = Get-SPManagedAccount | Where-Object {$_.UserName -eq $($spservice.username)}
                  $managedAccountDomain, $managedAccountUser = $managedAccountGen.UserName -split "\\"
                  If (!($localAdmins -contains $managedAccountUser)) {
                      Write-Host -ForegroundColor White " - Adding $($managedAccountGen.Username) to local Administrators..."
                      ([ADSI]"WinNT://$env:COMPUTERNAME/$builtinAdminGroup,group").Add("WinNT://$managedAccountDomain/$managedAccountUser")
                  }
              }
              $claimsService.Provision()
              If (-not $?) {throw " - Failed to start $($claimsService.DisplayName)"}
          }
          Catch {
              Throw " - An error occurred starting $($claimsService.DisplayName)"
          }
          #Wait
          Write-Host -ForegroundColor Cyan " - Waiting for $($claimsService.DisplayName)..." -NoNewline
          While ($claimsService.Status -ne "Online") {
              Write-Host -ForegroundColor Cyan "." -NoNewline
              sleep 1
              $claimsServices = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.SharePoint.Administration.Claims.SPWindowsTokenServiceInstance"}
              $claimsService = $claimsServices | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
          }
          Write-Host -BackgroundColor Green -ForegroundColor Black $($claimsService.Status)
      }
      Else {
          Write-Host -ForegroundColor White " - $($claimsService.DisplayName) already started."
      }
      Write-Host -ForegroundColor White " - Setting C2WTS to depend on Cryptographic Services..."
      Start-Process -FilePath "$env:windir\System32\sc.exe" -ArgumentList "config c2wts depend= CryptSvc" -Wait -NoNewWindow -ErrorAction SilentlyContinue
      WriteLine
  }
}