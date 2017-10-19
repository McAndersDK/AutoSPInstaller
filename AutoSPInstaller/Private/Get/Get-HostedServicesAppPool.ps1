# ====================================================================================
# Func: Get-HostedServicesAppPool
# Desc: Creates and/or returns the Hosted Services Application Pool
# ====================================================================================
Function Get-HostedServicesAppPool ([xml]$xmlinput) {
  $spservice = Get-SPManagedAccountXML $xmlinput -CommonName "spservice"
  # Managed Account
  $managedAccountGen = Get-SPManagedAccount | Where-Object {$_.UserName -eq $($spservice.username)}
  If ($managedAccountGen -eq $null) { Throw " - Managed Account $($spservice.username) not found" }
  # App Pool
  $applicationPool = Get-SPServiceApplicationPool "SharePoint Hosted Services" -ea SilentlyContinue
  If ($applicationPool -eq $null) {
      Write-Host -ForegroundColor White " - Creating SharePoint Hosted Services Application Pool..."
      $applicationPool = New-SPServiceApplicationPool -Name "SharePoint Hosted Services" -account $managedAccountGen
      If (-not $?) { Throw "Failed to create the application pool" }
  }
  Return $applicationPool
}