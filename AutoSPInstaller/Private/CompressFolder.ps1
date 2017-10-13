# ====================================================================================
# Func: CompressFolder
# Desc: Enables NTFS compression for a given folder
# From: Based on concepts & code found at http://www.humanstuff.com/2010/6/24/how-to-compress-a-file-using-powershell
# ====================================================================================
Function CompressFolder ($folder) {
  # Replace \ with \\ for WMI
  $wmiPath = $folder.Replace("\", "\\")
  $wmiDirectory = Get-WmiObject -Class "Win32_Directory" -Namespace "root\cimv2" -ComputerName $env:COMPUTERNAME -Filter "Name='$wmiPath'"
  # Check if folder is already compressed
  If (!($wmiDirectory.Compressed)) {
      Write-Host -ForegroundColor White " - Compressing $folder and subfolders..."
      $compress = $wmiDirectory.CompressEx("", "True")
  }
  Else {Write-Host -ForegroundColor White " - $folder is already compressed."}
}
