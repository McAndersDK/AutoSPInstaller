# ====================================================================================
# Func: Get-DBPrefix
# Desc: Returns the database prefix for the farm
# From: Brian Lalancette, 2014
# ====================================================================================
Function Get-DBPrefix ([xml]$xmlinput) {
  $dbPrefix = $xmlinput.Configuration.Farm.Database.DBPrefix
  If (($dbPrefix -ne "") -and ($dbPrefix -ne $null)) {$dbPrefix += "_"}
  If ($dbPrefix -like "*localhost*") {$dbPrefix = $dbPrefix -replace "localhost", "$env:COMPUTERNAME"}
  return $dbPrefix
}