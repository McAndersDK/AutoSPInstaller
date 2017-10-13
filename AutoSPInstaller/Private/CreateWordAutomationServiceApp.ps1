Function CreateWordAutomationServiceApp ([xml]$xmlinput) {
  $serviceConfig = $xmlinput.Configuration.ServiceApps.WordAutomationService
  $dbServer = $serviceConfig.Database.DBServer
  # If we haven't specified a DB Server then just use the default used by the Farm
  If ([string]::IsNullOrEmpty($dbServer)) {
      $dbServer = $xmlinput.Configuration.Farm.Database.DBServer
  }
  $dbPrefix = Get-DBPrefix $xmlinput
  $serviceDB = $dbPrefix + $($serviceConfig.Database.Name)
  If ((ShouldIProvision $serviceConfig -eq $true) -and (Get-Command -Name New-SPWordConversionServiceApplication -ErrorAction SilentlyContinue)) {
      WriteLine
      $serviceInstanceType = "Microsoft.Office.Word.Server.Service.WordServiceInstance"
      CreateGenericServiceApplication -ServiceConfig $serviceConfig `
          -ServiceInstanceType $serviceInstanceType `
          -ServiceName $serviceConfig.Name `
          -ServiceProxyName $serviceConfig.ProxyName `
          -ServiceGetCmdlet "Get-SPServiceApplication" `
          -ServiceProxyGetCmdlet "Get-SPServiceApplicationProxy" `
          -ServiceNewCmdlet "New-SPWordConversionServiceApplication -DatabaseServer $dbServer -DatabaseName $serviceDB -Default" `
          -ServiceProxyNewCmdlet "New-SPWordConversionServiceApplicationProxy" # Fake cmdlet, but the CreateGenericServiceApplication function expects something
      # Run the Word Automation Timer Job immediately; otherwise we will have a Health Analyzer error condition until the job runs as scheduled
      If (Get-SPServiceApplication | Where-Object {$_.DisplayName -eq $($serviceConfig.Name)}) {
          Get-SPTimerJob | Where-Object {$_.GetType().ToString() -eq "Microsoft.Office.Word.Server.Service.QueueJob"} | ForEach-Object {$_.RunNow()}
      }
      WriteLine
  }
}