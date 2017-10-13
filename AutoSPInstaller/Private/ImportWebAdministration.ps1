# ====================================================================================
# Func: ImportWebAdministration
# Desc: Load IIS WebAdministration Snapin/Module
# From: Inspired by http://stackoverflow.com/questions/1924217/powershell-load-webadministration-in-ps1-script-on-both-iis-7-and-iis-7-5
# ====================================================================================
Function ImportWebAdministration {
  $queryOS = Gwmi Win32_OperatingSystem
  $queryOS = $queryOS.Version
  Try {
      If ($queryOS.Contains("6.0")) {
          # Win2008
          If (!(Get-PSSnapin WebAdministration -ErrorAction SilentlyContinue)) {
              If (!(Test-Path $env:ProgramFiles\IIS\PowerShellSnapin\IIsConsole.psc1)) {
                  Start-Process -Wait -NoNewWindow -FilePath msiexec.exe -ArgumentList "/i `"$env:SPbits\PrerequisiteInstallerFiles\iis7psprov_x64.msi`" /passive /promptrestart"
              }
              Add-PSSnapin WebAdministration
          }
      }
      else {
          # Win2008R2 or Win2012
          Import-Module WebAdministration
      }
  }
  Catch {
      Throw " - Could not load IIS Administration module."

  }
}