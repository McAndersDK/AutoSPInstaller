# ===================================================================================
# Func: InstallOfficeWebApps2010
# Desc: Installs the OWA binaries in unattended mode
# From: Ported over by user http://www.codeplex.com/site/users/view/cygoh originally from the InstallSharePoint function, fixed up by brianlala
# Originally posted on: http://autospinstaller.codeplex.com/discussions/233530
# ===================================================================================
Function InstallOfficeWebApps2010([xml]$xmlinput) {
  Get-MajorVersionNumber $xmlinput
  If ($xmlinput.Configuration.OfficeWebApps.Install -eq $true -and $env:spVer -eq "14") {
      # Check for SP2010
      WriteLine
      If (Test-Path "$env:CommonProgramFiles\Microsoft Shared\Web Server Extensions\$env:spVer\TEMPLATE\FEATURES\OfficeWebApps\feature.xml") {
          # Crude way of checking if Office Web Apps is already installed
          Write-Host -ForegroundColor White " - Office Web Apps binaries appear to be already installed - skipping install."
      }
      Else {
          $spYears = @{"14" = "2010"; "15" = "2013"; "16" = "2016"}
          $spYear = $spYears.$env:spVer
          # Install Office Web Apps Binaries
          If (Test-Path "$bits\$spYear\OfficeWebApps\setup.exe") {
              Write-Host -ForegroundColor Cyan " - Installing Office Web Apps binaries..." -NoNewline
              $startTime = Get-Date
              Start-Process "$bits\$spYear\OfficeWebApps\setup.exe" -ArgumentList "/config `"$configFileOWA`"" -WindowStyle Minimized
              Show-Progress -Process setup -Color Cyan -Interval 5
              $delta, $null = (New-TimeSpan -Start $startTime -End (Get-Date)).ToString() -split "\."
              Write-Host -ForegroundColor White " - Office Web Apps setup completed in $delta."
              If (-not $?) {
                  Throw " - Error $LASTEXITCODE occurred running $bits\$spYear\OfficeWebApps\setup.exe"
              }
              # Parsing most recent Office Web Apps Setup log for errors or restart requirements, since $LASTEXITCODE doesn't seem to work...
              $setupLog = Get-ChildItem -Path (Get-Item $env:TEMP).FullName | Where-Object {$_.Name -like "Wac Server Setup*"} | Sort-Object -Descending -Property "LastWriteTime" | Select-Object -first 1
              If ($setupLog -eq $null) {
                  Throw " - Could not find Office Web Apps Setup log file!"
              }
              # Get error(s) from log
              $setupLastError = $setupLog | select-string -SimpleMatch -Pattern "Error:" | Select-Object -Last 1 #| Where-Object {$_.Line -notlike "*Startup task*"}
              If ($setupLastError) {
                  Write-Warning $setupLastError.Line
                  Invoke-Item -Path "$((Get-Item $env:TEMP).FullName)\$setupLog"
                  Throw " - Review the log file and try to correct any error conditions."
              }
              # Look for restart requirement in log
              $setupRestartNotNeeded = $setupLog | select-string -SimpleMatch -Pattern "System reboot is not pending."
              If (!($setupRestartNotNeeded)) {
                  Throw " - Office Webapps setup requires a restart. Run the script again after restarting to continue."
              }
              Write-Host -ForegroundColor Cyan " - Waiting for SharePoint Products and Technologies Wizard to launch..." -NoNewline
              While ((Get-Process | Where-Object {$_.ProcessName -like "psconfigui*"}) -eq $null) {
                  Write-Host -ForegroundColor Green "." -NoNewline
                  Start-Sleep 1
              }
              # The Connect-SPConfigurationDatabase cmdlet throws an error about an "upgrade required" if we don't at least *launch* the Wizard, so we wait to let it launch, then kill it.
              Start-Sleep 10
              Write-Host -ForegroundColor White "OK."
              Write-Host -ForegroundColor White " - Exiting Products and Technologies Wizard - using PowerShell instead!"
              Stop-Process -Name psconfigui
          }
          Else {
              Throw " - Install path $bits\$spYear\OfficeWebApps not found!!"
          }
      }
      WriteLine
  }
}