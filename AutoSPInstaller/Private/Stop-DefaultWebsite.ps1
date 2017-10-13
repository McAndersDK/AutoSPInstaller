Function Stop-DefaultWebsite () {
  # Added to avoid conflicts with web apps that do not use a host header
  # Thanks to Paul Stork per http://autospinstaller.codeplex.com/workitem/19318 for confirming the Stop-Website cmdlet
  ImportWebAdministration
  $defaultWebsite = Get-Website | Where-Object {$_.Name -eq "Default Web Site" -or $_.ID -eq 1 -or $_.physicalPath -eq "%SystemDrive%\inetpub\wwwroot"} # Try different ways of identifying the Default Web Site, in case it has a different name (e.g. localized installs)
  Write-Host -ForegroundColor White " - Checking $($defaultWebsite.Name)..." -NoNewline
  if ($defaultWebsite.State -ne "Stopped") {
      Write-Host -ForegroundColor White "Stopping..." -NoNewline
      $defaultWebsite | Stop-Website
      if ($?) {Write-Host -ForegroundColor White "OK."}
  }
  else {Write-Host -ForegroundColor White "Already stopped."}
}