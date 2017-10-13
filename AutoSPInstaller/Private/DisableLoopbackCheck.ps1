# ===================================================================================
# Func: DisableLoopbackCheck
# Desc: Disable Loopback Check
# ===================================================================================
Function DisableLoopbackCheck([xml]$xmlinput) {
  # Disable the Loopback Check on stand alone demo servers.
  # This setting usually kicks out a 401 error when you try to navigate to sites that resolve to a loopback address e.g.  127.0.0.1
  If ($xmlinput.Configuration.Install.Disable.LoopbackCheck -eq $true) {
      WriteLine
      Write-Host -ForegroundColor White " - Disabling Loopback Check..."

      $lsaPath = "HKLM:\System\CurrentControlSet\Control\Lsa"
      $lsaPathValue = Get-ItemProperty -path $lsaPath
      If (-not ($lsaPathValue.DisableLoopbackCheck -eq "1")) {
          New-ItemProperty HKLM:\System\CurrentControlSet\Control\Lsa -Name "DisableLoopbackCheck" -value "1" -PropertyType dword -Force | Out-Null
      }
      WriteLine
  }
}