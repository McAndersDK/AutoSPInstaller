# ===================================================================================
# Func: Load SharePoint PowerShell Snapin
# Desc: Load SharePoint PowerShell Snapin
# ===================================================================================
Function Load-SharePoint-PowerShell {
  If ((Get-PsSnapin | Where-Object {$_.Name -eq "Microsoft.SharePoint.PowerShell"}) -eq $null) {
      WriteLine
      Write-Host -ForegroundColor White " - Loading SharePoint PowerShell Snapin..."
      # Added the line below to match what the SharePoint.ps1 file implements (normally called via the SharePoint Management Shell Start Menu shortcut)
      If (Confirm-LocalSession) {$Host.Runspace.ThreadOptions = "ReuseThread"}
      Add-PsSnapin Microsoft.SharePoint.PowerShell -ErrorAction Stop | Out-Null
      WriteLine
  }
}