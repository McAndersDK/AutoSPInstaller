# ====================================================================================
# Func: Add-SQLAlias
# Desc: Creates a local SQL alias (like using cliconfg.exe) so the real SQL server/name doesn't get hard-coded in SharePoint
#       if local database server is being used, then use Shared Memory protocol
# From: Bill Brockbank, SharePoint MVP (billb@navantis.com)
# ====================================================================================

Function Add-SQLAlias() {
  <#
  .Synopsis
      Add a new SQL server Alias
  .Description
      Adds a new SQL server Alias with the provided parameters.
  .Example
              Add-SQLAlias -AliasName "SharePointDB" -SQLInstance $env:COMPUTERNAME
  .Example
              Add-SQLAlias -AliasName "SharePointDB" -SQLInstance $env:COMPUTERNAME -Port '1433'
  .Parameter AliasName
      The new alias Name.
  .Parameter SQLInstance
              The SQL server Name os Instance Name
  .Parameter Port
      Port number of SQL server instance. This is an optional parameter.
  #>
  [CmdletBinding(DefaultParameterSetName = "BuildPath+SetupInfo")]
  param
  (
      [Parameter(Mandatory = $false, ParameterSetName = "BuildPath+SetupInfo")][ValidateNotNullOrEmpty()]
      [String]$aliasName = "SharePointDB",

      [Parameter(Mandatory = $false, ParameterSetName = "BuildPath+SetupInfo")][ValidateNotNullOrEmpty()]
      [String]$SQLInstance = $env:COMPUTERNAME,

      [Parameter(Mandatory = $false, ParameterSetName = "BuildPath+SetupInfo")][ValidateNotNullOrEmpty()]
      [String]$port = ""
  )

  If ((MatchComputerName $SQLInstance $env:COMPUTERNAME) -or ($SQLInstance.StartsWith($env:ComputerName + "\"))) {
      $protocol = "dbmslpcn" # Shared Memory
  }
  else {
      $protocol = "DBMSSOCN" # TCP/IP
  }

  $serverAliasConnection = "$protocol,$SQLInstance"
  If ($port -ne "") {
      $serverAliasConnection += ",$port"
  }
  $notExist = $true
  $client = Get-Item 'HKLM:\SOFTWARE\Microsoft\MSSQLServer\Client' -ErrorAction SilentlyContinue
  # Create the key in case it doesn't yet exist
  If (!$client) {$client = New-Item 'HKLM:\SOFTWARE\Microsoft\MSSQLServer\Client' -Force}
  $client.GetSubKeyNames() | ForEach-Object -Process { If ( $_ -eq 'ConnectTo') { $notExist = $false }}
  If ($notExist) {
      $data = New-Item 'HKLM:\SOFTWARE\Microsoft\MSSQLServer\Client\ConnectTo'
  }
  # Add Alias
  $data = New-ItemProperty HKLM:\SOFTWARE\Microsoft\MSSQLServer\Client\ConnectTo -Name $aliasName -Value $serverAliasConnection -PropertyType "String" -Force -ErrorAction SilentlyContinue
}