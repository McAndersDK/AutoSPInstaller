Function CreateMachineTranslationServiceApp ([xml]$xmlinput) {
  $serviceConfig = $xmlinput.Configuration.ServiceApps.MachineTranslationService
  $dbServer = $serviceConfig.Database.DBServer
  # If we haven't specified a DB Server then just use the default used by the Farm
  If ([string]::IsNullOrEmpty($dbServer)) {
      $dbServer = $xmlinput.Configuration.Farm.Database.DBServer
  }
  $dbPrefix = Get-DBPrefix $xmlinput
  $translationDatabase = $dbPrefix + $($serviceConfig.Database.Name)
  If ((ShouldIProvision $serviceConfig -eq $true) -and (Get-Command -Name New-SPTranslationServiceApplication -ErrorAction SilentlyContinue)) {
      WriteLine
      $serviceInstanceType = "Microsoft.Office.TranslationServices.TranslationServiceInstance"
      CreateGenericServiceApplication -ServiceConfig $serviceConfig `
          -ServiceInstanceType $serviceInstanceType `
          -ServiceName $serviceConfig.Name `
          -ServiceProxyName $serviceConfig.ProxyName `
          -ServiceGetCmdlet "Get-SPServiceApplication" `
          -ServiceProxyGetCmdlet "Get-SPServiceApplicationProxy" `
          -ServiceNewCmdlet "New-SPTranslationServiceApplication -DatabaseServer $dbServer -DatabaseName $translationDatabase -Default" `
          -ServiceProxyNewCmdlet "New-SPTranslationServiceApplicationProxy"
      WriteLine
  }
}