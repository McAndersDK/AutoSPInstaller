Function Enable-RemoteSession ($server, $password) {
  If ($password) {$credential = New-Object System.Management.Automation.PsCredential $env:USERDOMAIN\$env:USERNAME, $(ConvertTo-SecureString $password)}
  If (!$credential) {$credential = $host.ui.PromptForCredential("AutoSPInstaller - Remote Install", "Re-Enter Credentials for Remote Authentication:", "$env:USERDOMAIN\$env:USERNAME", "NetBiosUserName")}
  $username = $credential.Username
  $password = ConvertTo-PlainText $credential.Password
  $configureTargetScript = "$env:dp0\AutoSPInstallerConfigureRemoteTarget.ps1"
  $psExec = $env:dp0 + "\PsExec.exe"
  If (!(Get-Item ($psExec) -ErrorAction SilentlyContinue)) {
      Write-Host -ForegroundColor White " - PsExec.exe not found; downloading..."
      $psExecUrl = "http://live.sysinternals.com/PsExec.exe"
      Import-Module BitsTransfer | Out-Null
      Start-BitsTransfer -Source $psExecUrl -Destination $psExec -DisplayName "Downloading Sysinternals PsExec..." -Priority Foreground -Description "From $psExecUrl..." -ErrorVariable err
      If ($err) {Write-Warning "Could not download PsExec!"; Pause "exit"; break}
      $sourceFile = $destinationFile
  }
  Write-Host -ForegroundColor White " - Updating PowerShell execution policy on `"$server`" via PsExec..."
  Start-Process -FilePath "$psExec" `
      -ArgumentList "/acceptEula \\$server -h powershell.exe -Command `"Set-ExecutionPolicy Bypass -Force ; Stop-Process -Id `$PID`"" `
      -Wait -NoNewWindow
  # Another way to exit powershell when running over PsExec from http://www.leeholmes.com/blog/2007/10/02/using-powershell-and-PsExec-to-invoke-expressions-on-remote-computers/
  # PsExec \\server cmd /c "echo . | powershell {command}"
  Write-Host -ForegroundColor White " - Enabling PowerShell remoting on `"$server`" via PsExec..."
  Start-Process -FilePath "$psExec" `
      -ArgumentList "/acceptEula \\$server -u $username -p $password -h powershell.exe -Command `"$configureTargetScript`"" `
      -Wait -NoNewWindow
}
