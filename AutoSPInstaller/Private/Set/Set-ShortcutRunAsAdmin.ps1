# From http://stackoverflow.com/questions/28997799/how-to-create-a-run-as-administrator-shortcut-using-powershell
function Set-ShortcutRunAsAdmin ($shortcutFile) {
  Write-Host -ForegroundColor White " - Setting SharePoint Management Shell to run as Administrator..." -NoNewline
  $bytes = [System.IO.File]::ReadAllBytes($ShortcutFile)
  $bytes[0x15] = $bytes[0x15] -bor 0x20 #set byte 21 (0x15) bit 6 (0x20) ON
  [System.IO.File]::WriteAllBytes($ShortcutFile, $bytes)
  Write-Host -ForegroundColor White "Done."
}