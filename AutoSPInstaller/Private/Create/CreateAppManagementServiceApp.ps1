Function CreateAppManagementServiceApp ([xml]$xmlinput) {
  $serviceConfig = $xmlinput.Configuration.ServiceApps.AppManagementService
  If ((ShouldIProvision $serviceConfig -eq $true) -and (Get-Command -Name New-SPAppManagementServiceApplication -ErrorAction SilentlyContinue)) {
      WriteLine
      $dbPrefix = Get-DBPrefix $xmlinput
      $serviceDB = $dbPrefix + $serviceConfig.Database.Name
      $dbServer = $serviceConfig.Database.DBServer
      # If we haven't specified a DB Server then just use the default used by the Farm
      If ([string]::IsNullOrEmpty($dbServer)) {
          $dbServer = $xmlinput.Configuration.Farm.Database.DBServer
      }
      $serviceInstanceType = "Microsoft.SharePoint.AppManagement.AppManagementServiceInstance"
      CreateGenericServiceApplication -ServiceConfig $serviceConfig `
          -ServiceInstanceType $serviceInstanceType `
          -ServiceName $serviceConfig.Name `
          -ServiceProxyName $serviceConfig.ProxyName `
          -ServiceGetCmdlet "Get-SPServiceApplication" `
          -ServiceProxyGetCmdlet "Get-SPServiceApplicationProxy" `
          -ServiceNewCmdlet "New-SPAppManagementServiceApplication -DatabaseServer $dbServer -DatabaseName $serviceDB" `
          -ServiceProxyNewCmdlet "New-SPAppManagementServiceApplicationProxy"

      # Configure your app domain and location
      Write-Host -ForegroundColor White " - Setting App Domain `"$($serviceConfig.AppDomain)`"..."
      Set-SPAppDomain -AppDomain $serviceConfig.AppDomain
      WriteLine
  }
}