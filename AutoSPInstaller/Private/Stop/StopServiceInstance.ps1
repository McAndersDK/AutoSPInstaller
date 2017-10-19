# ===================================================================================
# Func: StopServiceInstance
# Desc: Disables a specified service instance (e.g. on dedicated App servers or WFEs)
# ===================================================================================
Function StopServiceInstance ($service) {
  WriteLine
  $serviceInstances = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq $service -and $_.Name -ne "WSS_Administration"} # Need to filter out WSS_Administration because the Central Administration service instance shares the same Type as the Foundation Web Application Service
  $serviceInstance = $serviceInstances | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
  Write-Host -ForegroundColor White " - Stopping $($serviceInstance.TypeName)..."
  if ($serviceInstance.Status -eq "Online") {
      $serviceInstance.Unprovision()
      If (-not $?) {Throw " - Failed to stop $($serviceInstance.TypeName)" }
      # Wait
      Write-Host -ForegroundColor Cyan " - Waiting for $($serviceInstance.TypeName) to stop..." -NoNewline
      While ($serviceInstance.Status -ne "Disabled") {
          Write-Host -ForegroundColor Cyan "." -NoNewline
          Start-Sleep 1
          $serviceInstances = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq $service}
          $serviceInstance = $serviceInstances | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
      }
      Write-Host -BackgroundColor Green -ForegroundColor Black $($serviceInstance.Status -replace "Disabled", "Stopped")
  }
  Else {Write-Host -ForegroundColor White " - Already stopped."}
  WriteLine
}