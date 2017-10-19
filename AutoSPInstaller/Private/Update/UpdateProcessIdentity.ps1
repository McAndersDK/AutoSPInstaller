# ====================================================================================
# Func: UpdateProcessIdentity
# Desc: Updates the account a specified service runs under to the general app pool account
# ====================================================================================
Function UpdateProcessIdentity ($serviceToUpdate) {
  $spservice = Get-SPManagedAccountXML $xmlinput -CommonName "spservice"
  # Managed Account
  $managedAccountGen = Get-SPManagedAccount | Where-Object {$_.UserName -eq $($spservice.username)}
  if ($managedAccountGen -eq $null) { Throw " - Managed Account $($spservice.username) not found" }
  if ($serviceToUpdate.Service) {$serviceToUpdate = $serviceToUpdate.Service}
  if ($serviceToUpdate.ProcessIdentity.Username -ne $managedAccountGen.UserName) {
      Write-Host -ForegroundColor White " - Updating $($serviceToUpdate.TypeName) to run as $($managedAccountGen.UserName)..." -NoNewline
      # Set the Process Identity to our general App Pool Account; otherwise it's set by default to the Farm Account and gives warnings in the Health Analyzer
      $serviceToUpdate.ProcessIdentity.CurrentIdentityType = "SpecificUser"
      $serviceToUpdate.ProcessIdentity.ManagedAccount = $managedAccountGen
      $serviceToUpdate.ProcessIdentity.Update()
      $serviceToUpdate.ProcessIdentity.Deploy()
      Write-Host -ForegroundColor Green "Done."
  }
  else {Write-Host -ForegroundColor White " - $($serviceToUpdate.TypeName) is already configured to run as $($managedAccountGen.UserName)."}
}