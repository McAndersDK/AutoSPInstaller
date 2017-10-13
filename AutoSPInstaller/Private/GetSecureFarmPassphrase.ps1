# ===================================================================================
# Func: GetSecureFarmPassphrase
# Desc: Return the Farm Phrase as a secure string
# ===================================================================================
Function GetSecureFarmPassphrase([xml]$xmlinput) {
  If (!($farmPassphrase) -or ($farmPassphrase -eq "")) {
      $farmPassphrase = GetFarmPassPhrase $xmlinput
  }
  If ($farmPassPhrase.GetType().Name -ne "SecureString") {
      $secPhrase = ConvertTo-SecureString $farmPassphrase -AsPlaintext -Force
  }
  Else {$secPhrase = $farmPassphrase}
  Return $secPhrase
}