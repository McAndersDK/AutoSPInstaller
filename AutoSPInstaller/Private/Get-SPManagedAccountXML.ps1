Function Get-SPManagedAccountXML([xml]$xmlinput, $commonName) {
  $managedAccountXML = $xmlinput.Configuration.Farm.ManagedAccounts.ManagedAccount | Where-Object { $_.CommonName -eq $commonName }
  Return $managedAccountXML
}