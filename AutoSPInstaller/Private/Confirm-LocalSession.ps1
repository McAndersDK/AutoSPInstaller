# ====================================================================================
# Func: Confirm-LocalSession
# Desc: Returns $false if we are running over a PS remote session, $true otherwise
# From: Brian Lalancette, 2012
# ====================================================================================

Function Confirm-LocalSession {
  # Another way
  # If ((Get-Process -Id $PID).ProcessName -eq "wsmprovhost") {Return $false}
  If ($Host.Name -eq "ServerRemoteHost") {Return $false}
  Else {Return $true}
}