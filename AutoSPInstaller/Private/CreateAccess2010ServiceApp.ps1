Function CreateAccess2010ServiceApp ([xml]$xmlinput) {
  $officeServerPremium = $xmlinput.Configuration.Install.SKU -replace "Enterprise", "1" -replace "Standard", "0"
  $serviceConfig = $xmlinput.Configuration.EnterpriseServiceApps.AccessService
  If (ShouldIProvision $serviceConfig -eq $true) {
      WriteLine
      if ($officeServerPremium -eq "1") {
          $serviceInstanceType = "Microsoft.Office.Access.Server.MossHost.AccessServerWebServiceInstance"
          CreateGenericServiceApplication -ServiceConfig $serviceConfig `
              -ServiceInstanceType $serviceInstanceType `
              -ServiceName $serviceConfig.Name `
              -ServiceProxyName $serviceConfig.ProxyName `
              -ServiceGetCmdlet "Get-SPAccessServiceApplication" `
              -ServiceProxyGetCmdlet "Get-SPServiceApplicationProxy" `
              -ServiceNewCmdlet "New-SPAccessServiceApplication -Default" `
              -ServiceProxyNewCmdlet "New-SPAccessServiceApplicationProxy" # Fake cmdlet (and not needed for Access Services), but the CreateGenericServiceApplication function expects something
      }
      else {
          Write-Warning "You have specified a non-Enterprise SKU in `"$(Split-Path -Path $inputFile -Leaf)`". However, SharePoint requires the Enterprise SKU and corresponding PIDKey to provision Access Services 2010."
      }
      WriteLine
  }
}