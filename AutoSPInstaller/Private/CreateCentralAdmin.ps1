# ===================================================================================
# Func: CreateCentralAdmin
# Desc: Setup Central Admin Web Site, Check the topology of an existing farm, and configure the farm as required.
# ===================================================================================
Function CreateCentralAdmin([xml]$xmlinput) {
  Get-MajorVersionNumber $xmlinput
  # Get all Central Admin service instances in the farm
  $centralAdminServices = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.SharePoint.Administration.SPWebServiceInstance" -and $_.Name -eq "WSS_Administration"}
  # Get those Central Admin services that are Online
  $centralAdminServicesOnline = $centralAdminServices | Where-Object {$_.Status -eq "Online"}
  # Get the local Central Admin service
  $localCentralAdminService = $centralAdminServices | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
  If (((ShouldIProvision $xmlinput.Configuration.Farm.CentralAdmin) -eq $true) -and ($localCentralAdminService.Status -ne "Online")) {
      Try {
          # Check if there is already a Central Admin provisioned in the farm; if not, create one
          If (!(Get-SPWebApplication -IncludeCentralAdministration | Where-Object {$_.IsAdministrationWebApplication}) -or $centralAdminServicesOnline.Count -lt 1) {
              # Create Central Admin for farm
              Write-Host -ForegroundColor White " - Creating Central Admin site..."
              $centralAdminPort = $xmlinput.Configuration.Farm.CentralAdmin.Port
              if (($env:spVer -ge "16") -and ($xmlinput.Configuration.Farm.CentralAdmin.UseSSL -eq $true)) {
                  # Use updated cmdlet switch for SP2016 for SSL in Central Admin
                  $centralAdminSSLSwitch = @{SecureSocketsLayer = $true}
              }
              else {$centralAdminSSLSwitch = @{}
              }
              New-SPCentralAdministration -Port $centralAdminPort -WindowsAuthProvider "NTLM" @centralAdminSSLSwitch
              If (-not $?) {Throw " - Error creating central administration application"}
              Write-Host -ForegroundColor Cyan " - Waiting for Central Admin site..." -NoNewline
              While ($localCentralAdminService.Status -ne "Online") {
                  Write-Host -ForegroundColor Cyan "." -NoNewline
                  Start-Sleep 1
                  $centralAdminServices = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.SharePoint.Administration.SPWebServiceInstance" -and $_.Name -eq "WSS_Administration"}
                  $localCentralAdminService = $centralAdminServices | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
              }
              Write-Host -BackgroundColor Green -ForegroundColor Black $($localCentralAdminService.Status)
              If ($xmlinput.Configuration.Farm.CentralAdmin.UseSSL -eq $true) {
                  Write-Host -ForegroundColor White " - Enabling SSL for Central Admin..."
                  $centralAdmin = Get-SPWebApplication -IncludeCentralAdministration | Where-Object {$_.IsAdministrationWebApplication}
                  $SSLHostHeader = $env:COMPUTERNAME
                  $SSLPort = $centralAdminPort
                  $SSLSiteName = $centralAdmin.DisplayName
                  if ($env:spVer -le "15") {
                      # Use the old pre-2016 way to enable SSL for Central Admin
                      New-SPAlternateURL -Url "https://$($env:COMPUTERNAME):$centralAdminPort" -Zone Default -WebApplication $centralAdmin | Out-Null
                  }
                  if (((Get-WmiObject Win32_OperatingSystem).Version -like "6.2*" -or (Get-WmiObject Win32_OperatingSystem).Version -like "6.3*") -and ($env:spVer -eq "14")) {
                      Write-Host -ForegroundColor White " - Assigning certificate(s) in a separate PowerShell window..."
                      Start-Process -FilePath "$PSHOME\powershell.exe" -Verb RunAs -ArgumentList "-Command `". $env:dp0\AutoSPInstallerFunctions.ps1`; AssignCert $SSLHostHeader $SSLPort $SSLSiteName; Start-Sleep 10`"" -Wait
                  }
                  else {AssignCert $SSLHostHeader $SSLPort $SSLSiteName}
              }
          }
          # Otherwise create a Central Admin site locally, with an AAM to the existing Central Admin
          Else {
              Write-Host -ForegroundColor White " - Creating local Central Admin site..."
              New-SPCentralAdministration
          }
      }
      Catch {
          If ($err -like "*update conflict*") {
              Write-Warning "A concurrency error occured, trying again."
              CreateCentralAdmin $xmlinput
          }
          Else {
              Throw $_
          }
      }
  }
}