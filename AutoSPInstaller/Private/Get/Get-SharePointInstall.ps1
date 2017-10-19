Function Get-SharePointInstall {
  # New(er), faster way courtesy of SPRambler (https://www.codeplex.com/site/users/view/SpRambler)
  if ((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*) | Where-Object {$_.DisplayName -like "Microsoft SharePoint Server*"}) {
      return $true
  }
  else {return $false}
}