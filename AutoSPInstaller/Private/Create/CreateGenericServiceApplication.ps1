# ===================================================================================
# Func: CreateGenericServiceApplication
# Desc: General function that creates a broad range of service applications
# ===================================================================================
Function CreateGenericServiceApplication() {
  param
  (
      [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
      [String]$serviceConfig,
      [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
      [String]$serviceInstanceType,
      [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
      [String]$serviceName,
      [Parameter(Mandatory = $false)]
      [String]$serviceProxyName,
      [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
      [String]$serviceGetCmdlet,
      [Parameter(Mandatory = $false)][ValidateNotNullOrEmpty()]
      [String]$serviceProxyGetCmdlet,
      [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
      [String]$serviceNewCmdlet,
      [Parameter(Mandatory = $false)][ValidateNotNullOrEmpty()]
      [String]$serviceProxyNewCmdlet,
      [Parameter(Mandatory = $false)][ValidateNotNullOrEmpty()]
      [String]$serviceProxyNewParams
  )

  Try {
      $applicationPool = Get-HostedServicesAppPool $xmlinput
      Write-Host -ForegroundColor White " - Provisioning $serviceName..."
      # get the service instance
      $serviceInstances = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq $serviceInstanceType}
      $serviceInstance = $serviceInstances | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
      If (!$serviceInstance) { Throw " - Failed to get service instance - check product version (Standard vs. Enterprise)" }
      # Start Service instance
      Write-Host -ForegroundColor White " - Checking $($serviceInstance.TypeName) instance..."
      If (($serviceInstance.Status -eq "Disabled") -or ($serviceInstance.Status -ne "Online")) {
          Write-Host -ForegroundColor White " - Starting $($serviceInstance.TypeName) instance..."
          $serviceInstance.Provision()
          If (-not $?) { Throw " - Failed to start $($serviceInstance.TypeName) instance" }
          # Wait
          Write-Host -ForegroundColor Cyan " - Waiting for $($serviceInstance.TypeName) instance..." -NoNewline
          While ($serviceInstance.Status -ne "Online") {
              Write-Host -ForegroundColor Cyan "." -NoNewline
              Start-Sleep 1
              $serviceInstances = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq $serviceInstanceType}
              $serviceInstance = $serviceInstances | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
          }
          Write-Host -BackgroundColor Green -ForegroundColor Black $($serviceInstance.Status)
      }
      Else {
          Write-Host -ForegroundColor White " - $($serviceInstance.TypeName) instance already started."
      }
      # Check if our new cmdlets are available yet,  if not, re-load the SharePoint PS Snapin
      If (!(Get-Command $serviceGetCmdlet -ErrorAction SilentlyContinue)) {
          Write-Host -ForegroundColor White " - Re-importing SP PowerShell Snapin to enable new cmdlets..."
          Remove-PSSnapin Microsoft.SharePoint.PowerShell
          Load-SharePoint-PowerShell
      }
      $getServiceApplication = Invoke-Expression "$serviceGetCmdlet | Where-Object {`$_.Name -eq `"$serviceName`"}"
      If ($getServiceApplication -eq $null) {
          Write-Host -ForegroundColor White " - Creating $serviceName..."
          # A bit kludgey to accomodate the new PerformancePoint cmdlet in Service Pack 1, and some new SP2010 service apps (and still be able to use the CreateGenericServiceApplication function)
          If ((CheckFor2010SP1) -and ($serviceInstanceType -eq "Microsoft.PerformancePoint.Scorecards.BIMonitoringServiceInstance")) {
              $newServiceApplication = Invoke-Expression "$serviceNewCmdlet -Name `"$serviceName`" -ApplicationPool `$applicationPool -DatabaseServer `$dbServer -DatabaseName `$serviceDB"
          }
          Else {
              # Just do the regular non-database-bound service app creation
              $newServiceApplication = Invoke-Expression "$serviceNewCmdlet -Name `"$serviceName`" -ApplicationPool `$applicationPool"
          }
          $getServiceApplication = Invoke-Expression "$serviceGetCmdlet | Where-Object {`$_.Name -eq `"$serviceName`"}"
          if ($getServiceApplication) {
              Write-Host -ForegroundColor White " - Provisioning $serviceName Proxy..."
              # Because apparently the teams developing the cmdlets for the various service apps didn't communicate with each other, we have to account for the different ways each proxy is provisioned!
              Switch ($serviceInstanceType) {
                  "Microsoft.Office.Server.PowerPoint.SharePoint.Administration.PowerPointWebServiceInstance" {& $serviceProxyNewCmdlet -Name "$serviceProxyName" -ServiceApplication $newServiceApplication -AddToDefaultGroup | Out-Null}
                  "Microsoft.Office.Visio.Server.Administration.VisioGraphicsServiceInstance" {& $serviceProxyNewCmdlet -Name "$serviceProxyName" -ServiceApplication $newServiceApplication.Name | Out-Null}
                  "Microsoft.PerformancePoint.Scorecards.BIMonitoringServiceInstance" {& $serviceProxyNewCmdlet -Name "$serviceProxyName" -ServiceApplication $newServiceApplication -Default | Out-Null}
                  "Microsoft.Office.Excel.Server.MossHost.ExcelServerWebServiceInstance" {} # Do nothing because there is no cmdlet to create this services proxy
                  "Microsoft.Office.Access.Server.MossHost.AccessServerWebServiceInstance" {} # Do nothing because there is no cmdlet to create this services proxy
                  "Microsoft.Office.Word.Server.Service.WordServiceInstance" {} # Do nothing because there is no cmdlet to create this services proxy
                  "Microsoft.SharePoint.SPSubscriptionSettingsServiceInstance" {& $serviceProxyNewCmdlet -ServiceApplication $newServiceApplication | Out-Null}
                  "Microsoft.Office.Server.WorkManagement.WorkManagementServiceInstance" {& $serviceProxyNewCmdlet -Name "$serviceProxyName" -ServiceApplication $newServiceApplication -DefaultProxyGroup | Out-Null}
                  "Microsoft.Office.TranslationServices.TranslationServiceInstance" {} # Do nothing because the service app cmdlet automatically creates a proxy with the default name
                  "Microsoft.Office.Access.Services.MossHost.AccessServicesWebServiceInstance" {& $serviceProxyNewCmdlet -application $newServiceApplication | Out-Null}
                  "Microsoft.Office.Server.PowerPoint.Administration.PowerPointConversionServiceInstance" {& $serviceProxyNewCmdlet -Name "$serviceProxyName" -ServiceApplication $newServiceApplication -AddToDefaultGroup | Out-Null}
                  "Microsoft.Office.Project.Server.Administration.PsiServiceInstance" {} # Do nothing because the service app cmdlet automatically creates a proxy with the default name
                  Default {& $serviceProxyNewCmdlet -Name "$serviceProxyName" -ServiceApplication $newServiceApplication | Out-Null}
              }
              Write-Host -ForegroundColor White " - Done provisioning $serviceName. "
          }
          else {Write-Warning "An error occurred provisioning $serviceName! Check the log for any details, then try again."}
      }
      Else {
          Write-Host -ForegroundColor White " - $serviceName already created."
      }
  }
  Catch {
      Write-Output $_
      Pause "exit"
  }
}