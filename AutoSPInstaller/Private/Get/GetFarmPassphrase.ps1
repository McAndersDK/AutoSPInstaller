Function GetFarmPassphrase([xml]$xmlinput) {
  $farmPassphrase = $xmlinput.Configuration.Farm.Passphrase
  If (!($farmPassphrase) -or ($farmPassphrase -eq "")) {
      $farmPassphrase = Read-Host -Prompt " - Please enter the farm passphrase now" -AsSecureString
      If (!($farmPassphrase) -or ($farmPassphrase -eq "")) { Throw " - Farm passphrase is required!" }
  }
  Return $farmPassphrase
}