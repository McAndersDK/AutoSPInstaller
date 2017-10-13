# ===================================================================================
# Func: ConfigureUsageLogging
# Desc: Configures Usage Logging for the farm
# From: Submitted by Codeplex user deedubya (http://www.codeplex.com/site/users/view/deedubya); additional tweaks by @brianlala
# ===================================================================================
Function ConfigureUsageLogging([xml]$xmlinput) {
  WriteLine
  If (Get-SPUsageService) {
      Get-MajorVersionNumber $xmlinput
      $usageLogConfig = $xmlinput.Configuration.Farm.Logging.UsageLogs
      $usageLogDir = $usageLogConfig.UsageLogDir
      $usageLogMaxSpaceGB = $usageLogConfig.UsageLogMaxSpaceGB
      $usageLogCutTime = $usageLogConfig.UsageLogCutTime
      Write-Host -ForegroundColor White " - Configuring Usage Logging..."
      # Syntax for command: Set-SPUsageService [-LoggingEnabled {1 | 0}] [-UsageLogLocation <Path>] [-UsageLogMaxSpaceGB <1-20>] [-Verbose]
      # These are a per-farm settings, not per WSS Usage service application, as there can only be one per farm.
      Try {
          If (!([string]::IsNullOrEmpty($usageLogDir))) {
              EnsureFolder $usageLogDir
              $oldUsageLogDir = $(Get-SPUsageService).UsageLogDir
              $oldUsageLogDir = $oldUsageLogDir -replace ("%CommonProgramFiles%", "$env:CommonProgramFiles")
          }
          else {
              # Assume default value if none was specified in the XML input file
              $usageLogDir = "$env:CommonProgramFiles\Microsoft Shared\Web Server Extensions\$env:spVer\LOGS"
          }
          # UsageLogMaxSpaceGB must be between 1 and 20.
          If (($usageLogMaxSpaceGB -lt 1) -or ([string]::IsNullOrEmpty($usageLogMaxSpaceGB))) {$usageLogMaxSpaceGB = 5} # Default value
          If ($usageLogMaxSpaceGB -gt 20) {$usageLogMaxSpaceGB = 20} # Maximum value
          # UsageLogCutTime must be between 1 and 1440
          If (($usageLogCutTime -lt 1) -or ([string]::IsNullOrEmpty($usageLogCutTime))) {$usageLogCutTime = 30} # Default value
          If ($usageLogCutTime -gt 1440) {$usageLogCutTime = 1440} # Maximum value
          # Set-SPUsageService's LoggingEnabled is 0 for disabled, and 1 for enabled
          $loggingEnabled = 1
          Set-SPUsageService -LoggingEnabled $loggingEnabled -UsageLogLocation "$usageLogDir" -UsageLogMaxSpaceGB $usageLogMaxSpaceGB -UsageLogCutTime $usageLogCutTime | Out-Null
          # Only move log files if the old & new locations are different, and if the old location actually had a value
          If (($usageLogDir -ne $oldUsageLogDir) -and (!([string]::IsNullOrEmpty($oldUsageLogDir)))) {
              Write-Host -ForegroundColor White " - Moving any contents in old location $oldUsageLogDir to $usageLogDir..."
              ForEach ($item in $(Get-ChildItem -Path $oldUsageLogDir) | Where-Object {$_.Name -like "*.usage"}) {
                  Move-Item -Path $oldUsageLogDir\$item -Destination $usageLogDir -Force -ErrorAction SilentlyContinue
              }
          }
          # Finally, enable NTFS compression on the usage log location to save disk space
          If ($usageLogConfig.Compress -eq $true) {
              CompressFolder $usageLogDir
          }
      }
      Catch {
          Write-Output $_
          Throw " - Error configuring usage logging"
      }
      Write-Host -ForegroundColor White " - Done configuring usage logging."
  }
  Else {
      Write-Host -ForegroundColor White " - No usage service; skipping usage logging config."
  }
  WriteLine
}