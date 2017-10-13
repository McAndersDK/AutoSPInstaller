Function CreatePowerPointOWAServiceApp ([xml]$xmlinput) {
  Get-MajorVersionNumber $xmlinput
  $serviceConfig = $xmlinput.Configuration.OfficeWebApps.PowerPointService
  If ((ShouldIProvision $serviceConfig -eq $true) -and (Test-Path "$env:CommonProgramFiles\Microsoft Shared\Web Server Extensions\$env:spVer\TEMPLATE\FEATURES\OfficeWebApps\feature.xml")) {
      WriteLine
      If ($env:spVer -eq "14") {$serviceInstanceType = "Microsoft.Office.Server.PowerPoint.SharePoint.Administration.PowerPointWebServiceInstance"}
      CreateGenericServiceApplication -ServiceConfig $serviceConfig `
          -ServiceInstanceType $serviceInstanceType `
          -ServiceName $serviceConfig.Name `
          -ServiceProxyName $serviceConfig.ProxyName `
          -ServiceGetCmdlet "Get-SPPowerPointServiceApplication" `
          -ServiceProxyGetCmdlet "Get-SPPowerPointServiceApplicationProxy" `
          -ServiceNewCmdlet "New-SPPowerPointServiceApplication" `
          -ServiceProxyNewCmdlet "New-SPPowerPointServiceApplicationProxy"
      WriteLine
  }
}
