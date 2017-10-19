# ====================================================================================
# Func: ConfigureFoundationSearch
# Desc: Updates the service account for SPSearch4 (SharePoint Foundation (Help) Search)
# ====================================================================================

Function ConfigureFoundationSearch ([xml]$xmlinput) {
  # Does not actually provision Foundation Search as of yet, just updates the service account it would run under to mitigate Health Analyzer warnings
  Get-MajorVersionNumber $xmlinput
  # Make sure a credential deployment job doesn't already exist, and that we are running SP2010
  if ((!(Get-SPTimerJob -Identity "windows-service-credentials-SPSearch4")) -and ($env:spVer -eq "14")) {
      WriteLine
      Try {
          $foundationSearchService = (Get-SPFarm).Services | Where-Object {$_.Name -eq "SPSearch4"}
          $spservice = Get-SPManagedAccountXML $xmlinput -CommonName "spservice"
          UpdateProcessIdentity $foundationSearchService
      }
      Catch {
          Write-Output $_
          Throw " - An error occurred updating the service account for SPSearch4."
      }
      WriteLine
  }
}