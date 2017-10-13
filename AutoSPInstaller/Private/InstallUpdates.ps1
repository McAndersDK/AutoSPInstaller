# ===================================================================================
# Func: InstallUpdates
# Desc: Install SharePoint Updates (CUs and Service Packs) to work around slipstreaming issues
# ===================================================================================
Function InstallUpdates {
  WriteLine
  Write-Host -ForegroundColor White " - Looking for SharePoint updates to install..."
  Get-MajorVersionNumber $xmlinput
  $spYears = @{"14" = "2010"; "15" = "2013"; "16" = "2016"}
  $spYear = $spYears.$env:spVer
  # Result codes below are from http://technet.microsoft.com/en-us/library/cc179058(v=office.14).aspx
  $oPatchInstallResultCodes = @{"17301" = "Error: General Detection error";
      "17302"                           = "Error: Applying patch";
      "17303"                           = "Error: Extracting file";
      "17021"                           = "Error: Creating temp folder";
      "17022"                           = "Success: Reboot flag set";
      "17023"                           = "Error: User cancelled installation";
      "17024"                           = "Error: Creating folder failed";
      "17025"                           = "Patch already installed";
      "17026"                           = "Patch already installed to admin installation";
      "17027"                           = "Installation source requires full file update";
      "17028"                           = "No product installed for contained patch";
      "17029"                           = "Patch failed to install";
      "17030"                           = "Detection: Invalid CIF format";
      "17031"                           = "Detection: Invalid baseline";
      "17034"                           = "Error: Required patch does not apply to the machine";
      "17038"                           = "You do not have sufficient privileges to complete this installation for all users of the machine. Log on as administrator and then retry this installation";
      "17044"                           = "Installer was unable to run detection for this package"
  }
  if ($spYear -eq "2010") {
      $sp2010SP1 = Get-ChildItem -Path "$bits\$spYear\Updates" -Name -Include "officeserver2010sp1-kb2460045-x64-fullfile-en-us.exe" -Recurse -ErrorAction SilentlyContinue
      # In case we find more than one (e.g. in subfolders), grab the first one
      if ($sp2010SP1 -is [system.array]) {$sp2010SP1 = $sp2010SP1[0]}
      $sp2010June2013CU = Get-ChildItem -Path "$bits\$spYear\Updates" -Name -Include "ubersrv2010-kb2817527-fullfile-x64-glb.exe" -Recurse -ErrorAction SilentlyContinue
      # In case we find more than one (e.g. in subfolders), grab the first one
      if ($sp2010June2013CU -is [system.array]) {$sp2010June2013CU = $sp2010June2013CU[0]}
      $sp2010SP2 = Get-ChildItem -Path "$bits\$spYear\Updates" -Name -Include "oserversp2010-kb2687453-fullfile-x64-en-us.exe" -Recurse -ErrorAction SilentlyContinue
      # In case we find more than one (e.g. in subfolders), grab the first one
      if ($sp2010SP2 -is [system.array]) {$sp2010SP2 = $sp2010SP2[0]}
      # Get installed SharePoint languages, so we can determine which language pack updates to apply
      $installedOfficeServerLanguages = (Get-Item "HKLM:\Software\Microsoft\Office Server\$env:spVer.0\InstalledLanguages").GetValueNames() | Where-Object {$_ -ne ""}
      # First & foremost, install SP2 if it's there
      if ($sp2010SP2) {
          InstallSpecifiedUpdate $sp2010SP2 "Service Pack 2"
      }
      # Otherwise, install SP1 as it is a required baseline for any post-June 2012 CUs
      elseif ($sp2010SP1) {
          InstallSpecifiedUpdate $sp2010SP1 "Service Pack 1"
      }
      # Next, install the June 2013 CU if it's found in \Updates
      if ($sp2010June2013CU) {
          InstallSpecifiedUpdate $sp2010June2013CU "June 2013 CU"
      }
      # Now find any language pack service packs, using the naming conventions for both SP1 and SP2
      $sp2010LPServicePacks = Get-ChildItem -Path "$bits\$spYear\Updates" -Name -Include serverlanguagepack2010sp*.exe, oslpksp2010*.exe -Recurse -ErrorAction SilentlyContinue | Sort-Object -Descending
      # Now install language pack service packs - only if they match a currently-installed SharePoint language
      foreach ($installedOfficeServerLanguage in $installedOfficeServerLanguages) {
          [array]$sp2010LPServicePacksToInstall += $sp2010LPServicePacks | Where-Object {$_ -like "*$installedOfficeServerLanguage*"}
      }
      if ($sp2010LPServicePacksToInstall) {
          foreach ($sp2010LPServicePack in $sp2010LPServicePacksToInstall) {
              InstallSpecifiedUpdate $sp2010LPServicePack "Language Pack Service Pack"
          }
      }
      if ($xmlinput.Configuration.OfficeWebApps.Install -eq $true) {
          $sp2010OWAUpdates = Get-ChildItem -Path "$bits\$spYear\Updates" -Name -Include wac*.exe -Recurse -ErrorAction SilentlyContinue | Sort-Object -Descending
          if ($sp2010OWAUpdates.Count -ge 1) {
              foreach ($sp2010OWAUpdate in $sp2010OWAUpdates) {
                  InstallSpecifiedUpdate $sp2010OWAUpdate "Office Web Apps Update"
              }
          }
      }
  }
  if ($spYear -eq "2013") {
      # Do SP1 first, if it's found
      $sp2013SP1 = Get-ChildItem -Path "$bits\$spYear\Updates" -Name -Include "officeserversp2013-kb2880552-fullfile-x64-en-us.exe" -Recurse -ErrorAction SilentlyContinue
      if ($sp2013SP1) {
          # In case we find more than one (e.g. in subfolders), grab the first one
          if ($sp2013SP1 -is [system.array]) {$sp2013SP1 = $sp2013SP1[0]}
          InstallSpecifiedUpdate $sp2013SP1 "Service Pack 1"
      }
      if ($xmlinput.Configuration.ProjectServer.Install -eq $true) {
          if ($sp2013SP1) {
              # Look for Project Server 2013 SP1, since we have SharePoint Server SP1
              $sp2013ProjectSP1 = Get-ChildItem -Path "$bits\$spYear\Updates" -Name -Include "projectserversp2013-kb2817434-fullfile-x64-en-us.exe" -Recurse -ErrorAction SilentlyContinue
              if ($sp2013ProjectSP1) {
                  # In case we find more than one (e.g. in subfolders), grab the first one
                  if ($sp2013ProjectSP1 -is [system.array]) {$sp2013ProjectSP1 = $sp2013ProjectSP1[0]}
                  InstallSpecifiedUpdate $sp2013ProjectSP1 "Project Server Service Pack 1"
              }
              else {
                  Write-Warning "Project Server Service Pack 1 wasn't found. Since SharePoint itself will be updated to SP1, you should download and install Project Server 2013 SP1 for your server/farm to be completely patched."
              }
          }
          else {
              # Look for a Project Server March PU
              $marchPublicUpdate = Get-ChildItem -Path "$bits\$spYear\Updates" -Name -Include "ubersrvprjsp2013-kb2768001-fullfile-x64-glb.exe" -Recurse -ErrorAction SilentlyContinue
              if (!$marchPublicUpdate) {
                  # In case we forgot to include the Project Server March PU, just look for the SharePoint Server March PU
                  $marchPublicUpdate = Get-ChildItem -Path "$bits\$spYear\Updates" -Name -Include "ubersrvsp2013-kb2767999-fullfile-x64-glb.exe" -Recurse -ErrorAction SilentlyContinue
                  if ($marchPublicUpdate) {
                      Write-Warning "The Project Server March PU wasn't found, but the regular SharePoint Server March PU was, and will be applied. However you should download and install the full Project Server March PU and any subsequent updates afterwards for your server/farm to be completely patched."
                  }
              }
          }
      }
      else {
          if (!$sp2013SP1) {
              # Look for the SharePoint Server March PU
              $marchPublicUpdate = Get-ChildItem -Path "$bits\$spYear\Updates" -Name -Include "ubersrvsp2013-kb2767999-fullfile-x64-glb.exe" -Recurse -ErrorAction SilentlyContinue
          }
      }
      if ($marchPublicUpdate) {
          # In case we find more than one (e.g. in subfolders), grab the first one
          if ($marchPublicUpdate -is [system.array]) {$marchPublicUpdate = $marchPublicUpdate[0]}
          InstallSpecifiedUpdate $marchPublicUpdate "March 2013 Public Update"
      }
  }
  # Get all CUs except the March 2013 PU for SharePoint / Project Server 2013 and the June 2013 CU for SharePoint 2010
  $cumulativeUpdates = Get-ChildItem -Path "$bits\$spYear\Updates" -Include office2010*.exe, ubersrv*.exe, ubersts*.exe, *pjsrv*.exe, sharepointsp2013*.exe, coreserver201*.exe, sts201*.exe, wssloc201*.exe, svrproofloc201*.exe -Recurse -ErrorAction SilentlyContinue | Where-Object {$_ -notlike "*ubersrvsp2013-kb2767999-fullfile-x64-glb.exe" -and $_ -notlike "*ubersrvprjsp2013-kb2768001-fullfile-x64-glb.exe" -and $_ -notlike "*ubersrv2010-kb2817527-fullfile-x64-glb.exe"} | Sort-Object -Descending
  # Filter out Project Server updates if we aren't installing Project Server
  if ($xmlinput.Configuration.ProjectServer.Install -ne $true) {
      $cumulativeUpdates = $cumulativeUpdates | Where-Object {($_ -notlike "*prj*.exe") -and ($_ -notlike "*pjsrv*.exe")}
  }
  # Look for Server Cumulative Update installers
  if ($cumulativeUpdates) {
      # Display warning about missing March 2013 PU only if we are actually installing SP2013 and SP1 isn't already installed and the SP1 installer isn't found
      if ($spYear -eq "2013" -and !($sp2013SP1 -or (CheckFor2013SP1)) -and !$marchPublicUpdate) {
          Write-Host -ForegroundColor Yellow "  - Note: the March 2013 PU package wasn't found in ..\$spYear\Updates; it may need to be installed first if it wasn't slipstreamed."
      }
      # Now attempt to install any other CUs found in the \Updates folder
      Write-Host -ForegroundColor White "  - Installing SharePoint Cumulative Updates:"
      ForEach ($cumulativeUpdate in $cumulativeUpdates) {
          # Get the file name only, in case $cumulativeUpdate includes part of a path (e.g. is in a subfolder)
          $splitCumulativeUpdate = Split-Path -Path $cumulativeUpdate -Leaf
          Write-Host -ForegroundColor Cyan "   - Installing $splitCumulativeUpdate from `"$($cumulativeUpdate.Directory.Name)`"..." -NoNewline
          $startTime = Get-Date
          Start-Process -FilePath "$cumulativeUpdate" -ArgumentList "/passive /norestart"
          Show-Progress -Process $($splitCumulativeUpdate -replace ".exe", "") -Color Cyan -Interval 5
          $delta, $null = (New-TimeSpan -Start $startTime -End (Get-Date)).ToString() -split "\."
          $oPatchInstallLog = Get-ChildItem -Path (Get-Item $env:TEMP).FullName | Where-Object {$_.Name -like "opatchinstall*.log"} | Sort-Object -Descending -Property "LastWriteTime" | Select-Object -first 1
          # Get install result from log
          $oPatchInstallResultMessage = $oPatchInstallLog | Select-String -SimpleMatch -Pattern "OPatchInstall: Property 'SYS.PROC.RESULT' value" | Select-Object -Last 1
          If (!($oPatchInstallResultMessage -like "*value '0'*")) {
              # Anything other than 0 means unsuccessful but that's not necessarily a bad thing
              $null, $oPatchInstallResultCode = $oPatchInstallResultMessage.Line -split "OPatchInstall: Property 'SYS.PROC.RESULT' value '"
              $oPatchInstallResultCode = $oPatchInstallResultCode.TrimEnd("'")
              # OPatchInstall: Property 'SYS.PROC.RESULT' value '17028' means the patch was not needed or installed product was newer
              if ($oPatchInstallResultCode -eq "17028") {Write-Host -ForegroundColor White "   - Patch not required; installed product is same or newer."}
              elseif ($oPatchInstallResultCode -eq "17031") {
                  Write-Warning "Error 17031: Detection: Invalid baseline"
                  Write-Warning "A baseline patch (e.g. March 2013 PU for SP2013, SP1 for SP2010) is missing!"
                  Write-Host -ForegroundColor Yellow "   - Either slipstream the missing patch first, or include the patch package in the ..\$spYear\Updates folder."
                  Pause "continue"
              }
              else {Write-Host "   - $($oPatchInstallResultCodes.$oPatchInstallResultCode)"}
          }
          Write-Host -ForegroundColor White "   - $splitCumulativeUpdate install completed in $delta."
      }
      Write-Host -ForegroundColor White "  - Cumulative Update installation complete."
  }
  # Finally, install SP2 last in case we applied the June 2013 CU which would not have properly detected SP2...
  if ($sp2010SP2 -and $sp2010June2013CU -and $spYear -eq "2010") {
      InstallSpecifiedUpdate $sp2010SP2 "Service Pack 2"
  }
  if (!$marchPublicUpdate -and !$cumulativeUpdates) {
      Write-Host -ForegroundColor White " - No other updates found in $bits\$spYear\Updates, proceeding..."
  }
  else {
      Write-Host -ForegroundColor White " - Finished installing SharePoint updates."
  }
  WriteLine
}