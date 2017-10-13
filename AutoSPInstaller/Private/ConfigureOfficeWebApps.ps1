Function ConfigureOfficeWebApps([xml]$xmlinput) {
  Get-MajorVersionNumber $xmlinput
  If ($xmlinput.Configuration.OfficeWebApps.Install -eq $true -and $env:spVer -eq "14") {
      # Check for SP2010
      Writeline
      Try {
          Write-Host -ForegroundColor White " - Configuring Office Web Apps..."
          # Install Help Files
          Write-Host -ForegroundColor White " - Installing Help Collection..."
          Install-SPHelpCollection -All
          ##WaitForHelpInstallToFinish
          # Install application content
          Write-Host -ForegroundColor White " - Installing Application Content..."
          Install-SPApplicationContent
          # Secure resources
          Write-Host -ForegroundColor White " - Securing Resources..."
          Initialize-SPResourceSecurity
          # Install Services
          Write-Host -ForegroundColor White " - Installing Services..."
          Install-SPService
          If (!$?) {Throw}
          # Install (all) features
          Write-Host -ForegroundColor White " - Installing Features..."
          Install-SPFeature -AllExistingFeatures | Out-Null
      }
      Catch {
          Write-Output $_
          Throw " - Error configuring Office Web Apps!"
      }
      Writeline
  }
}