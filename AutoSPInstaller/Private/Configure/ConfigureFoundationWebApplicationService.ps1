Function ConfigureFoundationWebApplicationService {
  WriteLine
  Get-MajorVersionNumber $xmlinput
  $minRoleRequiresFoundationWebAppService = $false
  # Check if we are installing SharePoint 2016 and we're requesting a MinRole that requires the Foundation Web Application Service
  if ($env:SPVer -ge 16) {
      if ((ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.Application)) -or (ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.DistributedCache)) -or (ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.SingleServerFarm)) -or (ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.SingleServer)) -or (ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.WebFrontEnd)) -or (ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.WebFrontEndWithDistributedCache))) {
          $minRoleRequiresFoundationWebAppService = $true
      }
  }
  # Ensure the node exists in the XML first as we don't want to inadvertently stop/disable the service if it wasn't explicitly specified
  if (($xmlinput.Configuration.Farm.Services.SelectSingleNode("FoundationWebApplication")) -and !(ShouldIProvision $xmlinput.Configuration.Farm.Services.FoundationWebApplication -eq $true) -and !($minRoleRequiresFoundationWebAppService)) {
      StopServiceInstance "Microsoft.SharePoint.Administration.SPWebServiceInstance"
  }
  else {
      # Start the service, if it isn't already running
      $serviceInstanceType = "Microsoft.SharePoint.Administration.SPWebServiceInstance"
      # Get all occurrences of the Foundation Web App Service except those which are actually Central Administration instances
      $serviceInstances = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq $serviceInstanceType -and $_.Name -ne "WSS_Administration"}
      $serviceInstance = $serviceInstances | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
      If (!$serviceInstance) { Throw " - Failed to get service instance - check product version (Standard vs. Enterprise)" }
      Write-Host -ForegroundColor White " - Checking $($serviceInstance.TypeName) instance..."
      If (($serviceInstance.Status -eq "Disabled") -or ($serviceInstance.Status -ne "Online")) {
          Write-Host -ForegroundColor White " - Starting $($serviceInstance.TypeName) instance..."
          $serviceInstance.Provision()
          If (-not $?) { Throw " - Failed to start $($serviceInstance.TypeName) instance" }
          # Wait
          Write-Host -ForegroundColor Cyan " - Waiting for $($serviceInstance.TypeName) instance..." -NoNewline
          While ($serviceInstance.Status -ne "Online") {
              Write-Host -ForegroundColor Cyan "." -NoNewline
              Start-Sleep 1
              $serviceInstances = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq $serviceInstanceType}
              $serviceInstance = $serviceInstances | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
          }
          Write-Host -BackgroundColor Green -ForegroundColor Black $($serviceInstance.Status)
      }
      Else {
          Write-Host -ForegroundColor White " - $($serviceInstance.TypeName) instance already started."
      }
  }
  WriteLine
}