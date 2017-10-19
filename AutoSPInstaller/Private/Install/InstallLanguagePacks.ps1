# ===================================================================================
# Func: Install Language Packs
# Desc: Install language packs and report on any languages installed
# ===================================================================================
Function InstallLanguagePacks([xml]$xmlinput) {
  WriteLine
  Get-MajorVersionNumber $xmlinput
  $spYears = @{"14" = "2010"; "15" = "2013"; "16" = "2016"}
  $spYear = $spYears.$env:spVer
  # Get installed languages from registry (HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Office Server\$env:spVer.0\InstalledLanguages)
  $installedOfficeServerLanguages = (Get-Item "HKLM:\Software\Microsoft\Office Server\$env:spVer.0\InstalledLanguages").GetValueNames() | Where-Object {$_ -ne ""}
  # Look for extracted language packs
  $extractedLanguagePacks = (Get-ChildItem -Path "$bits\$spYear\LanguagePacks" -Name -Include "??-??" -ErrorAction SilentlyContinue)
  $serverLanguagePacks = (Get-ChildItem -Path "$bits\$spYear\LanguagePacks" -Name -Include ServerLanguagePack_*.exe -ErrorAction SilentlyContinue)
  If ($extractedLanguagePacks -and (Get-ChildItem -Path "$bits\$spYear\LanguagePacks" -Name -Include "setup.exe" -Recurse -ErrorAction SilentlyContinue)) {
      Write-Host -ForegroundColor White " - Installing SharePoint Language Packs:"
      ForEach ($languagePackFolder in $extractedLanguagePacks) {
          $language = $installedOfficeServerLanguages | Where-Object {$_ -eq $languagePackFolder}
          If (!$language) {
              #                if (Test-Path -Path "$bits\$spYear\LanguagePacks\$languagePackFolder\setup.exe" -ErrorAction SilentlyContinue)
              #                {
              Write-Host -ForegroundColor Cyan "  - Installing extracted language pack $languagePackFolder..." -NoNewline
              $startTime = Get-Date
              Start-Process -WorkingDirectory "$bits\$spYear\LanguagePacks\$languagePackFolder\" -FilePath "setup.exe" -ArgumentList "/config $bits\$spYear\LanguagePacks\$languagePackFolder\Files\SetupSilent\config.xml"
              Show-Progress -Process setup -Color Cyan -Interval 5
              $delta, $null = (New-TimeSpan -Start $startTime -End (Get-Date)).ToString() -split "\."
              Write-Host -ForegroundColor White "  - Language pack $languagePackFolder setup completed in $delta."
              #                }
              #                else {Write-Host -ForegroundColor White " - None found."}
          }
      }
      Write-Host -ForegroundColor White " - Language Pack installation complete."
  }
  # Look for Server language pack installers
  ElseIf ($serverLanguagePacks) {
      Write-Host -ForegroundColor White " - Installing SharePoint Language Packs:"
      ForEach ($languagePack in $serverLanguagePacks) {
          # Slightly convoluted check to see if language pack is already installed, based on name of language pack file.
          # This only works if you've renamed your language pack(s) to follow the convention "ServerLanguagePack_XX-XX.exe" where <XX-XX> is a culture such as <en-us>.
          $language = $installedOfficeServerLanguages | Where-Object {$_ -eq (($languagePack -replace "ServerLanguagePack_", "") -replace ".exe", "")}
          If (!$language) {
              Write-Host -ForegroundColor Cyan " - Installing $languagePack..." -NoNewline
              $startTime = Get-Date
              Start-Process -FilePath "$bits\$spYear\LanguagePacks\$languagePack" -ArgumentList "/quiet /norestart"
              Show-Progress -Process $($languagePack -replace ".exe", "") -Color Cyan -Interval 5
              $delta, $null = (New-TimeSpan -Start $startTime -End (Get-Date)).ToString() -split "\."
              Write-Host -ForegroundColor White " - Language pack $languagePack setup completed in $delta."
              $language = (($languagePack -replace "ServerLanguagePack_", "") -replace ".exe", "")
              # Install Foundation Language Pack SP1, then Server Language Pack SP1, if found
              If (Get-ChildItem -Path "$bits\$spYear\LanguagePacks" -Name -Include spflanguagepack2010sp1-kb2460059-x64-fullfile-$language.exe -ErrorAction SilentlyContinue) {
                  Write-Host -ForegroundColor Cyan " - Installing Foundation language pack SP1 for $language..." -NoNewline
                  Start-Process -WorkingDirectory "$bits\$spYear\LanguagePacks\" -FilePath "spflanguagepack2010sp1-kb2460059-x64-fullfile-$language.exe" -ArgumentList "/quiet /norestart"
                  Show-Progress -Process spflanguagepack2010sp1-kb2460059-x64-fullfile-$language -Color Cyan -Interval 5
                  # Install Server Language Pack SP1, if found
                  If (Get-ChildItem -Path "$bits\$spYear\LanguagePacks" -Name -Include serverlanguagepack2010sp1-kb2460056-x64-fullfile-$language.exe -ErrorAction SilentlyContinue) {
                      Write-Host -ForegroundColor Cyan " - Installing Server language pack SP1 for $language..." -NoNewline
                      Start-Process -WorkingDirectory "$bits\$spYear\LanguagePacks\" -FilePath "serverlanguagepack2010sp1-kb2460056-x64-fullfile-$language.exe" -ArgumentList "/quiet /norestart"
                      Show-Progress -Process serverlanguagepack2010sp1-kb2460056-x64-fullfile-$language -Color Cyan -Interval 5
                  }
                  Else {
                      Write-Warning "Server Language Pack SP1 not found for $language!"
                      Write-Warning "You must install it for the language service pack patching process to be complete."
                  }
              }
              Else {Write-Host -ForegroundColor White " - No Language Pack service packs found."}
          }
          Else {
              Write-Host -ForegroundColor White " - Language $language already appears to be installed, skipping."
          }
      }
      Write-Host -ForegroundColor White " - Language Pack installation complete."
  }
  Else {
      Write-Host -ForegroundColor White " - No language pack installers found in $bits\$spYear\LanguagePacks, skipping."
  }

  # Get and note installed languages
  $installedOfficeServerLanguages = (Get-Item "HKLM:\Software\Microsoft\Office Server\$env:spVer.0\InstalledLanguages").GetValueNames() | Where-Object {$_ -ne ""}
  Write-Host -ForegroundColor White " - Currently installed languages:"
  ForEach ($language in $installedOfficeServerLanguages) {
      Write-Host "  -" ([System.Globalization.CultureInfo]::GetCultureInfo($language).DisplayName)
  }
  WriteLine
}