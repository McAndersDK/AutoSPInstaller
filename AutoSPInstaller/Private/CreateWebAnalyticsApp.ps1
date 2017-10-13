# Thanks and credit to Jesper Nygaard Schi?tt (jesper@schioett.dk) per http://autospinstaller.codeplex.com/Thread/View.aspx?ThreadId=237578 !

Function CreateWebAnalyticsApp([xml]$xmlinput) {
  Get-MajorVersionNumber $xmlinput
  If ((ShouldIProvision $xmlinput.Configuration.ServiceApps.WebAnalyticsService -eq $true) -and ($env:spVer -eq "14")) {
      WriteLine
      Try {
          $dbServer = $xmlinput.Configuration.ServiceApps.WebAnalyticsService.Database.DBServer
          # If we haven't specified a DB Server then just use the default used by the Farm
          If ([string]::IsNullOrEmpty($dbServer)) {
              $dbServer = $xmlinput.Configuration.Farm.Database.DBServer
          }
          $applicationPool = Get-HostedServicesAppPool $xmlinput
          $dbPrefix = Get-DBPrefix $xmlinput
          $webAnalyticsReportingDB = $dbPrefix + $xmlinput.Configuration.ServiceApps.WebAnalyticsService.Database.ReportingDB
          $webAnalyticsStagingDB = $dbPrefix + $xmlinput.Configuration.ServiceApps.WebAnalyticsService.Database.StagingDB
          $webAnalyticsServiceName = $xmlinput.Configuration.ServiceApps.WebAnalyticsService.Name
          $getWebAnalyticsServiceApplication = Get-SPWebAnalyticsServiceApplication $webAnalyticsServiceName -ea SilentlyContinue
          Write-Host -ForegroundColor White " - Provisioning $webAnalyticsServiceName..."
          # Start Analytics service instances
          Write-Host -ForegroundColor White " - Checking Analytics Service instances..."
          $analyticsWebServiceInstances = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.Office.Server.WebAnalytics.Administration.WebAnalyticsWebServiceInstance"}
          $analyticsWebServiceInstance = $analyticsWebServiceInstances | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
          If (-not $?) { Throw " - Failed to find Analytics Web Service instance" }
          Write-Host -ForegroundColor White " - Starting local Analytics Web Service instance..."
          $analyticsWebServiceInstance.Provision()
          $analyticsDataProcessingInstances = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.Office.Server.WebAnalytics.Administration.WebAnalyticsServiceInstance"}
          $analyticsDataProcessingInstance = $analyticsDataProcessingInstances | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
          If (-not $?) { Throw " - Failed to find Analytics Data Processing Service instance" }
          UpdateProcessIdentity $analyticsDataProcessingInstance
          $analyticsDataProcessingInstance.Update()
          Write-Host -ForegroundColor White " - Starting local Analytics Data Processing Service instance..."
          $analyticsDataProcessingInstance.Provision()
          If ($getWebAnalyticsServiceApplication -eq $null) {
              $stagerSubscription = "<StagingDatabases><StagingDatabase ServerName='$dbServer' DatabaseName='$webAnalyticsStagingDB'/></StagingDatabases>"
              $warehouseSubscription = "<ReportingDatabases><ReportingDatabase ServerName='$dbServer' DatabaseName='$webAnalyticsReportingDB'/></ReportingDatabases>"
              Write-Host -ForegroundColor White " - Creating $webAnalyticsServiceName..."
              $serviceApplication = New-SPWebAnalyticsServiceApplication -Name $webAnalyticsServiceName -ReportingDataRetention 20 -SamplingRate 100 -ListOfReportingDatabases $warehouseSubscription -ListOfStagingDatabases $stagerSubscription -ApplicationPool $applicationPool
              # Create Web Analytics Service Application Proxy
              Write-Host -ForegroundColor White " - Creating $webAnalyticsServiceName Proxy..."
              $newWebAnalyticsServiceApplicationProxy = New-SPWebAnalyticsServiceApplicationProxy  -Name $webAnalyticsServiceName -ServiceApplication $serviceApplication.Name
          }
          Else {Write-Host -ForegroundColor White " - Web Analytics Service Application already provisioned."}
      }
      Catch {
          Write-Output $_
          Throw " - Error Provisioning Web Analytics Service Application"
      }
      WriteLine
  }
}