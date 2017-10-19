Function CreateWordViewingOWAServiceApp ([xml]$xmlinput) {
  Get-MajorVersionNumber $xmlinput
  $serviceConfig = $xmlinput.Configuration.OfficeWebApps.WordViewingService
  If ((ShouldIProvision $serviceConfig -eq $true) -and (Test-Path "$env:CommonProgramFiles\Microsoft Shared\Web Server Extensions\$env:spVer\TEMPLATE\FEATURES\OfficeWebApps\feature.xml")) {
      WriteLine
      $serviceInstanceType = "Microsoft.Office.Web.Environment.Sharepoint.ConversionServiceInstance"
      CreateGenericServiceApplication -ServiceConfig $serviceConfig `
          -ServiceInstanceType $serviceInstanceType `
          -ServiceName $serviceConfig.Name `
          -ServiceProxyName $serviceConfig.ProxyName `
          -ServiceGetCmdlet "Get-SPServiceApplication" `
          -ServiceProxyGetCmdlet "Get-SPServiceApplicationProxy" `
          -ServiceNewCmdlet "New-SPWordViewingServiceApplication" `
          -ServiceProxyNewCmdlet "New-SPWordViewingServiceApplicationProxy"
      WriteLine
  }
}