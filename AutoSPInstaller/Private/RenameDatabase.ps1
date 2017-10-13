# ====================================================================================
# Func: RenameDatabase()
# Desc: Renames a SQL database and the database files
# ====================================================================================
Function RenameDatabase([string]$sqlServer, [string]$oldName, [string]$newName) {
  $objSQLConnection = New-Object System.Data.SqlClient.SqlConnection
  $objSQLCommand = New-Object System.Data.SqlClient.SqlCommand
  $objSQLConnection.ConnectionString = "Server=$sqlServer;Integrated Security=SSPI;"
  $objSQLConnection.Open() | Out-Null
  $strCmdSvrDetails = @"
EXEC ('
declare @oldname nvarchar(4000)
declare @newname nvarchar(4000)
set @oldname=''$oldName''
set @newname=''$newName''
EXEC sp_configure ''show advanced options'', 1
RECONFIGURE
create table #opt ( name sysname, minimum int, maximum int,config_value int, run_value int)
insert into #opt exec sp_configure ''xp_cmdshell''
DECLARE @oldcmdshell int
SELECT @oldcmdshell = config_value FROM #opt
EXEC sp_configure ''xp_cmdshell'', 1
RECONFIGURE
declare @datapath nvarchar(4000)
declare @logpath nvarchar(4000)
declare @dataname nvarchar(4000)
declare @logname nvarchar(4000)
select @datapath = replace(physical_name,@oldname + ''.mdf'',''''), @dataname=Name from master.sys.master_files where type=0 and database_id = DB_ID(@oldname)
select @logpath = replace(physical_name,@oldname + ''_log.ldf'',''''), @logname=Name from master.sys.master_files where type=1 and database_id = DB_ID(@oldname)
EXEC (''ALTER DATABASE ['' + @oldname + ''] SET SINGLE_USER WITH ROLLBACK IMMEDIATE'')
EXEC (''ALTER DATABASE ['' + @oldname + ''] MODIFY NAME = ['' + @newname + '']'')
EXEC (''ALTER DATABASE ['' + @newname + ''] MODIFY FILE (
  NAME=N'''''' + @dataname + '''''',
  NEWNAME=N'''''' + @newname + '''''',
  FILENAME=N'''''' + @datapath + @newname + ''.mdf'''')'')
EXEC (''ALTER DATABASE ['' + @newname + ''] MODIFY FILE (
  NAME=N'''''' + @logname + '''''',
  NEWNAME=N'''''' + @newname + ''_log'''',
  FILENAME=N'''''' + @logpath + @newname + ''_log.ldf'''')'')
EXEC (''ALTER DATABASE ['' + @newname + ''] SET OFFLINE'')
EXEC (''EXEC xp_cmdshell ''''RENAME "'' + @datapath + @dataname + ''.mdf", "'' + @newname + ''.mdf"'''''')
EXEC (''EXEC xp_cmdshell ''''RENAME "'' + @logpath + @logname + ''.ldf", "'' + @newname + ''_log.ldf"'''''')
EXEC (''ALTER DATABASE ['' + @newname + ''] SET ONLINE'')
EXEC (''ALTER DATABASE ['' + @newname + ''] SET MULTI_USER WITH ROLLBACK IMMEDIATE'')
EXEC sp_configure ''xp_cmdshell'',@oldcmdshell
RECONFIGURE
drop table #opt
')
"@

  $objSQLCommand.CommandText = $strCmdSvrDetails
  $objSQLCommand.Connection = $objSQLConnection
  $objSQLCommand.ExecuteNonQuery()
  $objSQLConnection.Close()
}