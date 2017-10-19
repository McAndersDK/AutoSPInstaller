Function Install-NetFramework ($server, $password) {
  If ($password) {$credential = New-Object System.Management.Automation.PsCredential $env:USERDOMAIN\$env:USERNAME, $(ConvertTo-SecureString $password)}
  If (!$credential) {$credential = $host.ui.PromptForCredential("AutoSPInstaller - Remote Install", "Re-Enter Credentials for Remote Authentication:", "$env:USERDOMAIN\$env:USERNAME", "NetBiosUserName")}
  If ($session.Name -ne "AutoSPInstallerSession-$server") {
      Write-Host -ForegroundColor White " - Starting remote session to $server..."
      $session = New-PSSession -Name "AutoSPInstallerSession-$server" -Authentication Credssp -Credential $credential -ComputerName $server
  }
  $remoteQueryOS = Invoke-Command -ScriptBlock {Get-WmiObject Win32_OperatingSystem} -Session $session
  If (!($remoteQueryOS.Version.Contains("6.2")) -and !($remoteQueryOS.Version.Contains("6.3")) -and !($remoteQueryOS.Version.StartsWith("10"))) {
      # Only perform the stuff below if we aren't on Windows 2012 or 2012 R2 OR 2016
      Write-Host -ForegroundColor White " - Pre-installing .Net Framework feature on $server..."
      Invoke-Command -ScriptBlock {Import-Module ServerManager | Out-Null
          # Get the current progress preference
          $pref = $ProgressPreference
          # Hide the progress bar since it tends to not disappear
          $ProgressPreference = "SilentlyContinue"
          Import-Module ServerManager
          If (!(Get-WindowsFeature -Name NET-Framework).Installed) {Add-WindowsFeature -Name NET-Framework | Out-Null}
          # Restore progress preference
          $ProgressPreference = $pref} -Session $session
  }
}