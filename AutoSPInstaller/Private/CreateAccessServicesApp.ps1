Function CreateAccessServicesApp ([xml]$xmlinput) {
  $officeServerPremium = $xmlinput.Configuration.Install.SKU -replace "Enterprise", "1" -replace "Standard", "0"
  $dbServer = $serviceConfig.Database.DBServer
  # If we haven't specified a DB Server then just use the default used by the Farm
  If ([string]::IsNullOrEmpty($dbServer)) {
      $dbServer = $xmlinput.Configuration.Farm.Database.DBServer
  }
  $dbPrefix = Get-DBPrefix $xmlinput
  $serviceDB = $dbPrefix + $($serviceConfig.Database.Name)
  $serviceConfig = $xmlinput.Configuration.EnterpriseServiceApps.AccessServices
  If ((ShouldIProvision $serviceConfig -eq $true) -and (Get-Command -Name New-SPAccessServicesApplication -ErrorAction SilentlyContinue)) {
      WriteLine
      if ($officeServerPremium -eq "1") {
          $serviceInstanceType = "Microsoft.Office.Access.Services.MossHost.AccessServicesWebServiceInstance"
          CreateGenericServiceApplication -ServiceConfig $serviceConfig `
              -ServiceInstanceType $serviceInstanceType `
              -ServiceName $serviceConfig.Name `
              -ServiceProxyName $serviceConfig.ProxyName `
              -ServiceGetCmdlet "Get-SPAccessServicesApplication" `
              -ServiceProxyGetCmdlet "Get-SPServicesApplicationProxy" `
              -ServiceNewCmdlet "New-SPAccessServicesApplication -DatabaseServer $dbServer -Default" `
              -ServiceProxyNewCmdlet "New-SPAccessServicesApplicationProxy"
      }
      else {
          Write-Warning "You have specified a non-Enterprise SKU in `"$(Split-Path -Path $inputFile -Leaf)`". However, SharePoint requires the Enterprise SKU and corresponding PIDKey to provision Access Services 2010."
      }
      WriteLine
  }
}