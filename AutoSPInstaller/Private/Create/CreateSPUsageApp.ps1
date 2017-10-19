# ===================================================================================
# Func: CreateSPUsageApp
# Desc: Creates the Usage and Health Data Collection service application
# ===================================================================================
Function CreateSPUsageApp([xml]$xmlinput) {
  If ((ShouldIProvision $xmlinput.Configuration.ServiceApps.SPUsageService -eq $true) -and (Get-Command -Name New-SPUsageApplication -ErrorAction SilentlyContinue)) {
      WriteLine
      Try {
          $dbServer = $xmlinput.Configuration.ServiceApps.SPUsageService.Database.DBServer
          # If we haven't specified a DB Server then just use the default used by the Farm
          If ([string]::IsNullOrEmpty($dbServer)) {
              $dbServer = $xmlinput.Configuration.Farm.Database.DBServer
          }
          $spUsageApplicationName = $xmlinput.Configuration.ServiceApps.SPUsageService.Name
          $dbPrefix = Get-DBPrefix $xmlinput
          $spUsageDB = $dbPrefix + $xmlinput.Configuration.ServiceApps.SPUsageService.Database.Name
          $getSPUsageApplication = Get-SPUsageApplication
          If ($getSPUsageApplication -eq $null) {
              Write-Host -ForegroundColor White " - Provisioning SP Usage Application..."
              New-SPUsageApplication -Name $spUsageApplicationName -DatabaseServer $dbServer -DatabaseName $spUsageDB | Out-Null
              # Need this to resolve a known issue with the Usage Application Proxy not automatically starting/provisioning
              # Thanks and credit to Jesper Nygaard Schi?tt (jesper@schioett.dk) per http://autospinstaller.codeplex.com/Thread/View.aspx?ThreadId=237578 !
              Write-Host -ForegroundColor White " - Fixing Usage and Health Data Collection Proxy..."
              $spUsageApplicationProxy = Get-SPServiceApplicationProxy | Where-Object {$_.DisplayName -eq $spUsageApplicationName}
              $spUsageApplicationProxy.Provision()
              # End Usage Proxy Fix
              Write-Host -ForegroundColor White " - Enabling usage processing timer job..."
              $usageProcessingJob = Get-SPTimerJob | Where-Object {$_.TypeName -eq "Microsoft.SharePoint.Administration.SPUsageProcessingJobDefinition"}
              $usageProcessingJob.IsDisabled = $false
              $usageProcessingJob.Update()
              Write-Host -ForegroundColor White " - Done provisioning SP Usage Application."
          }
          Else {Write-Host -ForegroundColor White " - SP Usage Application already provisioned."}
      }
      Catch {
          Write-Output $_
          Throw " - Error provisioning the SP Usage Application"
      }
      WriteLine
  }
}