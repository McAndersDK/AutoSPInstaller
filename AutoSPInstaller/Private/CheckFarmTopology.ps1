# ===================================================================================
# Func: CheckFarmTopology
# Desc: Check if there is already more than one server in the farm (not including the database server)
# ===================================================================================
Function CheckFarmTopology([xml]$xmlinput) {
  $dbPrefix = Get-DBPrefix $xmlinput
  $configDB = $dbPrefix + $xmlinput.Configuration.Farm.Database.ConfigDB
  $dbServer = $xmlinput.Configuration.Farm.Database.DBServer
  $spFarm = Get-SPFarm | Where-Object {$_.Name -eq $configDB}
  ForEach ($srv in $spFarm.Servers) {If (($srv -like "*$dbServer*") -and ($dbServer -ne $env:COMPUTERNAME)) {[bool]$dbLocal = $false}}
  If (($($spFarm.Servers.Count) -gt 1) -and ($dbLocal -eq $false)) {[bool]$script:FirstServer = $false}
  Else {[bool]$script:FirstServer = $true}
}