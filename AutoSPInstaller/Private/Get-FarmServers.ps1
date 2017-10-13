Function Get-FarmServers ([xml]$xmlinput) {
  $servers = $null
  $farmServers = @()
  # Look for server name references in the XML
  ForEach ($node in $xmlinput.SelectNodes("//*[@Provision]|//*[@Install]|//*[CrawlComponent]|//*[QueryComponent]|//*[SearchQueryAndSiteSettingsComponent]|//*[AdminComponent]|//*[IndexComponent]|//*[ContentProcessingComponent]|//*[AnalyticsProcessingComponent]|//*[@Start]")) {
      # Try to set the server name from the various elements/attributes
      $servers = @(GetFromNode $node "Provision")
      If ([string]::IsNullOrEmpty($servers)) { $servers = @(GetFromNode $node "Install") }
      If ([string]::IsNullOrEmpty($servers)) { $servers = @(GetFromNode $node "Start") }
      # Accomodate and clean up comma and/or space-separated server names
      # First get rid of any recurring spaces or commas
      While ($servers -match "  ") {
          $servers = $servers -replace "  ", " "
      }
      While ($servers -match ",,") {
          $servers = $servers -replace ",,", ","
      }
      $servers = $servers -split "," -split " "
      # Remove any "true", "false" or zero-length values as we only want server names
      If ($servers -eq "true" -or $servers -eq "false" -or [string]::IsNullOrEmpty($servers)) {
          $servers = $null
      }
      else {
          # Add any server(s) we found to our $farmServers array
          $farmServers = @($farmServers + $servers)
      }
  }

  # Remove any blanks and duplicates
  $farmServers = $farmServers | Where-Object {$_ -ne ""} | Select-Object -Unique
  Return $farmServers
}