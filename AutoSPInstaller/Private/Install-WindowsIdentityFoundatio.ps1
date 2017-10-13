Function Install-WindowsIdentityFoundation ($server, $password) {
  # This step is required due to a known issue with the PrerequisiteInstaller.exe over a remote session;
  # Specifically, because Windows Update Standalone Installer (wusa.exe) blows up with error code 5
  # With a fully-patched Windows 2008 R2 server though, the rest of the prerequisites seem OK; so this function only deals with KB974405 (Windows Identity Foundation).
  # Thanks to Ravikanth Chaganti (@ravikanth) for describing the issue, and working around it so effectively: http://www.ravichaganti.com/blog/?p=1888
  If ($password) {$credential = New-Object System.Management.Automation.PsCredential $env:USERDOMAIN\$env:USERNAME, $(ConvertTo-SecureString $password)}
  If (!$credential) {$credential = $host.ui.PromptForCredential("AutoSPInstaller - Remote Install", "Re-Enter Credentials for Remote Authentication:", "$env:USERDOMAIN\$env:USERNAME", "NetBiosUserName")}
  If ($session.Name -ne "AutoSPInstallerSession-$server") {
      Write-Host -ForegroundColor White " - Starting remote session to $server..."
      $session = New-PSSession -Name "AutoSPInstallerSession-$server" -Authentication Credssp -Credential $credential -ComputerName $server
  }
  $remoteQueryOS = Invoke-Command -ScriptBlock {Get-WmiObject Win32_OperatingSystem} -Session $session
  If (!($remoteQueryOS.Version.Contains("6.2")) -and !($remoteQueryOS.Version.Contains("6.3")) -and !($remoteQueryOS.Version.StartsWith("10"))) {
      # Only perform the stuff below if we aren't on Windows 2012 or 2012 R2 OR 2016
      Write-Host -ForegroundColor White " - Checking for KB974405 (Windows Identity Foundation)..." -NoNewline
      $wifHotfixInstalled = Invoke-Command -ScriptBlock {Get-HotFix -Id KB974405 -ErrorAction SilentlyContinue} -Session $session
      If ($wifHotfixInstalled) {
          Write-Host -ForegroundColor White "already installed."
      }
      Else {
          Write-Host -ForegroundColor Black -BackgroundColor White "needed."
          $username = $credential.UserName
          $password = ConvertTo-PlainText $credential.Password
          If ($remoteQueryOS.Version.Contains("6.1")) {
              $wifHotfix = "Windows6.1-KB974405-x64.msu"
          }
          ElseIf ($remoteQueryOS.Version.Contains("6.0")) {
              $wifHotfix = "Windows6.0-KB974405-x64.msu"
          }
          Else {Write-Warning "Could not detect OS of `"$server`", or unsupported OS."}
          If (!(Get-Item $env:SPbits\PrerequisiteInstallerFiles\$wifHotfix -ErrorAction SilentlyContinue)) {
              Write-Host -ForegroundColor White " - Windows Identity Foundation KB974405 not found in $env:SPbits\PrerequisiteInstallerFiles"
              Write-Host -ForegroundColor White " - Attempting to download..."
              $wifURL = "http://download.microsoft.com/download/D/7/2/D72FD747-69B6-40B7-875B-C2B40A6B2BDD/$wifHotfix"
              Import-Module BitsTransfer | Out-Null
              Start-BitsTransfer -Source $wifURL -Destination "$env:SPbits\PrerequisiteInstallerFiles\$wifHotfix" -DisplayName "Downloading `'$wifHotfix`' to $env:SPbits\PrerequisiteInstallerFiles" -Priority Foreground -Description "From $wifURL..." -ErrorVariable err
              if ($err) {Throw " - Could not download from $wifURL!"; Pause "exit"; break}
          }
          $psExec = $env:dp0 + "\PsExec.exe"
          If (!(Get-Item ($psExec) -ErrorAction SilentlyContinue)) {
              Write-Host -ForegroundColor White " - PsExec.exe not found; downloading..."
              $psExecUrl = "http://live.sysinternals.com/PsExec.exe"
              Import-Module BitsTransfer | Out-Null
              Start-BitsTransfer -Source $psExecUrl -Destination $psExec -DisplayName "Downloading Sysinternals PsExec..." -Priority Foreground -Description "From $psExecUrl..." -ErrorVariable err
              If ($err) {Write-Warning "Could not download PsExec!"; Pause "exit"; break}
              $sourceFile = $destinationFile
          }
          Write-Host -ForegroundColor White " - Pre-installing Windows Identity Foundation on `"$server`" via PsExec..."
          Start-Process -FilePath "$psExec" `
              -ArgumentList "/acceptEula \\$server -u $username -p $password -h wusa.exe `"$env:SPbits\PrerequisiteInstallerFiles\$wifHotfix`" /quiet /norestart" `
              -Wait -NoNewWindow
      }
  }
}