# ===================================================================================
# Func: CreateBusinessDataConnectivityServiceApp
# Desc: Business Data Catalog Service Application
# From: http://autospinstaller.codeplex.com/discussions/246532 (user bunbunaz)
# ===================================================================================
Function CreateBusinessDataConnectivityServiceApp([xml]$xmlinput) {
  If ((ShouldIProvision $xmlinput.Configuration.ServiceApps.BusinessDataConnectivity -eq $true) -and (Get-Command -Name New-SPBusinessDataCatalogServiceApplication -ErrorAction SilentlyContinue)) {
      WriteLine
      Try {
          $dbServer = $xmlinput.Configuration.ServiceApps.BusinessDataConnectivity.Database.DBServer
          # If we haven't specified a DB Server then just use the default used by the Farm
          If ([string]::IsNullOrEmpty($dbServer)) {
              $dbServer = $xmlinput.Configuration.Farm.Database.DBServer
          }
          $bdcAppName = $xmlinput.Configuration.ServiceApps.BusinessDataConnectivity.Name
          $dbPrefix = Get-DBPrefix $xmlinput
          $bdcDataDB = $dbPrefix + $($xmlinput.Configuration.ServiceApps.BusinessDataConnectivity.Database.Name)
          $bdcAppProxyName = $xmlinput.Configuration.ServiceApps.BusinessDataConnectivity.ProxyName
          Write-Host -ForegroundColor White " - Provisioning $bdcAppName"
          $applicationPool = Get-HostedServicesAppPool $xmlinput
          Write-Host -ForegroundColor White " - Checking local service instance..."
          # Get the service instance
          $bdcServiceInstances = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.SharePoint.BusinessData.SharedService.BdcServiceInstance"}
          $bdcServiceInstance = $bdcServiceInstances | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
          If (-not $?) { Throw " - Failed to find the service instance" }
          # Start Service instances
          If ($bdcServiceInstance.Status -eq "Disabled") {
              Write-Host -ForegroundColor White " - Starting $($bdcServiceInstance.TypeName)..."
              $bdcServiceInstance.Provision()
              If (-not $?) { Throw " - Failed to start $($bdcServiceInstance.TypeName)" }
              # Wait
              Write-Host -ForegroundColor Cyan " - Waiting for $($bdcServiceInstance.TypeName)..." -NoNewline
              While ($bdcServiceInstance.Status -ne "Online") {
                  Write-Host -ForegroundColor Cyan "." -NoNewline
                  Start-Sleep 1
                  $bdcServiceInstances = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.SharePoint.BusinessData.SharedService.BdcServiceInstance"}
                  $bdcServiceInstance = $bdcServiceInstances | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
              }
              Write-Host -BackgroundColor Green -ForegroundColor Black ($bdcServiceInstance.Status)
          }
          Else {
              Write-Host -ForegroundColor White " - $($bdcServiceInstance.TypeName) already started."
          }
          # Create a Business Data Catalog Service Application
          If ((Get-SPServiceApplication | Where-Object {$_.GetType().ToString() -eq "Microsoft.SharePoint.BusinessData.SharedService.BdcServiceApplication"}) -eq $null) {
              # Create Service App
              Write-Host -ForegroundColor White " - Creating $bdcAppName..."
              $bdcDataServiceApp = New-SPBusinessDataCatalogServiceApplication -Name $bdcAppName -ApplicationPool $applicationPool -DatabaseServer $dbServer -DatabaseName $bdcDataDB
              If (-not $?) { Throw " - Failed to create $bdcAppName" }
          }
          Else {
              Write-Host -ForegroundColor White " - $bdcAppName already provisioned."
          }
          Write-Host -ForegroundColor White " - Done creating $bdcAppName."
      }
      Catch {
          Write-Output $_
          Throw " - Error provisioning Business Data Connectivity application"
      }
      WriteLine
  }
}