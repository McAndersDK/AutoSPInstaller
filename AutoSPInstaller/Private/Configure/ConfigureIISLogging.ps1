# ===================================================================================
# Func: ConfigureIISLogging
# Desc: Configures IIS Logging for the local server
# ===================================================================================
Function ConfigureIISLogging([xml]$xmlinput) {
  WriteLine
  $IISLogConfig = $xmlinput.Configuration.Farm.Logging.IISLogs
  Write-Host -ForegroundColor White " - Configuring IIS logging..."
  # New: Check for PowerShell version > 2 in case this is being run on Windows Server 2012
  If (!([string]::IsNullOrEmpty($IISLogConfig.Path)) -and $host.Version.Major -gt 2) {
      $IISLogDir = $IISLogConfig.Path
      EnsureFolder $IISLogDir
      ImportWebAdministration
      $oldIISLogDir = Get-WebConfigurationProperty "/system.applicationHost/sites/siteDefaults" -name logfile.directory.Value
      $oldIISLogDir = $oldIISLogDir -replace ("%SystemDrive%", "$env:SystemDrive")
      If ($IISLogDir -ne $oldIISLogDir) {
          # Only change the global IIS logging location if the desired location is different than the current
          Write-Host -ForegroundColor White " - Setting the global IIS logging location..."
          # The line below is from http://stackoverflow.com/questions/4626791/powershell-command-to-set-iis-logging-settings
          Set-WebConfigurationProperty "/system.applicationHost/sites/siteDefaults" -name logfile.directory -value $IISLogDir
          # TODO: Fix this so it actually moves all files within subfolders
          If (Test-Path -Path $oldIISLogDir) {
              Write-Host -ForegroundColor White " - Moving any contents in old location $oldIISLogDir to $IISLogDir..."
              ForEach ($item in $(Get-ChildItem -Path $oldIISLogDir)) {
                  Move-Item -Path $oldIISLogDir\$item -Destination $IISLogDir -Force -ErrorAction SilentlyContinue
              }
          }
      }
  }
  else {
      # Assume default value if none was specified in the XML input file
      $IISLogDir = "$env:SystemDrive\Inetpub\logs" # We omit the trailing \LogFiles so we can compress the entire \logs\ folder including Failed Requests etc.
  }
  # Finally, enable NTFS compression on the IIS log location to save disk space
  If ($IISLogConfig.Compress -eq $true) {
      CompressFolder $IISLogDir
  }
  WriteLine
}