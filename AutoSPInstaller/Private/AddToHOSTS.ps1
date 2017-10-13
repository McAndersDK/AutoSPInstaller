# ====================================================================================
# Func: AddToHOSTS
# Desc: This writes URLs to the server's local hosts file and points them to the server itself
# From: Check http://toddklindt.com/loopback for more information
# Copyright Todd Klindt 2011
# Originally published to http://www.toddklindt.com/blog
# ====================================================================================
Function AddToHOSTS ($hosts) {
  Write-Host -ForegroundColor White " - Adding HOSTS file entries for local resolution..."
  # Make backup copy of the Hosts file with today's date
  $hostsfile = "$env:windir\System32\drivers\etc\HOSTS"
  $date = Get-Date -UFormat "%y%m%d%H%M%S"
  $filecopy = $hostsfile + '.' + $date + '.copy'
  Write-Host -ForegroundColor White "  - Backing up HOSTS file to:"
  Write-Host -ForegroundColor White "  - $filecopy"
  Copy-Item $hostsfile -Destination $filecopy

  if (!$hosts) {
      # No hosts were passed as arguments, so look at the AAMs in the farm
      # Get a list of the AAMs and weed out the duplicates
      $hosts = Get-SPAlternateURL | ForEach-Object {$_.incomingurl.replace("https://", "").replace("http://", "")} | where-Object { $_.tostring() -notlike "*:*" } | Select-Object -Unique
  }

  # Get the contents of the Hosts file
  $file = Get-Content $hostsfile
  $file = $file | Out-String

  # Write the AAMs to the hosts file, UNLESS they already exist, are "localhost" or happen to match the local computer name.
  ForEach ($hostname in $hosts) {
      # Get rid of any path information that may have snuck in here
      $hostname, $null = $hostname -split "/" -replace ("localhost", $env:COMPUTERNAME)
      if (($file -match " $hostname") -or ($file -match "`t$hostname")) {
          # Added check for a space or tab character before the hostname for better exact matching, also used -match for case-insensitivity
          Write-Host -ForegroundColor White "  - HOSTS file entry for `"$hostname`" already exists - skipping."
      }
      elseif ($hostname -eq "$env:Computername" -or $hostname -eq "$env:Computername.$env:USERDNSDOMAIN") {
          Write-Host -ForegroundColor Yellow "  - HOSTS file entry for `"$hostname`" matches local computer name - skipping."
      }
      else {
          Write-Host -ForegroundColor White "  - Adding HOSTS file entry for `"$hostname`"..."
          Add-Content -Path $hostsfile -Value "`r"
          Add-Content -Path $hostsfile -value "127.0.0.1 `t $hostname`t# Added by AutoSPInstaller to locally resolve SharePoint URLs back to this server"
          $keepHOSTSCopy = $true
      }
  }
  If (!$keepHOSTSCopy) {
      Write-Host -ForegroundColor White "  - Deleting HOSTS backup file since no changes were made..."
      Remove-Item $filecopy
  }
  Write-Host -ForegroundColor White " - Done with HOSTS file."
}