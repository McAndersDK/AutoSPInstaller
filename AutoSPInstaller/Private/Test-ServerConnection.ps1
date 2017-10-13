Function Test-ServerConnection ($server) {
  Write-Host -ForegroundColor White " - Testing connection (via Ping) to `"$server`"..." -NoNewline
  $canConnect = Test-Connection -ComputerName $server -Count 1 -Quiet
  If ($canConnect) {Write-Host -ForegroundColor Cyan -BackgroundColor Black $($canConnect.ToString() -replace "True", "Success.")}
  If (!$canConnect) {
      Write-Host -ForegroundColor Yellow -BackgroundColor Black $($canConnect.ToString() -replace "False", "Failed.")
      Write-Host -ForegroundColor Yellow " - Check that `"$server`":"
      Write-Host -ForegroundColor Yellow "  - Is online"
      Write-Host -ForegroundColor Yellow "  - Has the required Windows Firewall exceptions set (or turned off)"
      Write-Host -ForegroundColor Yellow "  - Has a valid DNS entry for $server.$($env:USERDNSDOMAIN)"
  }
}