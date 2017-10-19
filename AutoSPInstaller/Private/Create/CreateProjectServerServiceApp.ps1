Function CreateProjectServerServiceApp ([xml]$xmlinput) {
  Get-MajorVersionNumber $xmlinput
  $serviceConfig = $xmlinput.Configuration.ProjectServer.ServiceApp
  If ((ShouldIProvision $serviceConfig -eq $true) -and ($xmlinput.Configuration.ProjectServer.Install -eq $true) -and (Get-Command -Name New-SPProjectServiceApplication -ErrorAction SilentlyContinue)) {
      # We need to check that Project Server has been requested for install, not just if the service app should be provisioned
      WriteLine
      $dbPrefix = Get-DBPrefix $xmlinput
      $serviceDB = $dbPrefix + $serviceConfig.Database.Name
      $dbServer = $serviceConfig.Database.DBServer
      # If we haven't specified a DB Server then just use the default used by the Farm
      If ([string]::IsNullOrEmpty($dbServer)) {
          $dbServer = $xmlinput.Configuration.Farm.Database.DBServer
      }
      $serviceInstanceType = "Microsoft.Office.Project.Server.Administration.PsiServiceInstance"
      CreateGenericServiceApplication -ServiceConfig $serviceConfig `
          -ServiceInstanceType $serviceInstanceType `
          -ServiceName $serviceConfig.Name `
          -ServiceProxyName $serviceConfig.ProxyName `
          -ServiceGetCmdlet "Get-SPServiceApplication" `
          -ServiceProxyGetCmdlet "Get-SPServiceApplicationProxy" `
          -ServiceNewCmdlet "New-SPProjectServiceApplication -Proxy:`$true" `
          -ServiceProxyNewCmdlet "New-SPProjectServiceApplicationProxy" # We won't be using the proxy cmdlet though for Project Server

      # Update process account for Project services
      $projectServices = @("Microsoft.Office.Project.Server.Administration.ProjectEventService", "Microsoft.Office.Project.Server.Administration.ProjectCalcService", "Microsoft.Office.Project.Server.Administration.ProjectQueueService")
      foreach ($projectService in $projectServices) {
          $projectServiceInstances = (Get-SPFarm).Services | Where-Object {$_.GetType().ToString() -eq $projectService}
          foreach ($projectServiceInstance in $projectServiceInstances) {
              UpdateProcessIdentity $projectServiceInstance
          }
      }
      # Create a Project Server DB (2013 only)
      $portalWebApp = $xmlinput.Configuration.WebApplications.WebApplication | Where-Object {$_.Type -eq "Portal"} | Select-Object -First 1
      if (!(Get-SPDatabase | Where-Object {$_.Name -eq $serviceDB})) {
          if (Get-Command -Name New-SPProjectDatabase -ErrorAction SilentlyContinue) {
              # Check for this since it no longer exists in SP2016
              Write-Host -ForegroundColor White " - Creating Project Server database `"$serviceDB`"..." -NoNewline
              New-SPProjectDatabase -Name $serviceDB -ServiceApplication (Get-SPServiceApplication | Where-Object {$_.Name -eq $serviceConfig.Name}) -DatabaseServer $dbServer | Out-Null
              if ($?) {Write-Host -ForegroundColor Black -BackgroundColor Cyan "Done."}
              else {
                  Write-Host -ForegroundColor White "."
                  throw {"Error creating the Project Server database."}
              }
          }
      }
      else {
          Write-Host -ForegroundColor Black -BackgroundColor Cyan "Already exists."
      }
      # Create a Project Server Web Instance
      $projectManagedPath = $xmlinput.Configuration.ProjectServer.ServiceApp.ManagedPath
      New-SPManagedPath -RelativeURL $xmlinput.Configuration.ProjectServer.ServiceApp.ManagedPath -WebApplication (Get-SPWebApplication | Where-Object {$_.Name -eq $portalWebApp.Name}) -Explicit:$true -ErrorAction SilentlyContinue | Out-Null
      Write-Host -ForegroundColor White " - Creating Project Server site collection at `"$projectManagedPath`"..." -NoNewline
      $projectSiteUrl = ($portalWebApp.Url).TrimEnd("/") + ":" + $portalWebApp.Port + "/" + $projectManagedPath
      if (!(Get-SPSite -Identity $projectSiteUrl -ErrorAction SilentlyContinue)) {
          $projectSite = New-SPSite -Url $projectSiteUrl  -OwnerAlias $env:USERDOMAIN\$env:USERNAME -Template "PROJECTSITE#0"
          if ($?) {Write-Host -ForegroundColor Black -BackgroundColor Green "Done."}
          else {
              Write-Host -ForegroundColor White "."
              throw {"Error creating the Project Server site collection."}
          }
      }
      else {
          Write-Host -ForegroundColor Black -BackgroundColor Cyan "Already exists."
      }
      Write-Host -ForegroundColor White " - Checking for Project Server web instance at `"$projectSiteUrl`"..." -NoNewline
      if (!(Get-SPProjectWebInstance -Url $projectSiteUrl -ErrorAction SilentlyContinue)) {
          Write-Host -ForegroundColor White "."
          if ((Get-Command -Name Mount-SPProjectWebInstance -ErrorAction SilentlyContinue) -and ($env:SPVer -le 15)) {
              # Check for this since the command no longer exists in SP2016
              Write-Host -ForegroundColor White " - Creating Project Server web instance at `"$projectSiteUrl`"..." -NoNewline
              Mount-SPProjectWebInstance -DatabaseName $serviceDB -SiteCollection $projectSite
              if ($?) {Write-Host -ForegroundColor Black -BackgroundColor Green "Done."}
              else {
                  Write-Host -ForegroundColor White "."
                  throw {"Error creating the Project Server web instance."}
              }
          }
          elseif ($env:spVer -ge 16) {    
              $pidKeyProjectServer = $xmlinput.Configuration.ProjectServer.PIDKeyProjectServer
              Write-Host -ForegroundColor White " - Enabling Project Server license key..."
              Enable-ProjectServerLicense -Key $pidKeyProjectServer
              Write-Host -ForegroundColor White " - Creating Project Web Instance by enabling PWA feature on `"$projectSiteUrl`"..." -NoNewline
              Enable-SPFeature -Identity pwasite -Url $projectSiteUrl
              if ($?) {Write-Host -ForegroundColor Black -BackgroundColor Green "Done."}
              else {
                  Write-Host -ForegroundColor White "."
                  throw {"Error creating the Project Server web instance."}
              }
          }
      }
      else {
          Write-Host -ForegroundColor Black -BackgroundColor Cyan "Already exists."
      }
      WriteLine
  }
}