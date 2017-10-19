Function CreateSubscriptionSettingsServiceApp ([xml]$xmlinput) {
  $serviceConfig = $xmlinput.Configuration.ServiceApps.SubscriptionSettingsService
  If ((ShouldIProvision $serviceConfig -eq $true) -and (Get-Command -Name New-SPSubscriptionSettingsServiceApplication -ErrorAction SilentlyContinue)) {
      WriteLine
      $dbPrefix = Get-DBPrefix $xmlinput
      $serviceDB = $dbPrefix + $serviceConfig.Database.Name
      $dbServer = $serviceConfig.Database.DBServer
      # If we haven't specified a DB Server then just use the default used by the Farm
      If ([string]::IsNullOrEmpty($dbServer)) {
          $dbServer = $xmlinput.Configuration.Farm.Database.DBServer
      }
      $serviceInstanceType = "Microsoft.SharePoint.SPSubscriptionSettingsServiceInstance"
      CreateGenericServiceApplication -ServiceConfig $serviceConfig `
          -ServiceInstanceType $serviceInstanceType `
          -ServiceName $serviceConfig.Name `
          -ServiceGetCmdlet "Get-SPServiceApplication" `
          -ServiceProxyGetCmdlet "Get-SPServiceApplicationProxy" `
          -ServiceNewCmdlet "New-SPSubscriptionSettingsServiceApplication -DatabaseServer $dbServer -DatabaseName $serviceDB" `
          -ServiceProxyNewCmdlet "New-SPSubscriptionSettingsServiceApplicationProxy"

      Write-Host -ForegroundColor White " - Setting Site Subscription name `"$($serviceConfig.AppSiteSubscriptionName)`"..."
      Set-SPAppSiteSubscriptionName -Name $serviceConfig.AppSiteSubscriptionName -Confirm:$false
      WriteLine
  }
}