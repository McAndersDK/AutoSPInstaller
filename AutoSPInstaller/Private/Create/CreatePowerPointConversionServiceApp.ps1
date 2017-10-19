Function CreatePowerPointConversionServiceApp ([xml]$xmlinput) {
  $serviceConfig = $xmlinput.Configuration.ServiceApps.PowerPointConversionService
  If ((ShouldIProvision $serviceConfig -eq $true) -and (Get-Command -Name New-SPPowerPointConversionServiceApplication -ErrorAction SilentlyContinue)) {
      WriteLine
      $serviceInstanceType = "Microsoft.Office.Server.PowerPoint.Administration.PowerPointConversionServiceInstance"
      CreateGenericServiceApplication -ServiceConfig $serviceConfig `
          -ServiceInstanceType $serviceInstanceType `
          -ServiceName $serviceConfig.Name `
          -ServiceProxyName $serviceConfig.ProxyName `
          -ServiceGetCmdlet "Get-SPServiceApplication" `
          -ServiceProxyGetCmdlet "Get-SPServiceApplicationProxy" `
          -ServiceNewCmdlet "New-SPPowerPointConversionServiceApplication" `
          -ServiceProxyNewCmdlet "New-SPPowerPointConversionServiceApplicationProxy"
      WriteLine
  }
}