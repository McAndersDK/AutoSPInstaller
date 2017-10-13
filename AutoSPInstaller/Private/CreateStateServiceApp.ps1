Function CreateStateServiceApp([xml]$xmlinput) {
  If ((ShouldIProvision $xmlinput.Configuration.ServiceApps.StateService -eq $true) -or `
      (ShouldIProvision $xmlinput.Configuration.EnterpriseServiceApps.AccessService -eq $true) -or `
      (ShouldIProvision $xmlinput.Configuration.EnterpriseServiceApps.VisioService -eq $true) -or `
      (ShouldIProvision $xmlinput.Configuration.EnterpriseServiceApps.AccessServices -eq $true) -or `
      (ShouldIProvision $xmlinput.Configuration.ServiceApps.WebAnalyticsService -eq $true)) {
      WriteLine
      Try {
          $stateService = $xmlinput.Configuration.ServiceApps.StateService
          $dbServer = $stateService.Database.DBServer
          # If we haven't specified a DB Server then just use the default used by the Farm
          If ([string]::IsNullOrEmpty($dbServer)) {
              $dbServer = $xmlinput.Configuration.Farm.Database.DBServer
          }
          $dbPrefix = Get-DBPrefix $xmlinput
          $stateServiceDB = $dbPrefix + $stateService.Database.Name
          $stateServiceName = $stateService.Name
          $stateServiceProxyName = $stateService.ProxyName
          If ($stateServiceName -eq $null) {$stateServiceName = "State Service Application"}
          If ($stateServiceProxyName -eq $null) {$stateServiceProxyName = $stateServiceName}
          $getSPStateServiceApplication = Get-SPStateServiceApplication
          If ($getSPStateServiceApplication -eq $null) {
              Write-Host -ForegroundColor White " - Provisioning State Service Application..."
              New-SPStateServiceDatabase -DatabaseServer $dbServer -Name $stateServiceDB | Out-Null
              New-SPStateServiceApplication -Name $stateServiceName -Database $stateServiceDB | Out-Null
              Get-SPStateServiceDatabase | Initialize-SPStateServiceDatabase | Out-Null
              Write-Host -ForegroundColor White " - Creating State Service Application Proxy..."
              Get-SPStateServiceApplication | New-SPStateServiceApplicationProxy -Name $stateServiceProxyName -DefaultProxyGroup | Out-Null
              Write-Host -ForegroundColor White " - Done creating State Service Application."
          }
          Else {Write-Host -ForegroundColor White " - State Service Application already provisioned."}
      }
      Catch {
          Write-Output $_
          Throw " - Error provisioning the state service application"
      }
      WriteLine
  }
}