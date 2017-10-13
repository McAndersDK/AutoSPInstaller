Function ValidatePassphrase([xml]$xmlinput) {
  # Check if passphrase is supplied
  $farmPassphrase = $xmlinput.Configuration.Farm.Passphrase
  If (!($farmPassphrase) -or ($farmPassphrase -eq "")) {
      Return
  }
  $groups = 0
  If ($farmPassphrase -cmatch "[a-z]") { $groups = $groups + 1 }
  If ($farmPassphrase -cmatch "[A-Z]") { $groups = $groups + 1 }
  If ($farmPassphrase -match "[0-9]") { $groups = $groups + 1 }
  If ($farmPassphrase -match "[^a-zA-Z0-9]") { $groups = $groups + 1 }

  If (($groups -lt 3) -or ($farmPassphrase.length -lt 8)) {
      Write-Host -ForegroundColor Yellow " - Farm passphrase does not meet complexity requirements."
      Write-Host -ForegroundColor Yellow " - It must be at least 8 characters long and contain three of these types:"
      Write-Host -ForegroundColor Yellow "  - Upper case letters"
      Write-Host -ForegroundColor Yellow "  - Lower case letters"
      Write-Host -ForegroundColor Yellow "  - Digits"
      Write-Host -ForegroundColor Yellow "  - Other characters"
      Throw " - Farm passphrase does not meet complexity requirements."
  }
}