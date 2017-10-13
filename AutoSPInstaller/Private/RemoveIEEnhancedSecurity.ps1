Function RemoveIEEnhancedSecurity([xml]$xmlinput) {
  WriteLine
  If ($xmlinput.Configuration.Install.Disable.IEEnhancedSecurity -eq "True") {
      Write-Host -ForegroundColor White " - Disabling IE Enhanced Security..."
      Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name isinstalled -Value 0 -ErrorAction SilentlyContinue
      Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name isinstalled -Value 0 -ErrorAction SilentlyContinue
      Rundll32 iesetup.dll, IEHardenLMSettings, 1, True
      Rundll32 iesetup.dll, IEHardenUser, 1, True
      Rundll32 iesetup.dll, IEHardenAdmin, 1, True
      If (Test-Path "HKCU:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -ErrorAction SilentlyContinue) {
          Remove-Item -Path "HKCU:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
      }
      If (Test-Path "HKCU:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -ErrorAction SilentlyContinue) {
          Remove-Item -Path "HKCU:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
      }

      #This doesn't always exist
      Remove-ItemProperty "HKCU:\SOFTWARE\Microsoft\Internet Explorer\Main" "First Home Page" -ErrorAction SilentlyContinue
  }
  Else {
      Write-Host -ForegroundColor White " - Not configured to change IE Enhanced Security."
  }
  WriteLine
}