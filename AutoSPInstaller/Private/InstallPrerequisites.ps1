# ===================================================================================
# Func: InstallPrerequisites
# Desc: If SharePoint is not already installed install the Prerequisites
# ===================================================================================
Function InstallPrerequisites([xml]$xmlinput) {
  WriteLine
  # Remove any lingering post-reboot registry values first
  Remove-ItemProperty -Path "HKLM:\SOFTWARE\AutoSPInstaller\" -Name "RestartRequired" -ErrorAction SilentlyContinue
  Remove-ItemProperty -Path "HKLM:\SOFTWARE\AutoSPInstaller\" -Name "CancelRemoteInstall" -ErrorAction SilentlyContinue
  # Check for whether UAC was previously enabled and should therefore be re-enabled after an automatic restart
  $regKey = Get-Item -Path "HKLM:\SOFTWARE\AutoSPInstaller\" -ErrorAction SilentlyContinue
  If ($regKey) {$UACWasEnabled = $regkey.GetValue("UACWasEnabled")}
  If ($UACWasEnabled -eq 1) {Set-UserAccountControl 1}
  # Now, remove the lingering registry UAC flag
  Remove-ItemProperty -Path "HKLM:\SOFTWARE\AutoSPInstaller\" -Name "UACWasEnabled" -ErrorAction SilentlyContinue
  Get-MajorVersionNumber $xmlinput
  # Create a hash table with major version to product year mappings
  $spYears = @{"14" = "2010"; "15" = "2013"; "16" = "2016"}
  $spYear = $spYears.$env:spVer
  $spInstalled = Get-SharePointInstall
  If ($spInstalled) {
      Write-Host -ForegroundColor White " - SharePoint $spYear prerequisites appear be already installed - skipping install."
  }
  Else {
      Write-Host -ForegroundColor White " - Installing Prerequisite Software:"
      If ((Gwmi Win32_OperatingSystem).Version -eq "6.1.7601") {
          # Win2008 R2 SP1
          # Due to the SharePoint 2010 issue described in http://support.microsoft.com/kb/2581903 (related to installing the KB976462 hotfix)
          # (and simply to speed things up for SharePoint 2013) we install the .Net 3.5.1 features prior to attempting the PrerequisiteInstaller on Win2008 R2 SP1
          Write-Host -ForegroundColor White "  - .Net Framework 3.5.1..." -NoNewline
          # Get the current progress preference
          $pref = $ProgressPreference
          # Hide the progress bar since it tends to not disappear
          $ProgressPreference = "SilentlyContinue"
          Import-Module ServerManager
          If (!(Get-WindowsFeature -Name NET-Framework).Installed) {
              Add-WindowsFeature -Name NET-Framework | Out-Null
              Write-Host -ForegroundColor Green "Done."
          }
          else {Write-Host -ForegroundColor White "Already installed."}
          # Restore progress preference
          $ProgressPreference = $pref

      }
      Try {
          # Detect if we're installing SP2010 on Windows Server 2012 (R2)
          if ((Get-WmiObject Win32_OperatingSystem).Version -like "6.2*") {
              $osName = "Windows Server 2012"
              $win2012 = $true
              $prereqInstallerRequiredBuild = "7009" # i.e. minimum required version of PrerequisiteInstaller.exe for Windows Server 2012 is 14.0.7009.1000
          }
          elseif ((Get-WmiObject Win32_OperatingSystem).Version -like "6.3*") {
              $osName = "Windows Server 2012 R2"
              $win2012 = $true
              $prereqInstallerRequiredBuild = "7104" # i.e. minimum required version of PrerequisiteInstaller.exe for Windows Server 2012 R2 is 14.0.7104.5000
          }
          else {$win2012 = $false}
          if ($win2012 -and ($env:spVer -eq "14")) {
              Write-Host -ForegroundColor White " - Checking for required version of PrerequisiteInstaller.exe..." -NoNewline
              $prereqInstallerVer = (Get-Command $env:SPbits\PrerequisiteInstaller.exe).FileVersionInfo.ProductVersion
              $null, $null, $prereqInstallerBuild, $null = $prereqInstallerVer -split "\."
              # Check that the version of PrerequisiteInstaller.exe included in the MS-provided SharePoint 2010 SP2-integrated package meets the minimum required version for the detected OS
              if ($prereqInstallerBuild -lt $prereqInstallerRequiredBuild) {
                  Write-Host -ForegroundColor White "."
                  Throw " - SharePoint 2010 is officially unsupported on $osName without an updated set of SP2-integrated binaries - see http://support.microsoft.com/kb/2724471"
              }
              else {Write-Host -BackgroundColor Green -ForegroundColor Black "OK."}
          }
          # Install using PrerequisiteInstaller as usual
          If ($xmlinput.Configuration.Install.OfflineInstall -eq $true) {
              # Install all prerequisites from local folder
              # Try to pre-install .Net Framework 3.5.1 on Windows Server 2012, 2012 R2 or 2016
              if ((Get-WmiObject Win32_OperatingSystem).Version -like "6.2*" -or (Get-WmiObject Win32_OperatingSystem).Version -like "6.3*" -or (Get-WmiObject Win32_OperatingSystem).Version -like "6.4*" -or (Get-WmiObject Win32_OperatingSystem).Version -like "10.0*") {
                  if (Test-Path -Path "$env:SPbits\PrerequisiteInstallerFiles\sxs") {
                      Write-Host -ForegroundColor White "  - .Net Framework 3.5.1 from `"$env:SPbits\PrerequisiteInstallerFiles\sxs`"..." -NoNewline
                      # Get the current progress preference
                      $pref = $ProgressPreference
                      # Hide the progress bar since it tends to not disappear
                      $ProgressPreference = "SilentlyContinue"
                      Import-Module ServerManager
                      if (!(Get-WindowsFeature -Name NET-Framework-Core).Installed) {
                          Start-Process -FilePath DISM.exe -ArgumentList "/Online /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:`"$env:SPbits\PrerequisiteInstallerFiles\sxs`"" -NoNewWindow -Wait
                          ##Install-WindowsFeature NET-Framework-Core –Source "$env:SPbits\PrerequisiteInstallerFiles\sxs" | Out-Null
                          Write-Host -ForegroundColor Green "Done."
                      }
                      else {Write-Host -ForegroundColor White "Already installed."}
                      # Restore progress preference
                      $ProgressPreference = $pref
                  }
                  else {Write-Host -ForegroundColor White " - Could not locate source for .Net Framework 3.5.1`n - The PrerequisiteInstaller will attempt to download it."}
              }
              if ($env:spVer -eq "14") {
                  # SP2010
                  Write-Host -ForegroundColor White "  - SQL Native Client..."
                  # Install SQL native client before running pre-requisite installer as newest versions require an IACCEPTSQLNCLILICENSETERMS=YES argument
                  Start-Process "$env:SPbits\PrerequisiteInstallerFiles\sqlncli.msi" -Wait -ArgumentList "/passive /norestart IACCEPTSQLNCLILICENSETERMS=YES"
                  Write-Host -ForegroundColor Cyan "  - Running Prerequisite Installer (offline mode)..." -NoNewline
                  $startTime = Get-Date
                  Start-Process "$env:SPbits\PrerequisiteInstaller.exe" -ArgumentList "/unattended `
                                                                                      /SQLNCli:`"$env:SPbits\PrerequisiteInstallerFiles\sqlncli.msi`" `
                                                                                      /ChartControl:`"$env:SPbits\PrerequisiteInstallerFiles\MSChart.exe`" `
                                                                                      /NETFX35SP1:`"$env:SPbits\PrerequisiteInstallerFiles\dotnetfx35.exe`" `
                                                                                      /PowerShell:`"$env:SPbits\PrerequisiteInstallerFiles\Windows6.0-KB968930-x64.msu`" `
                                                                                      /KB976394:`"$env:SPbits\PrerequisiteInstallerFiles\Windows6.0-KB976394-x64.msu`" `
                                                                                      /KB976462:`"$env:SPbits\PrerequisiteInstallerFiles\Windows6.1-KB976462-v2-x64.msu`" `
                                                                                      /IDFX:`"$env:SPbits\PrerequisiteInstallerFiles\Windows6.0-KB974405-x64.msu`" `
                                                                                      /IDFXR2:`"$env:SPbits\PrerequisiteInstallerFiles\Windows6.1-KB974405-x64.msu`" `
                                                                                      /Sync:`"$env:SPbits\PrerequisiteInstallerFiles\Synchronization.msi`" `
                                                                                      /FilterPack:`"$env:SPbits\PrerequisiteInstallerFiles\FilterPack\FilterPack.msi`" `
                                                                                      /ADOMD:`"$env:SPbits\PrerequisiteInstallerFiles\SQLSERVER2008_ASADOMD10.msi`" `
                                                                                      /ReportingServices:`"$env:SPbits\PrerequisiteInstallerFiles\rsSharePoint.msi`" `
                                                                                      /Speech:`"$env:SPbits\PrerequisiteInstallerFiles\SpeechPlatformRuntime.msi`" `
                                                                                      /SpeechLPK:`"$env:SPbits\PrerequisiteInstallerFiles\MSSpeech_SR_en-US_TELE.msi`""
                  If (-not $?) {Throw}
              }
              elseif ($env:spVer -eq "15") {
                  #SP2013
                  Write-Host -ForegroundColor Cyan "  - Running Prerequisite Installer (offline mode)..." -NoNewline
                  $startTime = Get-Date
                  if (CheckFor2013SP1) {
                      # Include WCFDataServices56 as required by updated SP1 prerequisiteinstaller.exe
                      Start-Process "$env:SPbits\PrerequisiteInstaller.exe" -ArgumentList "/unattended `
                                                                                           /SQLNCli:`"$env:SPbits\PrerequisiteInstallerFiles\sqlncli.msi`" `
                                                                                           /PowerShell:`"$env:SPbits\PrerequisiteInstallerFiles\Windows6.1-KB2506143-x64.msu`" `
                                                                                           /NETFX:`"$env:SPbits\PrerequisiteInstallerFiles\dotNetFx45_Full_x86_x64.exe`" `
                                                                                           /IDFX:`"$env:SPbits\PrerequisiteInstallerFiles\Windows6.1-KB974405-x64.msu`" `
                                                                                           /IDFX11:`"$env:SPbits\PrerequisiteInstallerFiles\MicrosoftIdentityExtensions-64.msi`" `
                                                                                           /Sync:`"$env:SPbits\PrerequisiteInstallerFiles\Synchronization.msi`" `
                                                                                           /AppFabric:`"$env:SPbits\PrerequisiteInstallerFiles\WindowsServerAppFabricSetup_x64.exe`" `
                                                                                           /KB2671763:`"$env:SPbits\PrerequisiteInstallerFiles\AppFabric1.1-RTM-KB2671763-x64-ENU.exe`" `
                                                                                           /MSIPCClient:`"$env:SPbits\PrerequisiteInstallerFiles\setup_msipc_x64.msi`" `
                                                                                           /WCFDataServices:`"$env:SPbits\PrerequisiteInstallerFiles\WcfDataServices.exe`" `
                                                                                           /WCFDataServices56:`"$env:SPbits\PrerequisiteInstallerFiles\WcfDataServices56.exe`""
                      If (-not $?) {Throw}
                  }
                  else {
                      # Just install the pre-SP1 set of prerequisites
                      Start-Process "$env:SPbits\PrerequisiteInstaller.exe" -ArgumentList "/unattended `
                                                                                           /SQLNCli:`"$env:SPbits\PrerequisiteInstallerFiles\sqlncli.msi`" `
                                                                                           /PowerShell:`"$env:SPbits\PrerequisiteInstallerFiles\Windows6.1-KB2506143-x64.msu`" `
                                                                                           /NETFX:`"$env:SPbits\PrerequisiteInstallerFiles\dotNetFx45_Full_x86_x64.exe`" `
                                                                                           /IDFX:`"$env:SPbits\PrerequisiteInstallerFiles\Windows6.1-KB974405-x64.msu`" `
                                                                                           /IDFX11:`"$env:SPbits\PrerequisiteInstallerFiles\MicrosoftIdentityExtensions-64.msi`" `
                                                                                           /Sync:`"$env:SPbits\PrerequisiteInstallerFiles\Synchronization.msi`" `
                                                                                           /AppFabric:`"$env:SPbits\PrerequisiteInstallerFiles\WindowsServerAppFabricSetup_x64.exe`" `
                                                                                           /KB2671763:`"$env:SPbits\PrerequisiteInstallerFiles\AppFabric1.1-RTM-KB2671763-x64-ENU.exe`" `
                                                                                           /MSIPCClient:`"$env:SPbits\PrerequisiteInstallerFiles\setup_msipc_x64.msi`" `
                                                                                           /WCFDataServices:`"$env:SPbits\PrerequisiteInstallerFiles\WcfDataServices.exe`""
                      If (-not $?) {Throw}
                  }
              }
              elseif ($env:spVer -eq "16") {
                  #SP2016
                  Write-Host -ForegroundColor Cyan "  - Running Prerequisite Installer (offline mode)..." -NoNewline
                  $startTime = Get-Date
                  Start-Process "$env:SPbits\PrerequisiteInstaller.exe" -ArgumentList "/unattended `
                                                                                       /SQLNCli:`"$env:SPbits\PrerequisiteInstallerFiles\sqlncli.msi`" `
                                                                                       /Sync:`"$env:SPbits\PrerequisiteInstallerFiles\Synchronization.msi`" `
                                                                                       /AppFabric:`"$env:SPbits\PrerequisiteInstallerFiles\WindowsServerAppFabricSetup_x64.exe`" `
                                                                                       /IDFX11:`"$env:SPbits\PrerequisiteInstallerFiles\MicrosoftIdentityExtensions-64.msi`" `
                                                                                       /MSIPCClient:`"$env:SPbits\PrerequisiteInstallerFiles\setup_msipc_x64.exe`" `
                                                                                       /KB3092423:`"$env:SPbits\PrerequisiteInstallerFiles\AppFabric-KB3092423-x64-ENU.exe`" `
                                                                                       /WCFDataServices56:`"$env:SPbits\PrerequisiteInstallerFiles\WcfDataServices.exe`" `
                                                                                       /ODBC:`"$env:SPbits\PrerequisiteInstallerFiles\msodbcsql.msi`" `
                                                                                       /DotNetFx:`"$env:SPbits\PrerequisiteInstallerFiles\NDP46-KB3045557-x86-x64-AllOS-ENU.exe`" `
                                                                                       /MSVCRT11:`"$env:SPbits\PrerequisiteInstallerFiles\vcredist_x64.exe`" `
                                                                                       /MSVCRT14:`"$env:SPbits\PrerequisiteInstallerFiles\vc_redist.x64.exe`""
                  If (-not $?) {Throw}
              }
          }
          else {
              # Regular prerequisite install - download required files
              Write-Host -ForegroundColor Cyan "  - Running Prerequisite Installer (online mode)..." -NoNewline
              $startTime = Get-Date
              Start-Process "$env:SPbits\PrerequisiteInstaller.exe" -ArgumentList "/unattended" -WindowStyle Minimized
              If (-not $?) {Throw}
          }
          Show-Progress -Process PrerequisiteInstaller -Color Cyan -Interval 5
          $delta, $null = (New-TimeSpan -Start $startTime -End (Get-Date)).ToString() -split "\."
          Write-Host -ForegroundColor White "  - Prerequisite Installer completed in $delta."
          If ($env:spVer -eq "15") {
              # SP2013
              # Install the "missing prerequisites" for SP2013 per http://www.toddklindt.com/blog/Lists/Posts/Post.aspx?ID=349
              # Expand hotfix executable to $env:SPbits\PrerequisiteInstallerFiles\
              if ((Gwmi Win32_OperatingSystem).Version -eq "6.1.7601") {
                  # Win2008 R2 SP1
                  $missingHotfixes = @{"Windows6.1-KB2554876-v2-x64.msu" = "http://hotfixv4.microsoft.com/Windows%207/Windows%20Server2008%20R2%20SP1/sp2/Fix368051/7600/free/433385_intl_x64_zip.exe";
                      "Windows6.1-KB2708075-x64.msu"                     = "http://hotfixv4.microsoft.com/Windows%207/Windows%20Server2008%20R2%20SP1/sp2/Fix402568/7600/free/447698_intl_x64_zip.exe";
                      "Windows6.1-KB2472264-v3-x64.msu"                  = "http://hotfixv4.microsoft.com/Windows%207/Windows%20Server2008%20R2%20SP1/sp2/Fix354400/7600/free/427087_intl_x64_zip.exe";
                      "Windows6.1-KB2567680-x64.msu"                     = "http://download.microsoft.com/download/C/D/A/CDAF5DD8-3B9A-4F8D-A48F-BEFE53C5B249/Windows6.1-KB2567680-x64.msu";
                      "NDP45-KB2759112-x64.exe"                          = "http://download.microsoft.com/download/5/6/3/5631B753-A009-48AF-826C-2D2C29B94172/NDP45-KB2759112-x64.exe"
                  }
              }
              elseif ((Get-WmiObject Win32_OperatingSystem).Version -like "6.2*") {
                  # Win2012
                  $missingHotfixes = @{"Windows8-RT-KB2765317-x64.msu" = "http://download.microsoft.com/download/0/2/E/02E9E569-5462-48EB-AF57-8DCCF852E6F4/Windows8-RT-KB2765317-x64.msu"}
              }
              else {} # Reserved for Win2012 R2
              if ($missingHotfixes.Count -ge 1) {
                  Write-Host -ForegroundColor White "  - SharePoint 2013 `"missing hotfix`" prerequisites..."
                  $hotfixLocation = $env:SPbits + "\PrerequisiteInstallerFiles"
              }
              ForEach ($hotfixPatch in $missingHotfixes.Keys) {
                  $hotfixKB = $hotfixPatch.Split('-') | Where-Object {$_ -like "KB*"}
                  # Check if the hotfix is already installed
                  Write-Host -ForegroundColor White "   - Checking for $hotfixKB..." -NoNewline
                  If (!(Get-HotFix -Id $hotfixKB -ErrorAction SilentlyContinue)) {
                      Write-Host -ForegroundColor White "Missing; attempting to install..."
                      $hotfixUrl = $missingHotfixes.$hotfixPatch
                      $hotfixFile = $hotfixUrl.Split('/')[-1]
                      $hotfixFileZip = $hotfixFile + ".zip"
                      $hotfixZipPath = Join-Path -Path $hotfixLocation -ChildPath $hotfixFileZip
                      # Check if the .msu/.exe file is already present
                      If (Test-Path "$hotfixLocation\$hotfixPatch") {
                          Write-Host -ForegroundColor White "    - Hotfix file `"$hotfixPatch`" found."
                      }
                      Else {
                          # Check if the downloaded package exists with a .zip extension
                          If (!([string]::IsNullOrEmpty($hotfixFileZip)) -and (Test-Path "$hotfixLocation\$hotfixFileZip")) {
                              Write-Host -ForegroundColor White "    - File $hotfixFile (zip) found."
                          }
                          Else {
                              # Check if the downloaded package exists
                              If (Test-Path "$hotfixLocation\$hotfixFile") {
                                  Write-Host -ForegroundColor White "    - File $hotfixFile found."
                              }
                              Else {
                                  # Go ahead and download the missing package
                                  Try {
                                      # Begin download
                                      Write-Host -ForegroundColor White "    - Hotfix $hotfixPatch not found in $env:SPbits\PrerequisiteInstallerFiles"
                                      Write-Host -ForegroundColor White "    - Attempting to download..." -NoNewline
                                      Import-Module BitsTransfer | Out-Null
                                      Start-BitsTransfer -Source $hotfixUrl -Destination "$hotfixLocation\$hotfixFile" -DisplayName "Downloading `'$hotfixFile`' to $hotfixLocation" -Priority Foreground -Description "From $hotfixUrl..." -ErrorVariable err
                                      if ($err) {Write-Host "."; Throw "  - Could not download from $hotfixUrl!"}
                                      Write-Host -ForegroundColor White "Done!"
                                  }
                                  Catch {
                                      Write-Warning "  - An error occurred attempting to download `"$hotfixFile`"."
                                      break
                                  }
                              }
                              if ($hotfixFile -like "*zip.exe") {
                                  # The hotfix is probably a self-extracting exe
                                  # Give the file a .zip extension so we can work with it like a compressed folder
                                  Write-Host -ForegroundColor White "    - Renaming $hotfixFile to $hotfixFileZip..."
                                  Rename-Item -Path "$hotfixLocation\$hotfixFile" -NewName $hotfixFileZip -Force -ErrorAction SilentlyContinue
                              }
                          }
                          If (Test-Path "$hotfixLocation\$hotfixFileZip") {
                              # The zipped hotfix exists, ands needs to be extracted
                              Write-Host -ForegroundColor White "    - Extracting `"$hotfixPatch`" from `"$hotfixFile`"..." -NoNewline
                              $shell = New-Object -ComObject Shell.Application
                              $hotfixFileZipNs = $shell.Namespace($hotfixZipPath)
                              $hotfixLocationNs = $shell.Namespace($hotfixLocation)
                              $hotfixLocationNs.Copyhere($hotfixFileZipNs.items())
                              Write-Host -ForegroundColor Green "Done."
                          }
                      }
                      # Install the hotfix
                      $extractedHotfixPath = Join-Path -Path $hotfixLocation -ChildPath $hotfixPatch
                      Write-Host -ForegroundColor White "    - Installing hotfix $hotfixPatch..." -NoNewline
                      if ($hotfixPatch -like "*.msu") {
                          # Treat as a Windows Update patch
                          Start-Process -FilePath "wusa.exe" -ArgumentList "`"$extractedHotfixPath`" /quiet /norestart" -Wait -NoNewWindow
                      }
                      else {
                          # Treat as an executable (.exe) patch
                          Start-Process -FilePath "$extractedHotfixPath" -ArgumentList "/passive /norestart" -Wait -NoNewWindow
                      }
                      Write-Host -ForegroundColor Green "Done."
                  }
                  Else {Write-Host -ForegroundColor White "Already installed."}
              }
          }
      }
      Catch {
          Write-Host -ForegroundColor Cyan "."
          Write-Host -ForegroundColor Red " - Error: $_ $LASTEXITCODE"
          If ($LASTEXITCODE -eq "1") {Throw " - Another instance of this application is already running"}
          ElseIf ($LASTEXITCODE -eq "2") {Throw " - Invalid command line parameter(s)"}
          ElseIf ($LASTEXITCODE -eq "1001") {Throw " - A pending restart blocks installation"}
          ElseIf ($LASTEXITCODE -eq "3010") {Throw " - A restart is needed"}
          ElseIf ($LASTEXITCODE -eq "-2145124329") {Write-Host -ForegroundColor White " - A known issue occurred installing one of the prerequisites"; InstallPreRequisites ([xml]$xmlinput)}
          Else {Throw " - An unknown error occurred installing prerequisites"}
      }
      # Parsing most recent PreRequisiteInstaller log for errors or restart requirements, since $LASTEXITCODE doesn't seem to work...
      $preReqLog = Get-ChildItem -Path (Get-Item $env:TEMP).FullName | Where-Object {$_.Name -like "PrerequisiteInstaller.*"} | Sort-Object -Descending -Property "LastWriteTime" | Select-Object -first 1
      If ($preReqLog -eq $null) {
          Write-Warning "Could not find PrerequisiteInstaller log file"
      }
      Else {
          # Get error(s) from log
          $preReqLastError = $preReqLog | Select-String -SimpleMatch -Pattern "Error" -Encoding Unicode | Where-Object {$_.Line -notlike "*Startup task*"}
          If ($preReqLastError) {
              ForEach ($preReqError in ($preReqLastError | ForEach {$_.Line})) {Write-Warning $preReqError}
              $preReqLastReturncode = $preReqLog | Select-String -SimpleMatch -Pattern "Last return code" -Encoding Unicode | Select-Object -Last 1
              If ($preReqLastReturnCode) {Write-Verbose $preReqLastReturncode.Line}
              If (!($preReqLastReturncode -like "*(0)")) {
                  Write-Warning $preReqLastReturncode.Line
                  If (($preReqLastReturncode -like "*-2145124329*") -or ($preReqLastReturncode -like "*2359302*") -or ($preReqLastReturncode -eq "5")) {
                      Write-Host -ForegroundColor White " - A known issue occurred installing one of the prerequisites - retrying..."
                      InstallPreRequisites ([xml]$xmlinput)
                  }
                  ElseIf (($preReqLog | Select-String -SimpleMatch -Pattern "Error when enabling ASP.NET v4.0.30319" -Encoding Unicode) -or ($preReqLog | Select-String -SimpleMatch -Pattern "Error when enabling ASP.NET v4.5 with IIS" -Encoding Unicode)) {
                      # Account for new issue with Win2012 RC / R2 and SP2013
                      Write-Host -ForegroundColor White " - A known issue occurred configuring .NET 4 / IIS."
                      $preReqKnownIssueRestart = $true
                  }
                  ElseIf ($preReqLog | Select-String -SimpleMatch -Pattern "pending restart blocks the installation" -Encoding Unicode) {
                      Write-Host -ForegroundColor White " - A pending restart blocks the installation."
                      $preReqKnownIssueRestart = $true
                  }
                  ElseIf ($preReqLog | Select-String -SimpleMatch -Pattern "Error: This tool supports Windows Server version 6.1 and version 6.2" -Encoding Unicode) {
                      Write-Host -ForegroundColor White " - A known issue occurred (due to Win2012 R2), continuing."
                      ##$preReqKnownIssueRestart = $true
                  }
                  Else {
                      Invoke-Item -Path "$((Get-Item $env:TEMP).FullName)\$preReqLog"
                      Throw " - Review the log file and try to correct any error conditions."
                  }
              }
          }
          # Look for restart requirement in log
          $preReqRestartNeeded = ($preReqLog | Select-String -SimpleMatch -Pattern "0XBC2=3010" -Encoding Unicode) -or ($preReqLog | Select-String -SimpleMatch -Pattern "0X3E9=1001" -Encoding Unicode)
          If ($preReqRestartNeeded -or $preReqKnownIssueRestart) {
              Write-Host -ForegroundColor White " - Setting AutoSPInstaller information in the registry..."
              New-Item -Path "HKLM:\SOFTWARE\AutoSPInstaller\" -ErrorAction SilentlyContinue | Out-Null
              $regKey = Get-Item -Path "HKLM:\SOFTWARE\AutoSPInstaller\"
              $regKey | New-ItemProperty -Name "RestartRequired" -PropertyType String -Value "1" -Force | Out-Null
              # We now also want to disable remote installs, or else each server will attempt to remote install to every *other* server after it reboots!
              $regKey | New-ItemProperty -Name "CancelRemoteInstall" -PropertyType String -Value "1" -Force | Out-Null
              $regKey | New-ItemProperty -Name "LogTime" -PropertyType String -Value $script:Logtime -ErrorAction SilentlyContinue | Out-Null
              Throw " - One or more of the prerequisites requires a restart."
          }
          Write-Host -ForegroundColor White " - All Prerequisite Software installed successfully."
      }
  }
  WriteLine
}