# ====================================================================================
# Func: ConfigureDistributedCacheService
# Desc: Updates the service account for AppFabricCachingService AKA Distributed Caching Service
# Info: http://technet.microsoft.com/en-us/library/jj219613.aspx
# ====================================================================================

Function ConfigureDistributedCacheService ([xml]$xmlinput) {
  Get-MajorVersionNumber $xmlinput
  # Make sure a credential deployment job doesn't already exist, and that we are running SP2013 at minimum
  if ((!(Get-SPTimerJob -Identity "windows-service-credentials-AppFabricCachingService")) -and ($env:spVer -ge "15")) {
      WriteLine
      $spservice = Get-SPManagedAccountXML $xmlinput -CommonName "spservice"
      $distributedCachingSvc = (Get-SPFarm).Services | Where-Object {$_.Name -eq "AppFabricCachingService"}
      # Check if we should disable the Distributed Cache service on the local server
      # Ensure the node exists in the XML first as we don't want to inadvertently disable the service if it wasn't explicitly specified
      $serviceInstances = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.SharePoint.DistributedCaching.Utilities.SPDistributedCacheServiceInstance"}
      $serviceInstance = $serviceInstances | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
      # Check if we are installing SharePoint 2016 and have requested a MinRole that requires (or complies with) Distributed Cache
      if ($env:spVer -ge "16") {
          # DistributedCache and SingleServerFarm Minroles require Distributed Cache to be provisioned locally
          if ((ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.DistributedCache)) -or (ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.SingleServerFarm)) -or (ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.SingleServer)) -or (ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.WebFrontEndWithDistributedCache))) {
              $distributedCache2016Stop = $false
          }
          # Check if we have requested both Custom Minrole and local Distributed Cache provisioning in the XML
          elseif (($xmlinput.Configuration.Farm.Services.SelectSingleNode("DistributedCache")) -and (ShouldIProvision $xmlinput.Configuration.Farm.Services.DistributedCache -eq $true) -and (ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.Custom))) {
              $distributedCache2016Stop = $false
          }
          # Otherwise we should be stopping the Distributed Cache
          else {
              $distributedCache2016Stop = $true
          }
          # Check if Feature Pack 1 (November 2106 PU) for SharePoint 2016 is installed
          if (CheckForSP2016FeaturePack1) {
              # Check if we are requesting a Single Server Farm
              if ((ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.SingleServerFarm)) -or (ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.SingleServer))) {
                  $distributedCacheSingleServerFarmSwitch = @{Role = "SingleServerFarm"}
              }
              elseif (ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.WebFrontEndWithDistributedCache)) {
                  $distributedCacheSingleServerFarmSwitch = @{Role = "WebFrontEndWithDistributedCache"}
              }
          }
          else {
              $distributedCacheSingleServerFarmSwitch = @{}
          }
      }
      else {
          if (($xmlinput.Configuration.Farm.Services.SelectSingleNode("DistributedCache")) -and !(ShouldIProvision $xmlinput.Configuration.Farm.Services.DistributedCache -eq $true)) {
              $distributedCache2013Stop = $true
          }
      }
      # New additional check for $distributedCache2016Stop flag - because we will need to ensure DC doesn't get stopped if we are running certain MinRoles in SP2016
      if ($distributedCache2013Stop -or $distributedCache2016Stop) {
          Write-Host -ForegroundColor White " - Stopping the Distributed Cache service..." -NoNewline
          if ($serviceInstance.Status -eq "Online") {
              Stop-SPDistributedCacheServiceInstance -Graceful
              Remove-SPDistributedCacheServiceInstance
              Write-Host -ForegroundColor Green "Done."
          }
          else {Write-Host -ForegroundColor White "Already stopped."}
      }
      # Otherwise, make sure it's started, and set it to run under a different account
      else {
          # Ensure the local Distributed Cache service is actually running
          if ($serviceInstance.Status -ne "Online") {
              Write-Host -ForegroundColor White " - Starting the Distributed Cache service..." -NoNewline
              Add-SPDistributedCacheServiceInstance @distributedCacheSingleServerFarmSwitch
              Write-Host -ForegroundColor Green "Done."
          }
          $appPoolAcctDomain, $appPoolAcctUser = $spservice.username -Split "\\"
          Write-Host -ForegroundColor White " - Applying service account $($spservice.username) to service AppFabricCachingService..."
          $managedAccountGen = Get-SPManagedAccount | Where-Object {$_.UserName -eq $($spservice.username)}
          Try {
              UpdateProcessIdentity $distributedCachingSvc
          }
          Catch {
              Write-Output $_
              Write-Warning "An error occurred updating the service account for service AppFabricCachingService."
          }
      }
      WriteLine
  }
}