# ====================================================================================
# Func: InstallForeFront
# Desc: Installs ForeFront Protection 2010 for SharePoint Sites
# ====================================================================================
Function InstallForeFront {
  If (ShouldIProvision $xmlinput.Configuration.ForeFront -eq $true) {
      WriteLine
      If (Test-Path "$env:PROGRAMFILES\Microsoft ForeFront Protection for SharePoint\Launcher.exe") {
          Write-Host -ForegroundColor White " - ForeFront binaries appear to be already installed - skipping install."
      }
      Else {
          # Install ForeFront
          If (Test-Path "$bits\$spYear\Forefront\setup.exe") {
              Write-Host -ForegroundColor White " - Installing ForeFront binaries..."
              Try {
                  Start-Process "$bits\$spYear\Forefront\setup.exe" -ArgumentList "/a `"$configFileForeFront`" /p" -Wait
                  If (-not $?) {Throw}
                  Write-Host -ForegroundColor White " - Done installing ForeFront."
              }
              Catch {
                  Throw " - Error $LASTEXITCODE occurred running $bits\$spYear\ForeFront\setup.exe"
              }
          }
          Else {
              Throw " - ForeFront installer not found in $bits\$spYear\ForeFront folder"
          }
      }
      WriteLine
  }
}