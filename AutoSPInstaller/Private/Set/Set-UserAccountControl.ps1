# ====================================================================================
# Func: Set-UserAccountControl
# Desc: Enables or disables User Account Control (UAC), using a 1 or a 0 (respectively) passed as a parameter
# From: Brian Lalancette, 2012
# ====================================================================================
Function Set-UserAccountControl ($flag) {
  $regUAC = (Get-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system").GetValue("EnableLUA")
  if ($flag -eq $regUAC) {
      Write-Host -ForegroundColor White " - User Account Control is already" $($regUAC -replace "1", "enabled." -replace "0", "disabled.")
  }
  else {
      if ($regUAC -eq 1) {
          New-Item -Path "HKLM:\SOFTWARE\AutoSPInstaller\" -ErrorAction SilentlyContinue | Out-Null
          $regKey = Get-Item -Path "HKLM:\SOFTWARE\AutoSPInstaller\"
          $regKey | New-ItemProperty -Name "UACWasEnabled" -PropertyType String -Value "1" -Force | Out-Null
      }
      Write-Host -ForegroundColor White " - $($flag -replace "1","Re-enabling" -replace "0","Disabling") User Account Control (effective upon restart)..."
      Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system" -Name EnableLUA -Value $flag
  }
}