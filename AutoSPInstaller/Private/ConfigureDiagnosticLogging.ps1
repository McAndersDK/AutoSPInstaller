# ===================================================================================
# Func: ConfigureDiagnosticLogging
# Desc: Configures Diagnostic (ULS) Logging for the farm
# From: Originally suggested by Codeplex user leowu70: http://autospinstaller.codeplex.com/discussions/254499
#       And Codeplex user timiun: http://autospinstaller.codeplex.com/discussions/261598
# ===================================================================================
Function ConfigureDiagnosticLogging([xml]$xmlinput) {
  WriteLine
  Get-MajorVersionNumber $xmlinput
  $ULSLogConfig = $xmlinput.Configuration.Farm.Logging.ULSLogs
  $ULSLogDir = $ULSLogConfig.LogLocation
  $ULSLogDiskSpace = $ULSLogConfig.LogDiskSpaceUsageGB
  $ULSLogRetention = $ULSLogConfig.DaysToKeepLogs
  $ULSLogCutInterval = $ULSLogConfig.LogCutInterval
  Write-Host -ForegroundColor White " - Configuring SharePoint diagnostic (ULS) logging..."
  If (!([string]::IsNullOrEmpty($ULSLogDir))) {
      $doConfig = $true
      EnsureFolder $ULSLogDir
      $oldULSLogDir = $(Get-SPDiagnosticConfig).LogLocation
      $oldULSLogDir = $oldULSLogDir -replace ("%CommonProgramFiles%", "$env:CommonProgramFiles")
  }
  else {
      # Assume default value if none was specified in the XML input file
      $ULSLogDir = "$env:CommonProgramFiles\Microsoft Shared\Web Server Extensions\$env:spVer\LOGS"
  }
  If (!([string]::IsNullOrEmpty($ULSLogDiskSpace))) {
      $doConfig = $true
      $ULSLogMaxDiskSpaceUsageEnabled = $true
  }
  else {
      # Assume default values if none were specified in the XML input file
      $ULSLogDiskSpace = 1000
      $ULSLogMaxDiskSpaceUsageEnabled = $false
  }
  If (!([string]::IsNullOrEmpty($ULSLogRetention)))
  {$doConfig = $true}
  else {
      # Assume default value if none was specified in the XML input file
      $ULSLogRetention = 14
  }
  If (!([string]::IsNullOrEmpty($ULSLogCutInterval)))
  {$doConfig = $true}
  else {
      # Assume default value if none was specified in the XML input file
      $ULSLogCutInterval = 30
  }
  # Only modify the Diagnostic Config if we have specified at least one value in the XML input file
  If ($doConfig) {
      Write-Host -ForegroundColor White " - Setting SharePoint diagnostic (ULS) logging options:"
      Write-Host -ForegroundColor White "  - DaysToKeepLogs: $ULSLogRetention"
      Write-Host -ForegroundColor White "  - LogMaxDiskSpaceUsageEnabled: $ULSLogMaxDiskSpaceUsageEnabled"
      Write-Host -ForegroundColor White "  - LogDiskSpaceUsageGB: $ULSLogDiskSpace"
      Write-Host -ForegroundColor White "  - LogLocation: $ULSLogDir"
      Write-Host -ForegroundColor White "  - LogCutInterval: $ULSLogCutInterval"
      Set-SPDiagnosticConfig -DaysToKeepLogs $ULSLogRetention -LogMaxDiskSpaceUsageEnabled:$ULSLogMaxDiskSpaceUsageEnabled -LogDiskSpaceUsageGB $ULSLogDiskSpace -LogLocation $ULSLogDir -LogCutInterval $ULSLogCutInterval
      # Only move log files if the old & new locations are different, and if the old location actually had a value
      If (($ULSLogDir -ne $oldULSLogDir) -and (!([string]::IsNullOrEmpty($oldULSLogDir)))) {
          Write-Host -ForegroundColor White " - Moving any contents in old location $oldULSLogDir to $ULSLogDir..."
          ForEach ($item in $(Get-ChildItem -Path $oldULSLogDir) | Where-Object {$_.Name -like "*.log"}) {
              Move-Item -Path $oldULSLogDir\$item -Destination $ULSLogDir -Force -ErrorAction SilentlyContinue
          }
      }
  }
  # Finally, enable NTFS compression on the ULS log location to save disk space
  If ($ULSLogConfig.Compress -eq $true) {
      CompressFolder $ULSLogDir
  }
  WriteLine
}