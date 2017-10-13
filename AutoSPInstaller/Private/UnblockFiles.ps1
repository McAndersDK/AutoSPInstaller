Function UnblockFiles ($path) {
  # Ensure that if we're running from a UNC path, the host portion is added to the Local Intranet zone so we don't get the "Open File - Security Warning"
  If ($env:dp0 -like "\\*") {
      WriteLine
      if (Get-Command -Name "Unblock-File" -ErrorAction SilentlyContinue) {
          Write-Host -ForegroundColor White " - Unblocking executable files in $path to prevent security prompts..." -NoNewline
          # Leverage the Unblock-File cmdlet, if available to prevent security warnings when working with language packs, CUs etc.
          Get-ChildItem -Path $path -Recurse | Where-Object {($_.Name -like "*.exe") -or ($_.Name -like "*.ms*") -or ($_.Name -like "*.zip") -or ($_.Name -like "*.cab")} | Unblock-File -Confirm:$false -ErrorAction SilentlyContinue
          Write-Host -ForegroundColor White "Done."
      }
      $safeHost = ($env:dp0 -split "\\")[2]
      Write-Host -ForegroundColor White " - Adding location `"$safeHost`" to local Intranet security zone to prevent security prompts..." -NoNewline
      New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains" -Name $safeHost -ItemType Leaf -Force | Out-Null
      New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\$safeHost" -Name "file" -value "1" -PropertyType dword -Force | Out-Null
      Write-Host -ForegroundColor White "Done."
      WriteLine
  }
}