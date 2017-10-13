# ====================================================================================
# Func: InstallSMTP
# Desc: Installs the SMTP Server Windows feature
# ====================================================================================
Function InstallSMTP([xml]$xmlinput) {
  If (ShouldIProvision $xmlinput.Configuration.Farm.Services.SMTP -eq $true) {
      WriteLine
      Write-Host -ForegroundColor White " - Installing SMTP Server feature..."
      $queryOS = Gwmi Win32_OperatingSystem
      $queryOS = $queryOS.Version
      If ($queryOS.Contains("6.0")) {
          # Win2008
          Start-Process -FilePath servermanagercmd.exe -ArgumentList "-install smtp-server" -Wait -NoNewWindow
      }
      else {
          # Win2008 or Win2012
          # Get the current progress preference
          $pref = $ProgressPreference
          # Hide the progress bar since it tends to not disappear
          $ProgressPreference = "SilentlyContinue"
          Import-Module ServerManager
          Add-WindowsFeature -Name SMTP-Server | Out-Null
          # Restore progress preference
          $ProgressPreference = $pref
          If (!$?) {Throw " - Failed to install SMTP Server!"}
          else {
              # Need to set the newly-installed service to Automatic since it is set to Manual by default (per https://autospinstaller.codeplex.com/workitem/19744)
              Write-Host -ForegroundColor White "  - Setting SMTP service startup type to Automatic..."
              Set-Service SMTPSVC -StartupType Automatic -ErrorAction SilentlyContinue
          }
      }
      Write-Host -ForegroundColor White " - Done."
      WriteLine
  }
}