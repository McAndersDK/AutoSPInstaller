Function CreateWorkManagementServiceApp ([xml]$xmlinput) {
  $serviceConfig = $xmlinput.Configuration.ServiceApps.WorkManagementService
  If ((ShouldIProvision $serviceConfig -eq $true) -and (Get-Command -Name New-SPWorkManagementServiceApplication -ErrorAction SilentlyContinue) -and (Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.Office.Server.WorkManagement.WorkManagementServiceInstance"})) {
      WriteLine
      $serviceInstanceType = "Microsoft.Office.Server.WorkManagement.WorkManagementServiceInstance"
      CreateGenericServiceApplication -ServiceConfig $serviceConfig `
          -ServiceInstanceType $serviceInstanceType `
          -ServiceName $serviceConfig.Name `
          -ServiceProxyName $serviceConfig.ProxyName `
          -ServiceGetCmdlet "Get-SPServiceApplication" `
          -ServiceProxyGetCmdlet "Get-SPServiceApplicationProxy" `
          -ServiceNewCmdlet "New-SPWorkManagementServiceApplication" `
          -ServiceProxyNewCmdlet "New-SPWorkManagementServiceApplicationProxy"
      WriteLine
  }
}