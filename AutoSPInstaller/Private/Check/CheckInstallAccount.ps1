# ===================================================================================
# Func: CheckInstallAccount
# Desc: Check the install account and
# ===================================================================================
Function CheckInstallAccount([xml]$xmlinput) {
  # Check if we are running under Farm Account credentials
  $farmAcct = $xmlinput.Configuration.Farm.Account.Username
  If ($env:USERDOMAIN + "\" + $env:USERNAME -eq $farmAcct) {
      Write-Host  -ForegroundColor Yellow " - WARNING: Running install using Farm Account: $farmAcct"
  }
}