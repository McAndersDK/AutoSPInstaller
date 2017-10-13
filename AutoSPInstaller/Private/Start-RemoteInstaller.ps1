Function Start-RemoteInstaller ($server, $password, $inputFile) {
  If ($password) {$credential = New-Object System.Management.Automation.PsCredential $env:USERDOMAIN\$env:USERNAME, $(ConvertTo-SecureString $password)}
  If (!$credential) {$credential = $host.ui.PromptForCredential("AutoSPInstaller - Remote Install", "Re-Enter Credentials for Remote Authentication:", "$env:USERDOMAIN\$env:USERNAME", "NetBiosUserName")}
  If ($session.Name -ne "AutoSPInstallerSession-$server") {
      Write-Host -ForegroundColor White " - Starting remote session to $server..."
      $session = New-PSSession -Name "AutoSPInstallerSession-$server" -Authentication Credssp -Credential $credential -ComputerName $server
  }
  Get-MajorVersionNumber $xmlinput
  # Create a hash table with major version to product year mappings
  $spYears = @{"14" = "2010"; "15" = "2013"; "16" = "2016"}
  $spYear = $spYears.$env:spVer
  # Set some remote variables that we will need...
  Invoke-Command -ScriptBlock {param ($value) Set-Variable -Name dp0 -Value $value} -ArgumentList $env:dp0 -Session $session
  Invoke-Command -ScriptBlock {param ($value) Set-Variable -Name InputFile -Value $value} -ArgumentList $inputFile -Session $session
  Invoke-Command -ScriptBlock {param ($value) Set-Variable -Name spVer -Value $value} -ArgumentList $env:spVer -Session $session
  # Check if SharePoint is already installed
  $spInstalledOnRemote = Invoke-Command -ScriptBlock {(Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*) | Where-Object {$_.DisplayName -like "Microsoft SharePoint Server*"}} -Session $session
  Write-Host -ForegroundColor Green " - SharePoint $spYear binaries are"($spInstalledOnRemote -replace "True", "already" -replace "False", "not yet") "installed on $server."
  Write-Host -ForegroundColor White " - Launching AutoSPInstaller..."
  Invoke-Command -ScriptBlock {& "$dp0\AutoSPInstallerMain.ps1" "$inputFile"} -Session $session
  Write-Host -ForegroundColor White " - Removing session `"$($session.Name)...`""
  Remove-PSSession $session
}