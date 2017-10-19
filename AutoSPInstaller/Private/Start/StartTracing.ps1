Function StartTracing ($server) {
  If (!$isTracing) {
      # Look for an existing log file start time in the registry so we can re-use the same log file
      $regKey = Get-Item -Path "HKLM:\SOFTWARE\AutoSPInstaller\" -ErrorAction SilentlyContinue
      If ($regKey) {$script:Logtime = $regkey.GetValue("LogTime")}
      If ([string]::IsNullOrEmpty($logtime)) {$script:Logtime = Get-Date -Format yyyy-MM-dd_h-mm}
      If ($server) {$script:LogFile = "$env:USERPROFILE\Desktop\AutoSPInstaller-$server-$script:Logtime.rtf"}
      else {$script:LogFile = "$env:USERPROFILE\Desktop\AutoSPInstaller-$script:Logtime.rtf"}
      Start-Transcript -Path $logFile -Append -Force
      If ($?) {$script:isTracing = $true}
  }
}