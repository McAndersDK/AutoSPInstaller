# ===================================================================================
# Func: GetFarmCredentials
# Desc: Return the credentials for the farm account, prompt the user if need more info
# ===================================================================================
Function GetFarmCredentials([xml]$xmlinput) {
  $farmAcct = $xmlinput.Configuration.Farm.Account.Username
  $farmAcctPWD = $xmlinput.Configuration.Farm.Account.Password
  If (!($farmAcct) -or $farmAcct -eq "" -or !($farmAcctPWD) -or $farmAcctPWD -eq "") {
      Write-Host -BackgroundColor Gray -ForegroundColor DarkCyan " - Prompting for Farm Account:"
      $script:farmCredential = $host.ui.PromptForCredential("Farm Setup", "Enter Farm Account Credentials:", "$farmAcct", "NetBiosUserName" )
  }
  Else {
      $secPassword = ConvertTo-SecureString "$farmAcctPWD" -AsPlaintext -Force
      $script:farmCredential = New-Object System.Management.Automation.PsCredential $farmAcct, $secPassword
  }
  Return $farmCredential
}