# ===================================================================================
# Func: ConfigureFarm
# Desc: Setup Central Admin Web Site, Check the topology of an existing farm, and configure the farm as required.
# ===================================================================================
Function ConfigureFarm([xml]$xmlinput) {
  WriteLine
  Get-MajorVersionNumber $xmlinput
  Write-Host -ForegroundColor White " - Configuring the SharePoint farm/server..."
  # Force a full configuration if this is the first web/app server in the farm
  If ((!($farmExists)) -or ($firstServer -eq $true) -or (CheckIfUpgradeNeeded -eq $true)) {[bool]$doFullConfig = $true}
  Try {
      If ($doFullConfig) {
          # Install Help Files
          Write-Host -ForegroundColor White " - Installing Help Collection..."
          Install-SPHelpCollection -All
          ##WaitForHelpInstallToFinish
      }
      # Secure resources
      Write-Host -ForegroundColor White " - Securing Resources..."
      Initialize-SPResourceSecurity
      # Install Services
      Write-Host -ForegroundColor White " - Installing Services..."
      Install-SPService
      If ($doFullConfig) {
          # Install (all) features
          Write-Host -ForegroundColor White " - Installing Features..."
          Install-SPFeature -AllExistingFeatures | Out-Null
      }
      CreateCentralAdmin $xmlinput
      # Update Central Admin branding text for SharePoint 2013 based on the XML input Environment attribute
      if ($env:spVer -ge "15" -and !([string]::IsNullOrEmpty($xmlinput.Configuration.Environment))) {
          # From http://www.wictorwilen.se/sharepoint-2013-central-administration-productivity-tip
          Write-Host -ForegroundColor White " - Updating Central Admin branding text to `"$($xmlinput.Configuration.Environment)`"..."
          $suiteBarBrandingText = "SharePoint - " + $xmlinput.Configuration.Environment
          $ca = Get-SPWebApplication -IncludeCentralAdministration | Where-Object {$_.IsAdministrationWebApplication}
          if ($env:spVer -ge "16") {
              # Updated for SharePoint 2016 - thanks Mark Kordelski (@delsk) for the tip!
              $ca.SuiteNavBrandingText = $suiteBarBrandingText
          }
          else {
              # Assume SharePoint 2013 method
              $ca.SuiteBarBrandingElementHtml = "<div class='ms-core-brandingText'>$suiteBarBrandingText</div>"
          }
          $ca.Update()
      }
      # Install application content if this is a new farm
      If ($doFullConfig) {
          Write-Host -ForegroundColor White " - Installing Application Content..."
          Install-SPApplicationContent
      }
  }
  Catch {
      If ($err -like "*update conflict*") {
          Write-Warning "A concurrency error occured, trying again."
          CreateCentralAdmin $xmlinput
      }
      Else {
          Throw $_
      }
  }
  # Check again if we need to run PSConfig, in case a CU was installed on a subsequent pass of AutoSPInstaller
  if (CheckIfUpgradeNeeded -eq $true) {
      $retryNum = 1
      Run-PSConfig
      $PSConfigLastError = Check-PSConfig
      while (!([string]::IsNullOrEmpty($PSConfigLastError)) -and $retryNum -le 4) {
          Write-Warning $PSConfigLastError.Line
          Write-Host -ForegroundColor White " - An error occurred running PSConfig, trying again ($retryNum)..."
          Start-Sleep -Seconds 5
          $retryNum += 1
          Run-PSConfig
          $PSConfigLastError = Check-PSConfig
      }
      If ($retryNum -ge 5) {
          Write-Host -ForegroundColor White " - After $retryNum retries to run PSConfig, trying GUI-based..."
          Start-Process -FilePath $PSConfigUI -NoNewWindow -Wait
      }
      Clear-Variable -Name PSConfigLastError -ErrorAction SilentlyContinue
      Clear-Variable -Name PSConfigLog -ErrorAction SilentlyContinue
      Clear-Variable -Name retryNum -ErrorAction SilentlyContinue
  }
  $spRegVersion = (Get-Item -Path "HKLM:\SOFTWARE\Microsoft\Shared Tools\Web Server Extensions\$env:spVer.0\").GetValue("Version")
  If (!($spRegVersion)) {
      Write-Host -ForegroundColor White " - Creating Version registry value (workaround for bug in PS-based install)"
      Write-Host -ForegroundColor White -NoNewline " - Getting version number... "
      $spBuild = "$($(Get-SPFarm).BuildVersion.Major).0.0.$($(Get-SPFarm).BuildVersion.Build)"
      Write-Host -ForegroundColor White "$spBuild"
      New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Shared Tools\Web Server Extensions\$env:spVer.0\" -Name Version -Value $spBuild -ErrorAction SilentlyContinue | Out-Null
  }
  # Set an environment variable for the 14/15 hive (SharePoint root)
  [Environment]::SetEnvironmentVariable($env:spVer, "$env:CommonProgramFiles\Microsoft Shared\Web Server Extensions\$env:spVer", "Machine")

  # Let's make sure the SharePoint Timer Service (SPTimerV4) is running
  # Per workaround in http://www.paulgrimley.com/2010/11/side-effects-of-attaching-additional.html
  If ((Get-Service SPTimerV4).Status -eq "Stopped") {
      Write-Host -ForegroundColor White " - Starting $((Get-Service SPTimerV4).DisplayName) Service..."
      Start-Service SPTimerV4
      If (!$?) {Throw " - Could not start Timer service!"}
  }
  if (((Get-WmiObject Win32_OperatingSystem).Version -like "6.2*" -or (Get-WmiObject Win32_OperatingSystem).Version -like "6.3*") -and ($env:spVer -eq "14")) {
      Write-Host -ForegroundColor White " - Stopping Default Web Site in a separate PowerShell window..."
      Start-Process -FilePath "$PSHOME\powershell.exe" -Verb RunAs -ArgumentList "-Command `". $env:dp0\AutoSPInstallerFunctions.ps1`; Stop-DefaultWebsite; Start-Sleep 10`"" -Wait
  }
  else {Stop-DefaultWebsite}
  Write-Host -ForegroundColor White " - Done initial farm/server config."
  WriteLine
}