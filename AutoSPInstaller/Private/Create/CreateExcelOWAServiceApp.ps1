Function CreateExcelOWAServiceApp ([xml]$xmlinput) {
  Get-MajorVersionNumber $xmlinput
  $serviceConfig = $xmlinput.Configuration.OfficeWebApps.ExcelService
  If ((ShouldIProvision $serviceConfig -eq $true) -and (Test-Path "$env:CommonProgramFiles\Microsoft Shared\Web Server Extensions\$env:spVer\TEMPLATE\FEATURES\OfficeWebApps\feature.xml")) {
      WriteLine
      $portalWebApp = $xmlinput.Configuration.WebApplications.WebApplication | Where-Object {$_.Type -eq "Portal"} | Select-Object -First 1
      $portalURL = ($portalWebApp.URL).TrimEnd("/")
      $portalPort = $portalWebApp.Port
      $serviceInstanceType = "Microsoft.Office.Excel.Server.MossHost.ExcelServerWebServiceInstance"
      CreateGenericServiceApplication -ServiceConfig $serviceConfig `
          -ServiceInstanceType $serviceInstanceType `
          -ServiceName $serviceConfig.Name `
          -ServiceProxyName $serviceConfig.ProxyName `
          -ServiceGetCmdlet "Get-SPExcelServiceApplication" `
          -ServiceProxyGetCmdlet "Get-SPServiceApplicationProxy" `
          -ServiceNewCmdlet "New-SPExcelServiceApplication -Default" `
          -ServiceProxyNewCmdlet "New-SPExcelServiceApplicationProxy" # Fake cmdlet (and not needed for Excel Services), but the CreateGenericServiceApplication function expects something

      If (Get-SPExcelServiceApplication) {
          Write-Host -ForegroundColor White " - Setting Excel Services Trusted File Location..."
          Set-SPExcelFileLocation -Identity "http://" -LocationType SharePoint -IncludeChildren -Address $portalURL`:$portalPort -ExcelServiceApplication $($serviceConfig.Name) -ExternalDataAllowed 2 -WorkbookSizeMax 10
      }
      WriteLine
  }
}