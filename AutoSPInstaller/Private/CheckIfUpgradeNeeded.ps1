# ====================================================================================
# Func: CheckIfUpgradeNeeded
# Desc: Returns $true if the server or farm requires an upgrade (i.e. requires PSConfig or the corresponding PowerShell commands to be run)
# ====================================================================================
Function CheckIfUpgradeNeeded {
  $setupType = (Get-Item -Path "HKLM:\SOFTWARE\Microsoft\Shared Tools\Web Server Extensions\$env:spVer.0\WSS\").GetValue("SetupType")
  If ($setupType -ne "CLEAN_INSTALL") {
      # For example, if the value is "B2B_UPGRADE"
      Return $true
  }
  Else {
      Return $false
  }
}