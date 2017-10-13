# ===================================================================================
# Func: CreateOrJoinFarm
# Desc: Check if the farm is created
# ===================================================================================
Function CreateOrJoinFarm([xml]$xmlinput, $secPhrase, $farmCredential) {
  WriteLine
  Get-MajorVersionNumber $xmlinput
  $dbPrefix = Get-DBPrefix $xmlinput
  $configDB = $dbPrefix + $xmlinput.Configuration.Farm.Database.ConfigDB

  # Look for an existing farm and join the farm if not already joined, or create a new farm
  Try {
      Write-Host -ForegroundColor White " - Checking farm membership for $env:COMPUTERNAME in `"$configDB`"..." -NoNewline
      $spFarm = Get-SPFarm | Where-Object {$_.Name -eq $configDB} -ErrorAction SilentlyContinue
      Write-Host "."
  }
  Catch {Write-Host "Not joined yet."}
  If ($spFarm -eq $null) {
      $dbServer = $xmlinput.Configuration.Farm.Database.DBServer
      $centralAdminContentDB = $dbPrefix + $xmlinput.Configuration.Farm.CentralAdmin.Database
      # If the SharePoint version is newer than 2010, set the new -SkipRegisterAsDistributedCacheHost parameter when creating/joining the farm if we aren't requesting it for the current server
      if (($env:spVer -ge "15") -and !(ShouldIProvision $xmlinput.Configuration.Farm.Services.DistributedCache -eq $true)) {
          $distCacheSwitch = @{SkipRegisterAsDistributedCacheHost = $true}
          Write-Host -ForegroundColor White " - This server ($env:COMPUTERNAME) has been requested to be excluded from the Distributed Cache cluster."
      }
      else {$distCacheSwitch = @{}
      }
      if ($env:spVer -ge "16") {
          if (ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.Custom)) {$serverRole = "Custom"}
          elseif (ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.WebFrontEnd)) {$serverRole = "WebFrontEnd"}
          elseif (ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.Search)) {$serverRole = "Search"}
          elseif (ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.Application)) {$serverRole = "Application"}
          elseif (ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.DistributedCache)) {$serverRole = "DistributedCache"}
          elseif (ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.SingleServerFarm)) {$serverRole = "SingleServerFarm"}
          elseif (ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.SingleServer)) {$serverRole = "SingleServerFarm"}
          # Only process this stuff if we are running SP2016 with Feature Pack 1
          if (CheckForSP2016FeaturePack1) {
              if (ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.ApplicationWithSearch)) {$serverRole = "ApplicationWithSearch"}
              elseif (ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.WebFrontEndWithDistributedCache)) {$serverRole = "WebFrontEndWithDistributedCache"}
          }
          if ($serverRole) {
              # If the role has been specified, let's apply it
              $serverRoleSwitch = @{LocalServerRole = $serverRole}
              $serverRoleOptionalSwitch = @{}
              Write-Host -ForegroundColor Green " - This server ($env:COMPUTERNAME) has been requested to have the `"$serverRole`" LocalServerRole."
          }
          else {
              # Otherwise we'll just go with Custom/SpecialLoad
              $serverRoleSwitch = @{}
              $serverRoleOptionalSwitch = @{ServerRoleOptional = $true}
              Write-Host -ForegroundColor Green " - ServerRole was not specified (or an invalid role was given); assuming `"Custom`"."
          }
      }
      else {
          $serverRoleSwitch = @{}
          $serverRoleOptionalSwitch = @{}
      }
      Write-Host -ForegroundColor White " - Attempting to join farm on `"$configDB`"..."
      $connectFarm = Connect-SPConfigurationDatabase -DatabaseName "$configDB" -Passphrase $secPhrase -DatabaseServer "$dbServer" @distCacheSwitch @serverRoleSwitch -ErrorAction SilentlyContinue
      If (-not $?) {
          Write-Host -ForegroundColor White " - No existing farm found.`n - Creating config database `"$configDB`"..."
          # Waiting a few seconds seems to help with the Connect-SPConfigurationDatabase barging in on the New-SPConfigurationDatabase command; not sure why...
          Start-Sleep 5
          New-SPConfigurationDatabase -DatabaseName "$configDB" -DatabaseServer "$dbServer" -AdministrationContentDatabaseName "$centralAdminContentDB" -Passphrase $secPhrase -FarmCredentials $farmCredential @distCacheSwitch @serverRoleSwitch @serverRoleOptionalSwitch
          If (-not $?) {Throw " - Error creating new farm configuration database"}
          Else {$farmMessage = " - Done creating configuration database for farm."}
      }
      Else {
          $farmMessage = " - Done joining farm."
          [bool]$script:FarmExists = $true

      }
  }
  Else {
      [bool]$script:FarmExists = $true
      $farmMessage = " - $env:COMPUTERNAME is already joined to farm on `"$configDB`"."
  }

  Write-Host -ForegroundColor White $farmMessage
  WriteLine
}