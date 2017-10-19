# ===================================================================================
# Func: ConfigureSandboxedCodeService
# Desc: Configures the SharePoint Foundation Sandboxed (User) Code Service
# ===================================================================================
Function ConfigureSandboxedCodeService {
  If (ShouldIProvision $xmlinput.Configuration.Farm.Services.SandboxedCodeService -eq $true) {
      WriteLine
      Write-Host -ForegroundColor White " - Starting Sandboxed Code Service"
      $sandboxedCodeServices = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.SharePoint.Administration.SPUserCodeServiceInstance"}
      $sandboxedCodeService = $sandboxedCodeServices | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
      If ($sandboxedCodeService.Status -ne "Online") {
          Try {
              Write-Host -ForegroundColor White " - Starting Microsoft SharePoint Foundation Sandboxed Code Service..."
              UpdateProcessIdentity $sandboxedCodeService
              $sandboxedCodeService.Update()
              $sandboxedCodeService.Provision()
              If (-not $?) {Throw " - Failed to start Sandboxed Code Service"}
          }
          Catch {
              Throw " - An error occurred starting the Microsoft SharePoint Foundation Sandboxed Code Service"
          }
          #Wait
          Write-Host -ForegroundColor Cyan " - Waiting for Sandboxed Code service..." -NoNewline
          While ($sandboxedCodeService.Status -ne "Online") {
              Write-Host -ForegroundColor Cyan "." -NoNewline
              Start-Sleep 1
              $sandboxedCodeServices = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.SharePoint.Administration.SPUserCodeServiceInstance"}
              $sandboxedCodeService = $sandboxedCodeServices | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
          }
          Write-Host -BackgroundColor Green -ForegroundColor Black $($sandboxedCodeService.Status)
      }
      Else {
          Write-Host -ForegroundColor White " - Sandboxed Code Service already started."
      }
      WriteLine
  }
}