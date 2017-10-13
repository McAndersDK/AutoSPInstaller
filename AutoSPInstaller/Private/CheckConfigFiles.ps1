Function CheckConfigFiles([xml]$xmlinput) {
  #region SharePoint config file
  if (Test-Path -Path (Join-Path -Path $env:dp0 -ChildPath $($xmlinput.Configuration.Install.ConfigFile))) {
      # Just use the existing config file we found
      $script:configFile = Join-Path -Path $env:dp0 -ChildPath $($xmlinput.Configuration.Install.ConfigFile)
      Write-Host -ForegroundColor White " - Using existing config file:`n - $configFile"
  }
  else {
      Get-MajorVersionNumber $xmlinput
      # Write out a new config file based on defaults and the values provided in $inputFile
      $pidKey = $xmlinput.Configuration.Install.PIDKey
      # Do a rudimentary check on the presence and format of the product key
      if ($pidKey -notlike "?????-?????-?????-?????-?????") {
          throw " - The Product ID (PIDKey) is missing or badly formatted.`n - Check the value of <PIDKey> in `"$(Split-Path -Path $inputFile -Leaf)`" and try again."
      }
      $officeServerPremium = $xmlinput.Configuration.Install.SKU -replace "Enterprise", "1" -replace "Standard", "0"
      $installDir = $xmlinput.Configuration.Install.InstallDir
      # Set $installDir to the default value if it's not specified in $xmlinput
      if ([string]::IsNullOrEmpty($installDir)) {$installDir = "%PROGRAMFILES%\Microsoft Office Servers\"}
      $dataDir = $xmlinput.Configuration.Install.DataDir
      # Set $dataDir to the default value if it's not specified in $xmlinput
      if ([string]::IsNullOrEmpty($dataDir)) {$dataDir = "%PROGRAMFILES%\Microsoft Office Servers\$env:spVer.0\Data"}
      $dataDir = $dataDir.TrimEnd("\")
      $xmlConfig = @"
<Configuration>
<Package Id="sts">
  <Setting Id="LAUNCHEDFROMSETUPSTS" Value="Yes"/>
</Package>
<Package Id="spswfe">
  <Setting Id="SETUPCALLED" Value="1"/>
  <Setting Id="OFFICESERVERPREMIUM" Value="$officeServerPremium" />
</Package>
<ARP ARPCOMMENTS="Installed with AutoSPInstaller (http://autospinstaller.com)" ARPCONTACT="brian@autospinstaller.com" />
<Logging Type="verbose" Path="%temp%" Template="SharePoint Server Setup(*).log"/>
<Display Level="basic" CompletionNotice="No" AcceptEula="Yes"/>
<INSTALLLOCATION Value="$installDir"/>
<DATADIR Value="$dataDir"/>
<PIDKEY Value="$pidKey"/>
<Setting Id="SERVERROLE" Value="APPLICATION"/>
<Setting Id="USINGUIINSTALLMODE" Value="1"/>
<Setting Id="SETUPTYPE" Value="CLEAN_INSTALL"/>
<Setting Id="SETUP_REBOOT" Value="Never"/>
<Setting Id="AllowWindowsClientInstall" Value="True"/>
</Configuration>
"@
      $script:configFile = Join-Path -Path (Get-Item $env:TEMP).FullName -ChildPath $($xmlinput.Configuration.Install.ConfigFile)
      Write-Host -ForegroundColor White " - Writing $($xmlinput.Configuration.Install.ConfigFile) to $((Get-Item $env:TEMP).FullName)..."
      Set-Content -Path "$configFile" -Force -Value $xmlConfig
  }
  #endregion

  #region OWA config file
  if ($xmlinput.Configuration.OfficeWebApps.Install -eq $true) {
      if (Test-Path -Path (Join-Path -Path $env:dp0 -ChildPath $($xmlinput.Configuration.OfficeWebApps.ConfigFile))) {
          # Just use the existing config file we found
          $script:configFileOWA = Join-Path -Path $env:dp0 -ChildPath $($xmlinput.Configuration.OfficeWebApps.ConfigFile)
          Write-Host -ForegroundColor White " - Using existing OWA config file:`n - $configFileOWA"
      }
      else {
          # Write out a new config file based on defaults and the values provided in $inputFile
          $pidKeyOWA = $xmlinput.Configuration.OfficeWebApps.PIDKeyOWA
          # Do a rudimentary check on the presence and format of the product key
          if ($pidKeyOWA -notlike "?????-?????-?????-?????-?????") {
              throw " - The OWA Product ID (PIDKey) is missing or badly formatted.`n - Check the value of <PIDKeyOWA> in `"$(Split-Path -Path $inputFile -Leaf)`" and try again."
          }
          $xmlConfigOWA = @"
<Configuration>
  <Package Id="sts">
      <Setting Id="LAUNCHEDFROMSETUPSTS" Value="Yes"/>
  </Package>
  <ARP ARPCOMMENTS="Installed with AutoSPInstaller (http://autospinstaller.com)" ARPCONTACT="brian@autospinstaller.com" />
  <Logging Type="verbose" Path="%temp%" Template="Wac Server Setup(*).log"/>
  <Display Level="basic" CompletionNotice="no" />
  <Setting Id="SERVERROLE" Value="APPLICATION"/>
  <PIDKEY Value="$pidKeyOWA"/>
  <Setting Id="USINGUIINSTALLMODE" Value="1"/>
  <Setting Id="SETUPTYPE" Value="CLEAN_INSTALL"/>
  <Setting Id="SETUP_REBOOT" Value="Never"/>
  <Setting Id="AllowWindowsClientInstall" Value="True"/>
</Configuration>
"@
          $script:configFileOWA = Join-Path -Path (Get-Item $env:TEMP).FullName -ChildPath $($xmlinput.Configuration.OfficeWebApps.ConfigFile)
          Write-Host -ForegroundColor White " - Writing $($xmlinput.Configuration.OfficeWebApps.ConfigFile) to $((Get-Item $env:TEMP).FullName)..."
          Set-Content -Path "$configFileOWA" -Force -Value $xmlConfigOWA
      }
  }
  #endregion

  #region Project Server config file
  if ($xmlinput.Configuration.ProjectServer.Install -eq $true) {
      $pidKeyProjectServer = $xmlinput.Configuration.ProjectServer.PIDKeyProjectServer
      # Do a rudimentary check on the presence and format of the product key
      if ($pidKeyProjectServer -notlike "?????-?????-?????-?????-?????") {
          throw " - The Project Server Product ID (PIDKey) is missing or badly formatted.`n - Check the value of <PIDKeyProjectServer> in `"$(Split-Path -Path $inputFile -Leaf)`" and try again."
      }
      if ($env:spVer -eq "15") {
          # We only need this config file for Project Server 2013 / SP2013
          if (Test-Path -Path (Join-Path -Path $env:dp0 -ChildPath $($xmlinput.Configuration.ProjectServer.ConfigFile))) {
              # Just use the existing config file we found
              $script:configFileProjectServer = Join-Path -Path $env:dp0 -ChildPath $($xmlinput.Configuration.ProjectServer.ConfigFile)
              Write-Host -ForegroundColor White " - Using existing ProjectServer config file:`n - $configFileProjectServer"
          }
          else {
              # Write out a new config file based on defaults and the values provided in $inputFile
              $xmlConfigProjectServer = @"
<Configuration>
  <Package Id="sts">
    <Setting Id="LAUNCHEDFROMSETUPSTS" Value="Yes"/>
  </Package>
    <Package Id="PJSRVWFE">
      <Setting Id="PSERVER" Value="1"/>
    </Package>
  <ARP ARPCOMMENTS="Installed with AutoSPInstaller (http://autospinstaller.com)" ARPCONTACT="brian@autospinstaller.com" />
  <Logging Type="verbose" Path="%temp%" Template="Project Server Setup(*).log"/>
  <Display Level="basic" CompletionNotice="No" AcceptEula="Yes"/>
  <Setting Id="SERVERROLE" Value="APPLICATION"/>
  <PIDKEY Value="$pidKeyProjectServer"/>
  <Setting Id="USINGUIINSTALLMODE" Value="1"/>
  <Setting Id="SETUPTYPE" Value="CLEAN_INSTALL"/>
  <Setting Id="SETUP_REBOOT" Value="Never"/>
  <Setting Id="AllowWindowsClientInstall" Value="True"/>
</Configuration>
"@
              $script:configFileProjectServer = Join-Path -Path (Get-Item $env:TEMP).FullName -ChildPath $($xmlinput.Configuration.ProjectServer.ConfigFile)
              Write-Host -ForegroundColor White " - Writing $($xmlinput.Configuration.ProjectServer.ConfigFile) to $((Get-Item $env:TEMP).FullName)..."
              Set-Content -Path "$configFileProjectServer" -Force -Value $xmlConfigProjectServer
          }
      }
  }
  #endregion

  #region ForeFront answer file
  if (ShouldIProvision $xmlinput.Configuration.ForeFront -eq $true) {
      if (Test-Path -Path (Join-Path -Path $env:dp0 -ChildPath $($xmlinput.Configuration.ForeFront.ConfigFile))) {
          # Just use the existing answer file we found
          $script:configFileForeFront = Join-Path -Path $env:dp0 -ChildPath $($xmlinput.Configuration.ForeFront.ConfigFile)
          Write-Host -ForegroundColor White " - Using existing ForeFront answer file:`n - $configFileForeFront"
      }
      else {
          $farmAcct = $xmlinput.Configuration.Farm.Account.Username
          $farmAcctPWD = $xmlinput.Configuration.Farm.Account.Password
          # Write out a new answer file based on defaults and the values provided in $inputFile
          $xmlConfigForeFront = @"
<?xml version="1.0" encoding="utf-8"?>
<FSSAnswerFile>
<AcceptLicense>true</AcceptLicense>
<AcceptRestart>true</AcceptRestart>
<AcceptReplacePreviousVS>true</AcceptReplacePreviousVS>
<InstallType>Full</InstallType>
<Folders>
  <!--Leave these empty to use the default values-->
  <ProgramFolder></ProgramFolder>
  <DataFolder></DataFolder>
</Folders>
<ProxyInformation>
  <UseProxy>false</UseProxy>
  <ServerName></ServerName>
  <Port>80</Port>
  <UserName></UserName>
  <Password></Password>
</ProxyInformation>
<SharePointInformation>
  <UserName>$farmAcct</UserName>
  <Password>$farmAcctPWD</Password>
</SharePointInformation>
<EnableAntiSpamNow>false</EnableAntiSpamNow>
<EnableCustomerExperienceImprovementProgram>false</EnableCustomerExperienceImprovementProgram>
</FSSAnswerFile>
"@
          $script:configFileForeFront = Join-Path -Path (Get-Item $env:TEMP).FullName -ChildPath $($xmlinput.Configuration.ForeFront.ConfigFile)
          Write-Host -ForegroundColor White " - Writing $($xmlinput.Configuration.ForeFront.ConfigFile) to $((Get-Item $env:TEMP).FullName)..."
          Set-Content -Path "$configFileForeFront" -Force -Value $xmlConfigForeFront
      }
  }
  #endregion
}