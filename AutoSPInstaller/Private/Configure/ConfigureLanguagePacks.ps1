Function ConfigureLanguagePacks([xml]$xmlinput) {
  Get-MajorVersionNumber $xmlinput
  $installedOfficeServerLanguages = (Get-Item "HKLM:\Software\Microsoft\Office Server\$env:spVer.0\InstalledLanguages").GetValueNames() | Where-Object {$_ -ne ""}
  $languagePackInstalled = (Get-Item -Path "HKLM:\SOFTWARE\Microsoft\Shared Tools\Web Server Extensions\$env:spVer.0\WSS\").GetValue("LanguagePackInstalled")
  # If there were language packs installed we need to run psconfig to configure them
  If (($languagePackInstalled -eq "1") -and ($installedOfficeServerLanguages.Count -gt 1)) {
      WriteLine
      Write-Host -ForegroundColor White " - Configuring language packs..."
      # Let's sleep for a while to let the farm config catch up...
      Start-Sleep 20
      $retryNum += 1
      # Run PSConfig.exe per http://sharepoint.stackexchange.com/questions/9927/sp2010-psconfig-fails-trying-to-configure-farm-after-installing-language-packs
      # Note this was changed from v2v to b2b as suggested by CodePlex user jwthompson98
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
      WriteLine
  }
}