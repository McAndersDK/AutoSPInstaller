# ===================================================================================
# Func: InstallProjectServer
# Desc: Installs the Project Server binaries in unattended mode
# ===================================================================================
Function InstallProjectServer([xml]$xmlinput) {
  Get-MajorVersionNumber $xmlinput
  If ($xmlinput.Configuration.ProjectServer.Install -eq $true -and $env:SPVer -eq "15") {
      # Check for SP2013 since we don't support installing Project Server 2010 at this point, and it's included with SP2016
      WriteLine
      # Create a hash table with major version to product year mappings
      $spYears = @{"14" = "2010"; "15" = "2013"; "16" = "2016"}
      $spYear = $spYears.$env:spVer
      # There has to be a better way to check whether Project Server is installed...
      $projectServerInstalled = Test-Path -Path "$env:CommonProgramFiles\Microsoft Shared\Web Server Extensions\$env:spVer\CONFIG\BIN\Microsoft.ProjectServer.dll"
      If ($projectServerInstalled) {
          Write-Host -ForegroundColor White " - Project Server $spYear binaries appear to be already installed - skipping installation."
      }
      Else {
          # Install Project Server Binaries
          If (Test-Path "$bits\$spYear\ProjectServer\setup.exe") {
              Write-Host -ForegroundColor Cyan " - Installing Project Server $spYear binaries..." -NoNewline
              $startTime = Get-Date
              Start-Process "$bits\$spYear\ProjectServer\setup.exe" -ArgumentList "/config `"$configFileProjectServer`"" -WindowStyle Minimized
              Show-Progress -Process setup -Color Cyan -Interval 5
              $delta, $null = (New-TimeSpan -Start $startTime -End (Get-Date)).ToString() -split "\."
              Write-Host -ForegroundColor White " - Project Server $spYear setup completed in $delta."
              If (-not $?) {
                  Throw " - Error $LASTEXITCODE occurred running $bits\$spYear\ProjectServer\setup.exe"
              }

              # Parsing most recent Project Server Setup log for errors or restart requirements, since $LASTEXITCODE doesn't seem to work...
              $setupLog = Get-ChildItem -Path (Get-Item $env:TEMP).FullName | Where-Object {$_.Name -like "Project Server Setup*"} | Sort-Object -Descending -Property "LastWriteTime" | Select-Object -first 1
              If ($setupLog -eq $null) {
                  Throw " - Could not find Project Server Setup log file!"
              }

              # Get error(s) from log
              $setupLastError = $setupLog | Select-String -SimpleMatch -Pattern "Error:" | Select-Object -Last 1
              $setupSuccess = $setupLog | Select-String -SimpleMatch -Pattern "Successfully installed package: pserver"
              if (!$setupSuccess) {$setupSuccess = $setupLog | Select-String -SimpleMatch -Pattern "Successfully configured package: pserver"} # In case we are just configuring pre-installed or partially-installed product
              If ($setupLastError -and !$setupSuccess) {
                  Write-Warning $setupLastError.Line
                  Invoke-Item -Path "$((Get-Item $env:TEMP).FullName)\$setupLog"
                  Throw " - Review the log file and try to correct any error conditions."
              }
              # Look for restart requirement in log, but only if we installed fresh vs. just configuring
              if ($setupSuccess -like "*installed*") {
                  $setupRestartNotNeeded = $setupLog | select-string -SimpleMatch -Pattern "System reboot is not pending."
                  If (!$setupRestartNotNeeded) {
                      Throw " - Project Server setup requires a restart. Run the script again after restarting to continue."
                  }
              }
              Write-Host -ForegroundColor Cyan " - Waiting for SharePoint Products and Technologies Wizard to launch..." -NoNewline
              While ((Get-Process | Where-Object {$_.ProcessName -like "psconfigui*"}) -eq $null) {
                  Write-Host -ForegroundColor Cyan "." -NoNewline
                  Start-Sleep 1
              }
              Write-Host -ForegroundColor White "OK."
              Write-Host -ForegroundColor White " - Exiting Products and Technologies Wizard - using PowerShell instead!"
              Stop-Process -Name psconfigui
          }
          Else {
              Write-Warning "Project Server installation requested, but install path $bits\$spYear\ProjectServer not found!!"
              pause "continue"
          }
      }
      WriteLine
  }
}