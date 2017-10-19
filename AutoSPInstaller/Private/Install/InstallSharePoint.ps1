# ===================================================================================
# Func: InstallSharePoint
# Desc: Installs the SharePoint binaries in unattended mode
# ===================================================================================
Function InstallSharePoint([xml]$xmlinput) {
  WriteLine
  Get-MajorVersionNumber $xmlinput
  # Create a hash table with major version to product year mappings
  $spYears = @{"14" = "2010"; "15" = "2013"; "16" = "2016"}
  $spYear = $spYears.$env:spVer
  $spInstalled = Get-SharePointInstall
  If ($spInstalled) {
      Write-Host -ForegroundColor White " - SharePoint $spYear binaries appear to be already installed - skipping installation."
  }
  Else {
      # Install SharePoint Binaries
      If (Test-Path "$env:SPbits\setup.exe") {
          Write-Host -ForegroundColor Cyan " - Installing SharePoint $spYear binaries..." -NoNewline
          $startTime = Get-Date
          Start-Process "$env:SPbits\setup.exe" -ArgumentList "/config `"$configFile`"" -WindowStyle Minimized
          Show-Progress -Process setup -Color Cyan -Interval 5
          $delta, $null = (New-TimeSpan -Start $startTime -End (Get-Date)).ToString() -split "\."
          Write-Host -ForegroundColor White " - SharePoint $spYear setup completed in $delta."
          If (-not $?) {
              Throw " - Error $LASTEXITCODE occurred running $env:SPbits\setup.exe"
          }

          # Parsing most recent SharePoint Server Setup log for errors or restart requirements, since $LASTEXITCODE doesn't seem to work...
          $setupLog = Get-ChildItem -Path (Get-Item $env:TEMP).FullName | Where-Object {$_.Name -like "*SharePoint * Setup*"} | Sort-Object -Descending -Property "LastWriteTime" | Select-Object -first 1
          If ($setupLog -eq $null) {
              Throw " - Could not find SharePoint Server Setup log file!"
          }

          # Get error(s) from log
          $setupLastError = $setupLog | Select-String -SimpleMatch -Pattern "Error:" | Select-Object -Last 1
          $setupSuccess = $setupLog | Select-String -SimpleMatch -Pattern "Successfully installed package: oserver"
          # Look for a different success message if we are only installing Foundation
          if ($xmlinput.Configuration.Install.SKU -eq "Foundation") {$setupSuccess = $setupLog | Select-String -SimpleMatch -Pattern "Successfully installed package: wss"}
          If ($setupLastError -and !$setupSuccess) {
              Write-Warning $setupLastError.Line
              Invoke-Item -Path "$((Get-Item $env:TEMP).FullName)\$setupLog"
              Throw " - Review the log file and try to correct any error conditions."
          }
          # Look for restart requirement in log
          $setupRestartNotNeeded = $setupLog | select-string -SimpleMatch -Pattern "System reboot is not pending."
          If (!($setupRestartNotNeeded)) {
              Throw " - SharePoint setup requires a restart. Run the script again after restarting to continue."
          }

          Write-Host -ForegroundColor Cyan " - Waiting for SharePoint Products and Technologies Wizard to launch..." -NoNewline
          While ((Get-Process | Where-Object {$_.ProcessName -like "psconfigui*"}) -eq $null) {
              Write-Host -ForegroundColor Cyan "." -NoNewline
              Start-Sleep 1
          }
          Write-Host -ForegroundColor Green "Done."
          Write-Host -ForegroundColor White " - Exiting Products and Technologies Wizard - using PowerShell instead!"
          Stop-Process -Name psconfigui
      }
      Else {
          Throw " - Install path $env:SPbits not found!!"
      }
  }
  WriteLine
}