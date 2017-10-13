# ====================================================================================
# Func: CheckSQLAccess
# Desc: Checks if the install account has the correct SQL database access and permissions
# By:   Sameer Dhoot (http://sharemypoint.in/about/sameerdhoot/)
# From: http://sharemypoint.in/2011/04/18/powershell-script-to-check-sql-server-connectivity-version-custering-status-user-permissions/
# Adapted for use in AutoSPInstaller by @brianlala
# ====================================================================================
Function CheckSQLAccess {
  WriteLine
  # Look for references to DB Servers, Aliases, etc. in the XML
  ForEach ($node in $xmlinput.SelectNodes("//*[DBServer]|//*[@DatabaseServer]|//*[@FailoverDatabaseServer]")) {
      $dbServer = (GetFromNode $node "DBServer")
      If ($node.DatabaseServer) {$dbServer = GetFromNode $node "DatabaseServer"}
      # If the DBServer has been specified, and we've asked to set up an alias, create one
      If (!([string]::IsNullOrEmpty($dbServer)) -and ($node.DBAlias.Create -eq $true)) {
          $dbInstance = GetFromNode $node.DBAlias "DBInstance"
          $dbPort = GetFromNode $node.DBAlias "DBPort"
          # If no DBInstance has been specified, but Create="$true", set the Alias to the server value
          If (($dbInstance -eq $null) -and ($dbInstance -ne "")) {$dbInstance = $dbServer}
          If (($dbPort -ne $null) -and ($dbPort -ne "")) {
              Write-Host -ForegroundColor White " - Creating SQL alias `"$dbServer,$dbPort`"..."
              Add-SQLAlias -AliasName $dbServer -SQLInstance $dbInstance -Port $dbPort
          }
          else {
              # Create the alias without specifying the port (use default)
              Write-Host -ForegroundColor White " - Creating SQL alias `"$dbServer`"..."
              Add-SQLAlias -AliasName $dbServer -SQLInstance $dbInstance
          }
      }
      $dbServers += @($dbServer)
  }

  $currentUser = "$env:USERDOMAIN\$env:USERNAME"
  $serverRolesToCheck = "dbcreator", "securityadmin"
  # If we are provisioning PerformancePoint but aren't running SharePoint 2010 Service Pack 1 yet, we need sysadmin in order to run the RenameDatabase function
  # We also evidently need sysadmin in order to configure MaxDOP on the SQL instance if we are installing SharePoint 2013
  If (($xmlinput.Configuration.EnterpriseServiceApps.PerformancePointService) -and (ShouldIProvision $xmlinput.Configuration.EnterpriseServiceApps.PerformancePointService -eq $true) -and (!(CheckFor2010SP1))) {
      $serverRolesToCheck += "sysadmin"
  }

  ForEach ($sqlServer in ($dbServers | Select-Object -Unique)) {
      If ($sqlServer) {
          # Only check the SQL instance if it has a value
          $objSQLConnection = New-Object System.Data.SqlClient.SqlConnection
          $objSQLCommand = New-Object System.Data.SqlClient.SqlCommand
          Try {
              $objSQLConnection.ConnectionString = "Server=$sqlServer;Integrated Security=SSPI;"
              Write-Host -ForegroundColor White " - Testing access to SQL server/instance/alias:" $sqlServer
              Write-Host -ForegroundColor White " - Trying to connect to `"$sqlServer`"..." -NoNewline
              $objSQLConnection.Open() | Out-Null
              Write-Host -ForegroundColor Black -BackgroundColor Green "Success"
              $strCmdSvrDetails = "SELECT SERVERPROPERTY('productversion') as Version"
              $strCmdSvrDetails += ",SERVERPROPERTY('IsClustered') as Clustering"
              $objSQLCommand.CommandText = $strCmdSvrDetails
              $objSQLCommand.Connection = $objSQLConnection
              $objSQLDataReader = $objSQLCommand.ExecuteReader()
              If ($objSQLDataReader.Read()) {
                  Write-Host -ForegroundColor White (" - SQL Server version is: {0}" -f $objSQLDataReader.GetValue(0))
                  $SQLVersion = $objSQLDataReader.GetValue(0)
                  [int]$SQLMajorVersion, [int]$SQLMinorVersion, [int]$SQLBuild, $null = $SQLVersion -split "\."
                  # SharePoint needs minimum SQL 2008 10.0.2714.0 or SQL 2005 9.0.4220.0 per http://support.microsoft.com/kb/976215
                  If ((($SQLMajorVersion -eq 10) -and ($SQLMinorVersion -lt 5) -and ($SQLBuild -lt 2714)) -or (($SQLMajorVersion -eq 9) -and ($SQLBuild -lt 4220))) {
                      Throw " - Unsupported SQL version!"
                  }
                  If ($objSQLDataReader.GetValue(1) -eq 1) {
                      Write-Host -ForegroundColor White " - This instance of SQL Server is clustered"
                  }
                  Else {
                      Write-Host -ForegroundColor White " - This instance of SQL Server is not clustered"
                  }
              }
              $objSQLDataReader.Close()
              ForEach ($serverRole in $serverRolesToCheck) {
                  $objSQLCommand.CommandText = "SELECT IS_SRVROLEMEMBER('$serverRole')"
                  $objSQLCommand.Connection = $objSQLConnection
                  Write-Host -ForegroundColor White " - Check if $currentUser has $serverRole server role..." -NoNewline
                  $objSQLDataReader = $objSQLCommand.ExecuteReader()
                  If ($objSQLDataReader.Read() -and $objSQLDataReader.GetValue(0) -eq 1) {
                      Write-Host -ForegroundColor Black -BackgroundColor Green "Pass"
                  }
                  ElseIf ($objSQLDataReader.GetValue(0) -eq 0) {
                      Throw " - $currentUser does not have `'$serverRole`' role!"
                  }
                  Else {
                      Write-Host -ForegroundColor Red "Invalid Role"
                  }
                  $objSQLDataReader.Close()
              }
              $objSQLConnection.Close()
          }
          Catch {
              Write-Host -ForegroundColor Red " - Fail"
              $errText = $error[0].ToString()
              If ($errText.Contains("network-related")) {
                  Write-Warning "Connection Error. Check server name, port, firewall."
                  Write-Host -ForegroundColor White " - This may be expected if e.g. SQL server isn't installed yet, and you are just installing SharePoint binaries for now."
                  Pause "continue without checking SQL Server connection, or Ctrl-C to exit" "y"
              }
              ElseIf ($errText.Contains("Login failed")) {
                  Throw " - Not able to login. SQL Server login not created."
              }
              ElseIf ($errText.Contains("Unsupported SQL version")) {
                  Throw " - SharePoint 2010 requires SQL 2005 SP3+CU3, SQL 2008 SP1+CU2, or SQL 2008 R2."
              }
              Else {
                  If (!([string]::IsNullOrEmpty($serverRole))) {
                      Throw " - $currentUser does not have `'$serverRole`' role!"
                  }
                  Else {Throw " - $errText"}
              }
          }
      }
  }
  WriteLine
}