# Original script for SharePoint 2010 beta2 by Gary Lapointe ()
#
# Modified by Søren Laurits Nielsen (soerennielsen.wordpress.com):
#
# Modified to fix some errors since some cmdlets have changed a bit since beta 2 and added support for "ShareName" for
# the query component. It is required for non DC computers.
#
# Modified to support "localhost" moniker in config file.
#
# Note: Accounts, Shares and directories specified in the config file must be setup beforehand.

function CreateEnterpriseSearchServiceApp {
    param(
        [xml]$xmlinput
    )
  Get-MajorVersionNumber $xmlinput
  $searchServiceAccount = Get-SPManagedAccountXML $xmlinput -CommonName "SearchService"
  # Check if the Search Service account username has been specified before we try to convert its password to a secure string
  if (!([string]::IsNullOrEmpty($searchServiceAccount.Username))) {
    $secSearchServicePassword = ConvertTo-SecureString -String $searchServiceAccount.Password -AsPlainText -Force
  }
  else {
    Write-Host -ForegroundColor White " - Managed account credentials for Search Service have not been specified."
  }

  # We now do a check that both Search is being requested for provisioning and that we are not running the Foundation SKU
  If (((ShouldIProvision $xmlinput.Configuration.ServiceApps.EnterpriseSearchService) -eq $true) -and (Get-Command -Name New-SPEnterpriseSearchServiceApplication -ErrorAction SilentlyContinue) -and ($xmlinput.Configuration.Install.SKU -ne "Foundation")) {
    WriteLine
    Write-Host -ForegroundColor White " - Provisioning Enterprise Search..."
    # SLN: Added support for local host
    $svcConfig = $xmlinput.Configuration.ServiceApps.EnterpriseSearchService
    $portalWebApp = $xmlinput.Configuration.WebApplications.WebApplication | Where-Object {$_.Type -eq "Portal"} | Select-Object -First 1
    $portalURL = ($portalWebApp.URL).TrimEnd("/")
    $portalPort = $portalWebApp.Port
    if ($xmlinput.Configuration.ServiceApps.UserProfileServiceApp.Provision -ne $false) {
      # We didn't use ShouldIProvision here as we want to know if UPS is being provisioned in this farm, not just on this server
      $mySiteWebApp = $xmlinput.Configuration.WebApplications.WebApplication | Where-Object {$_.Type -eq "MySiteHost"}
      # If we have asked to create a MySite Host web app, use that as the MySite host location
      if ($mySiteWebApp) {
        $mySiteURL = ($mySiteWebApp.URL).TrimEnd("/")
        $mySitePort = $mySiteWebApp.Port
        $mySiteHostLocation = $mySiteURL + ":" + $mySitePort
      }
      else {
        # Use the value provided in the $userProfile node
        $mySiteHostLocation = $xmlinput.Configuration.ServiceApps.UserProfileServiceApp.MySiteHostLocation
      }
      # Strip out any protocol values
      $mySiteHostHeaderAndPort, $null = $mySiteHostLocation -replace "http://", "" -replace "https://", "" -split "/"
    }

    $dataDir = $xmlinput.Configuration.Install.DataDir
    $dataDir = $dataDir.TrimEnd("\")
    # Set it to the default value if it's not specified in $xmlinput
    if ([string]::IsNullOrEmpty($dataDir)) {$dataDir = "$env:ProgramFiles\Microsoft Office Servers\$env:spVer.0\Data"}

    $searchSvc = Get-SPEnterpriseSearchServiceInstance -Local
    If ($searchSvc -eq $null) {
      Throw "  - Unable to retrieve search service."
    }
    if ([string]::IsNullOrEmpty($svcConfig.CustomIndexLocation)) {
      # Use the default location
      $indexLocation = "$dataDir\Office Server\Applications"
    }
    else {
      $indexLocation = $svcConfig.CustomIndexLocation
      $indexLocation = $indexLocation.TrimEnd("\")
      # If the requested index location is not the default, make sure the new location exists so we can use it later in the script
      if ($indexLocation -ne "$dataDir\Office Server\Applications") {
        Write-Host -ForegroundColor White " - Checking requested IndexLocation path..."
        EnsureFolder $svcConfig.CustomIndexLocation
      }
    }
    Write-Host -ForegroundColor White "  - Configuring search service..." -NoNewline
    Get-SPEnterpriseSearchService | Set-SPEnterpriseSearchService  `
      -ContactEmail $svcConfig.ContactEmail -ConnectionTimeout $svcConfig.ConnectionTimeout `
      -AcknowledgementTimeout $svcConfig.AcknowledgementTimeout -ProxyType $svcConfig.ProxyType `
      -IgnoreSSLWarnings $svcConfig.IgnoreSSLWarnings -InternetIdentity $svcConfig.InternetIdentity -PerformanceLevel $svcConfig.PerformanceLevel `
      -ServiceAccount $searchServiceAccount.Username -ServicePassword $secSearchServicePassword
    If ($?) {
        Write-Host -ForegroundColor Green "Done."
    }


    If ($env:spVer -eq "14") {
      # SharePoint 2010 steps
      $svcConfig.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication | ForEach-Object {
        $appConfig = $_
        $dbPrefix = Get-DBPrefix $xmlinput
        If (!([string]::IsNullOrEmpty($appConfig.Database.DBServer))) {
          $dbServer = $appConfig.Database.DBServer
        }
        Else {
          $dbServer = $xmlinput.Configuration.Farm.Database.DBServer
        }
        $secContentAccessAcctPWD = ConvertTo-SecureString -String $appConfig.ContentAccessAccountPassword -AsPlainText -Force
        # Try and get the application pool if it already exists
        $pool = Get-ApplicationPool $appConfig.ApplicationPool
        $adminPool = Get-ApplicationPool $appConfig.AdminComponent.ApplicationPool
        $searchApp = Get-SPEnterpriseSearchServiceApplication -Identity $appConfig.Name -ErrorAction SilentlyContinue
        If ($searchApp -eq $null) {
          Write-Host -ForegroundColor White " - Creating $($appConfig.Name)..."
          $searchApp = New-SPEnterpriseSearchServiceApplication -Name $appConfig.Name `
            -DatabaseServer $dbServer `
            -DatabaseName $($dbPrefix + $appConfig.Database.Name) `
            -FailoverDatabaseServer $appConfig.FailoverDatabaseServer `
            -ApplicationPool $pool `
            -AdminApplicationPool $adminPool `
            -Partitioned:([bool]::Parse($appConfig.Partitioned)) `
            -SearchApplicationType $appConfig.SearchServiceApplicationType
        }
        Else {
          Write-Host -ForegroundColor White " - Enterprise search service application already exists, skipping creation."
        }

        # Add link to resources list
        AddResourcesLink "Search Administration" ("searchadministration.aspx?appid=" + $searchApp.Id)

        # If the index location isn't already set to either the default location or our custom-specified location, set the default location for the search service instance
        if ($indexLocation -ne "$dataDir\Office Server\Applications" -or $indexLocation -ne $searchSvc.DefaultIndexLocation) {
          Write-Host -ForegroundColor White "  - Setting default index location on search service instance..." -NoNewline
          $searchSvc | Set-SPEnterpriseSearchServiceInstance -DefaultIndexLocation $indexLocation -ErrorAction SilentlyContinue
          if ($?) {
              Write-Host -ForegroundColor White "OK."
            }
        }

        # Finally using ShouldIProvision here like everywhere else in the script...
        $installCrawlSvc = ShouldIProvision $appConfig.CrawlComponent
        $installQuerySvc = ShouldIProvision $appConfig.QueryComponent
        $installAdminComponent = ShouldIProvision $appConfig.AdminComponent
        $installSyncSvc = ShouldIProvision $appConfig.SearchQueryAndSiteSettingsComponent

        If ($searchSvc.Status -ne "Online" -and ($installCrawlSvc -or $installQuerySvc)) {
          $searchSvc | Start-SPEnterpriseSearchServiceInstance
        }

        If ($installAdminComponent) {
          Write-Host -ForegroundColor White " - Setting administration component..."
          Set-SPEnterpriseSearchAdministrationComponent -SearchApplication $searchApp -SearchServiceInstance $searchSvc

          $adminCmpnt = $searchApp | Get-SPEnterpriseSearchAdministrationComponent
          If ($adminCmpnt.Initialized -eq $false) {
            Write-Host -ForegroundColor Cyan " - Waiting for administration component initialization..." -NoNewline
            While ($adminCmpnt.Initialized -ne $true) {
              Write-Host -ForegroundColor Cyan "." -NoNewline
              Start-Sleep 1
              $adminCmpnt = $searchApp | Get-SPEnterpriseSearchAdministrationComponent
            }
            Write-Host -BackgroundColor Green -ForegroundColor Black $($adminCmpnt.Initialized -replace "True", "Done.")
          }
          Else {
              Write-Host -ForegroundColor White " - Administration component already initialized."
            }
        }
        # Update the default Content Access Account
        Update-SearchContentAccessAccount $($appconfig.Name) $searchApp $($appConfig.ContentAccessAccount) $secContentAccessAcctPWD


        $crawlTopology = Get-SPEnterpriseSearchCrawlTopology -SearchApplication $searchApp | Where-Object { $_.CrawlComponents.Count -gt 0 -or $_.State -eq "Inactive" }

        If ($crawlTopology -eq $null) {
          Write-Host -ForegroundColor White " - Creating new crawl topology..."
          $crawlTopology = $searchApp | New-SPEnterpriseSearchCrawlTopology
        }
        Else {
          Write-Host -ForegroundColor White " - A crawl topology with crawl components already exists, skipping crawl topology creation."
        }

        If ($installCrawlSvc) {
          $crawlComponent = $crawlTopology.CrawlComponents | Where-Object {MatchComputerName $_.ServerName $env:COMPUTERNAME}
          If ($crawlTopology.CrawlComponents.Count -eq 0 -or $crawlComponent -eq $null) {
            $crawlStore = $searchApp.CrawlStores | Where-Object { $_.Name -eq "$($dbPrefix+$appConfig.Database.Name)_CrawlStore" }
            Write-Host -ForegroundColor White " - Creating new crawl component..."
            $crawlComponent = New-SPEnterpriseSearchCrawlComponent -SearchServiceInstance $searchSvc -SearchApplication $searchApp -CrawlTopology $crawlTopology -CrawlDatabase $crawlStore.Id.ToString() -IndexLocation $indexLocation
          }
          Else {
            Write-Host -ForegroundColor White " - Crawl component already exist, skipping crawl component creation."
          }
        }

        $queryTopologies = Get-SPEnterpriseSearchQueryTopology -SearchApplication $searchApp | Where-Object { $_.QueryComponents.Count -gt 0 -or $_.State -eq "Inactive" }
        If ($queryTopologies.Count -lt 1) {
          Write-Host -ForegroundColor White " - Creating new query topology..."
          $queryTopology = $searchApp | New-SPEnterpriseSearchQueryTopology -Partitions $appConfig.Partitions
        }
        Else {
          Write-Host -ForegroundColor White " - A query topology already exists, skipping query topology creation."
          If ($queryTopologies.Count -gt 1) {
            # Try to select the query topology that has components
            $queryTopology = $queryTopologies | Where-Object { $_.QueryComponents.Count -gt 0 } | Select-Object -First 1
            if (!$queryTopology) {
              # Just select the first query topology since none appear to have query components
              $queryTopology = $queryTopologies | Select-Object -First 1
            }
          }
          Else {
            # Just set it to $queryTopologies since there is only one
            $queryTopology = $queryTopologies
          }
        }

        If ($installQuerySvc) {
          $queryComponent = $queryTopology.QueryComponents | Where-Object { MatchComputerName $_.ServerName $env:COMPUTERNAME }
          If ($queryComponent -eq $null) {
            $partition = ($queryTopology | Get-SPEnterpriseSearchIndexPartition)
            Write-Host -ForegroundColor White " - Creating new query component..."
            $queryComponent = New-SPEnterpriseSearchQueryComponent -IndexPartition $partition -QueryTopology $queryTopology -SearchServiceInstance $searchSvc -ShareName $svcConfig.ShareName -IndexLocation $indexLocation
            Write-Host -ForegroundColor White " - Setting index partition and property store database..."
            $propertyStore = $searchApp.PropertyStores | Where-Object { $_.Name -eq "$($dbPrefix+$appConfig.Database.Name)_PropertyStore" }
            $partition | Set-SPEnterpriseSearchIndexPartition -PropertyDatabase $propertyStore.Id.ToString()
          }
          Else {
            Write-Host -ForegroundColor White " - Query component already exists, skipping query component creation."
          }
        }

        If ($installSyncSvc) {
          # SLN: Updated to new syntax
          $searchQueryAndSiteSettingsServices = Get-SPServiceInstance | Where-Object { $_.GetType().ToString() -eq "Microsoft.Office.Server.Search.Administration.SearchQueryAndSiteSettingsServiceInstance" }
          $searchQueryAndSiteSettingsService = $searchQueryAndSiteSettingsServices | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
          If (-not $?) { 
              Throw " - Failed to find Search Query and Site Settings service instance" 
            }
          # Start Service instance
          Write-Host -ForegroundColor White " - Starting Search Query and Site Settings Service Instance..."
          If ($searchQueryAndSiteSettingsService.Status -eq "Disabled") {
            $searchQueryAndSiteSettingsService.Provision()
            If (-not $?) { 
                Throw " - Failed to start Search Query and Site Settings service instance" 
            }
            # Wait
            Write-Host -ForegroundColor Cyan " - Waiting for Search Query and Site Settings service..." -NoNewline
            While ($searchQueryAndSiteSettingsService.Status -ne "Online") {
              Write-Host -ForegroundColor Cyan "." -NoNewline
              Start-Sleep 1
              $searchQueryAndSiteSettingsServices = Get-SPServiceInstance | Where-Object { $_.GetType().ToString() -eq "Microsoft.Office.Server.Search.Administration.SearchQueryAndSiteSettingsServiceInstance" }
              $searchQueryAndSiteSettingsService = $searchQueryAndSiteSettingsServices | Where-Object { MatchComputerName $_.Server.Address $env:COMPUTERNAME }
            }
            Write-Host -BackgroundColor Green -ForegroundColor Black $($searchQueryAndSiteSettingsService.Status)
          }
          Else {Write-Host -ForegroundColor White " - Search Query and Site Settings Service already started."}
        }

        # Don't activate until we've added all components
        $allCrawlServersDone = $true
        # Put any comma- or space-delimited servers we find in the "Provision" attribute into an array
        [array]$crawlServersToProvision = $appConfig.CrawlComponent.Provision -split "," -split " "
        $crawlServersToProvision | ForEach-Object {
          $crawlServer = $_
          $top = $crawlTopology.CrawlComponents | Where-Object { $_.ServerName -eq $crawlServer }
          If ($top -eq $null) { 
              $allCrawlServersDone = $false 
            }
        }

        If ($allCrawlServersDone -and $crawlTopology.State -ne "Active") {
          Write-Host -ForegroundColor White " - Setting new crawl topology to active..."
          $crawlTopology | Set-SPEnterpriseSearchCrawlTopology -Active -Confirm:$false
          Write-Host -ForegroundColor Cyan " - Waiting for Crawl Components..." -NoNewLine
          while ($true) {
            $ct = Get-SPEnterpriseSearchCrawlTopology -Identity $crawlTopology -SearchApplication $searchApp
            $state = $ct.CrawlComponents | Where-Object {$_.State -ne "Ready"}
            If ($ct.State -eq "Active" -and $state -eq $null) {
              break
            }
            Write-Host -ForegroundColor Cyan "." -NoNewLine
            Start-Sleep 1
          }
          Write-Host -BackgroundColor Green -ForegroundColor Black $($crawlTopology.State)

          # Need to delete the original crawl topology that was created by default
          $searchApp | Get-SPEnterpriseSearchCrawlTopology | Where-Object { $_.State -eq "Inactive" } | Remove-SPEnterpriseSearchCrawlTopology -Confirm:$false
        }

        $allQueryServersDone = $true
        # Put any comma- or space-delimited servers we find in the "Provision" attribute into an array
        [array]$queryServersToProvision = $appConfig.QueryComponent.Provision -split "," -split " "
        $queryServersToProvision | ForEach-Object {
          $queryServer = $_
          $top = $queryTopology.QueryComponents | Where-Object { $_.ServerName -eq $queryServer }
          If ($top -eq $null) { 
              $allQueryServersDone = $false 
            }
        }

        # Make sure we have a crawl component added and started before trying to enable the query component
        If ($allCrawlServersDone -and $allQueryServersDone -and $queryTopology.State -ne "Active") {
          Write-Host -ForegroundColor White " - Setting query topology as active..."
          $queryTopology | Set-SPEnterpriseSearchQueryTopology -Active -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable err
          Write-Host -ForegroundColor Cyan " - Waiting for Query Components..." -NoNewLine
          while ($true) {
            $qt = Get-SPEnterpriseSearchQueryTopology -Identity $queryTopology -SearchApplication $searchApp
            $state = $qt.QueryComponents | Where-Object {$_.State -ne "Ready"}
            If ($qt.State -eq "Active" -and $state -eq $null) {
              break
            }
            Write-Host -ForegroundColor Cyan "." -NoNewLine
            Start-Sleep 1
          }
          Write-Host -BackgroundColor Green -ForegroundColor Black $($queryTopology.State)

          # Need to delete the original query topology that was created by default
          $origQueryTopology = $searchApp | Get-SPEnterpriseSearchQueryTopology | Where-Object {$_.QueryComponents.Count -eq 0}
          If ($origQueryTopology.State -eq "Inactive") {
            Write-Host -ForegroundColor White " - Removing original (default) query topology..."
            $origQueryTopology | Remove-SPEnterpriseSearchQueryTopology -Confirm:$false
          }
        }

        $proxy = Get-SPEnterpriseSearchServiceApplicationProxy -Identity $appConfig.Proxy.Name -ErrorAction SilentlyContinue
        If ($proxy -eq $null) {
          Write-Host -ForegroundColor White " - Creating enterprise search service application proxy..."
          $proxy = New-SPEnterpriseSearchServiceApplicationProxy -Name $appConfig.Proxy.Name -SearchApplication $searchApp -Partitioned:([bool]::Parse($appConfig.Proxy.Partitioned))
        }
        Else {
          Write-Host -ForegroundColor White " - Enterprise search service application proxy already exists, skipping creation."
        }
        If ($proxy.Status -ne "Online") {
          $proxy.Status = "Online"
          $proxy.Update()
        }
        Write-Host -ForegroundColor White " - Setting proxy group membership..."
        $proxy | Set-ProxyGroupsMembership $appConfig.Proxy
      }
      WriteLine
    }
    ElseIf ($env:spVer -ge "15") {
      # SharePoint 2013+ steps
      $svcConfig.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication | ForEach-Object {
        $appConfig = $_
        $dbPrefix = Get-DBPrefix $xmlinput
        If (!([string]::IsNullOrEmpty($appConfig.Database.DBServer))) {
          $dbServer = $appConfig.Database.DBServer
        }
        Else {
          $dbServer = $xmlinput.Configuration.Farm.Database.DBServer
        }
        $secContentAccessAcctPWD = ConvertTo-SecureString -String $appConfig.ContentAccessAccountPassword -AsPlainText -Force

        # Finally using ShouldIProvision here like everywhere else in the script...
        $installCrawlComponent = ShouldIProvision $appConfig.CrawlComponent
        $installQueryComponent = ShouldIProvision $appConfig.QueryComponent
        $installAdminComponent = ShouldIProvision $appConfig.AdminComponent
        $installSyncSvc = ShouldIProvision $appConfig.SearchQueryAndSiteSettingsComponent
        $installAnalyticsProcessingComponent = ShouldIProvision $appConfig.AnalyticsProcessingComponent
        $installContentProcessingComponent = ShouldIProvision $appConfig.ContentProcessingComponent
        $installIndexComponent = ShouldIProvision $appConfig.IndexComponent

        $pool = Get-ApplicationPool $appConfig.ApplicationPool
        $adminPool = Get-ApplicationPool $appConfig.AdminComponent.ApplicationPool
        $appPoolUserName = $searchServiceAccount.Username

        $saAppPool = Get-SPServiceApplicationPool -Identity $pool -ErrorAction SilentlyContinue
        if ($saAppPool -eq $null) {
          Write-Host -ForegroundColor White "  - Creating Service Application Pool..."

          $appPoolAccount = Get-SPManagedAccount -Identity $appPoolUserName -ErrorAction SilentlyContinue
          if ($appPoolAccount -eq $null) {
            Write-Host -ForegroundColor White "  - Please supply the password for the Service Account..."
            $appPoolCred = Get-Credential $appPoolUserName
            $appPoolAccount = New-SPManagedAccount -Credential $appPoolCred -ErrorAction SilentlyContinue
          }

          $appPoolAccount = Get-SPManagedAccount -Identity $appPoolUserName -ErrorAction SilentlyContinue

          if ($appPoolAccount -eq $null) {
            Throw "  - Cannot create or find the managed account $appPoolUserName, please ensure the account exists."
          }

          New-SPServiceApplicationPool -Name $pool -Account $appPoolAccount -ErrorAction SilentlyContinue | Out-Null
        }

        # From http://mmman.itgroove.net/2012/12/search-host-controller-service-in-starting-state-sharepoint-2013-8/
        # And http://blog.thewulph.com/?p=374
        Write-Host -ForegroundColor White "  - Fixing registry permissions for Search Host Controller Service..." -NoNewline
        $acl = Get-Acl HKLM:\System\CurrentControlSet\Control\ComputerName
        $person = [System.Security.Principal.NTAccount] "WSS_WPG" # Trimmed down from the original "Users"
        $access = [System.Security.AccessControl.RegistryRights]::FullControl
        $inheritance = [System.Security.AccessControl.InheritanceFlags] "ContainerInherit, ObjectInherit"
        $propagation = [System.Security.AccessControl.PropagationFlags]::None
        $type = [System.Security.AccessControl.AccessControlType]::Allow
        $rule = New-Object System.Security.AccessControl.RegistryAccessRule($person, $access, $inheritance, $propagation, $type)
        $acl.AddAccessRule($rule)
        Set-Acl HKLM:\System\CurrentControlSet\Control\ComputerName $acl
        Write-Host -ForegroundColor White "OK."

        Write-Host -ForegroundColor White "  - Checking Search Service Instance..." -NoNewline
        If ($searchSvc.Status -eq "Disabled") {
          Write-Host -ForegroundColor White "Starting..." -NoNewline
          $searchSvc | Start-SPEnterpriseSearchServiceInstance
          If (!$?) {
              Throw "  - Could not start the Search Service Instance."
            }
          # Wait
          $searchSvc = Get-SPEnterpriseSearchServiceInstance -Local
          While ($searchSvc.Status -ne "Online") {
            Write-Host -ForegroundColor Cyan "." -NoNewline
            Start-Sleep 1
            $searchSvc = Get-SPEnterpriseSearchServiceInstance -Local
          }
          Write-Host -BackgroundColor Green -ForegroundColor Black $($searchSvc.Status)
        }
        Else {
            Write-Host -ForegroundColor White "Already $($searchSvc.Status)."
        }

        if ($installSyncSvc) {
          Write-Host -ForegroundColor White "  - Checking Search Query and Site Settings Service Instance..." -NoNewline
          $searchQueryAndSiteSettingsService = Get-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance -Local
          If ($searchQueryAndSiteSettingsService.Status -eq "Disabled") {
            Write-Host -ForegroundColor White "Starting..." -NoNewline
            $searchQueryAndSiteSettingsService | Start-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance
            If (!$?) {
                Throw "  - Could not start the Search Query and Site Settings Service Instance."
            }
            Write-Host -ForegroundColor Green $($searchQueryAndSiteSettingsService.Status)
          }
          Else {
              Write-Host -ForegroundColor White "Already $($searchQueryAndSiteSettingsService.Status)."
            }
        }

        Write-Host -ForegroundColor White "  - Checking Search Service Application..." -NoNewline
        $searchApp = Get-SPEnterpriseSearchServiceApplication -Identity $appConfig.Name -ErrorAction SilentlyContinue
        If ($searchApp -eq $null) {
          Write-Host -ForegroundColor White "Creating $($appConfig.Name)..." -NoNewline
          $searchApp = New-SPEnterpriseSearchServiceApplication -Name $appConfig.Name `
            -DatabaseServer $dbServer `
            -DatabaseName $($dbPrefix + $appConfig.Database.Name) `
            -FailoverDatabaseServer $appConfig.FailoverDatabaseServer `
            -ApplicationPool $pool `
            -AdminApplicationPool $adminPool `
            -Partitioned:([bool]::Parse($appConfig.Partitioned))
          If (!$?) {
              Throw "  - An error occurred creating the $($appConfig.Name) application."
            }
          Write-Host -ForegroundColor Green "Done."
        }
        Else {
            Write-Host -ForegroundColor White "Already exists."
        }

        # Update the default Content Access Account
        Update-SearchContentAccessAccount $($appConfig.Name) $searchApp $($appConfig.ContentAccessAccount) $secContentAccessAcctPWD

        # If the index location isn't already set to either the default location or our custom-specified location, set the default location for the search service instance
        if ($indexLocation -ne "$dataDir\Office Server\Applications" -or $indexLocation -ne $searchSvc.DefaultIndexLocation) {
          Write-Host -ForegroundColor White "  - Setting default index location on search service instance..." -NoNewline
          $searchSvc | Set-SPEnterpriseSearchServiceInstance -DefaultIndexLocation $indexLocation -ErrorAction SilentlyContinue
          if ($?) {
              Write-Host -ForegroundColor White "OK."
            }
        }

        # Look for a topology that has components, or is still Inactive, because that's probably our $clone
        $clone = $searchApp.Topologies | Where-Object {$_.ComponentCount -gt 0 -and $_.State -eq "Inactive"} | Select-Object -First 1
        if (!$clone) {
          # Clone the active topology
          Write-Host -ForegroundColor White "  - Cloning the active search topology..." -NoNewline
          $activeTopology = Get-SPEnterpriseSearchTopology -SearchApplication $searchApp -Active
          $clone = New-SPEnterpriseSearchTopology -SearchApplication $searchApp -Clone -SearchTopology $activeTopology
          Write-Host -ForegroundColor White "OK."
        }
        else {
          Write-Host -ForegroundColor White "  - Using existing cloned search topology."
          # Since this clone probably doesn't have all its components added yet, we probably want to keep it if it isn't activated after this pass
          $keepClone = $true
        }
        $activateTopology = $false
        # Check if each search component is already assigned to the current server, then check that it's actually being requested for the current server, then create it as required.
        Write-Host -ForegroundColor White "  - Checking admin component..." -NoNewline
        $adminComponents = $clone.GetComponents() | Where-Object {$_.Name -like "AdminComponent*"}
        If ($installAdminComponent) {
          if (!($adminComponents | Where-Object {MatchComputerName $_.ServerName $env:COMPUTERNAME})) {
            Write-Host -ForegroundColor White "Creating..." -NoNewline
            New-SPEnterpriseSearchAdminComponent -SearchTopology $clone -SearchServiceInstance $searchSvc | Out-Null
            If ($?) {
              Write-Host -ForegroundColor White "OK."
              $componentsModified = $true
            }
          }
          else {Write-Host -ForegroundColor White "Already exists on this server."}
          $adminComponentReady = $true
        }
        else {
          Write-Host -ForegroundColor White "Not requested for this server."
          [array]$componentsToRemove = $adminComponents | Where-Object {MatchComputerName $_.ServerName $env:COMPUTERNAME}
          if ($componentsToRemove) {
            foreach ($componentToRemove in $componentsToRemove) {
              Write-Host -ForegroundColor White "   - Removing component $($componentToRemove.ComponentId)..." -NoNewline
              $componentToRemove | Remove-SPEnterpriseSearchComponent -SearchTopology $clone -Confirm:$false
              If ($?) {
                Write-Host -ForegroundColor White "OK."
                $componentsModified = $true
              }
            }
          }
          $componentsToRemove = $null
        }
        if ($adminComponents) {Write-Host -ForegroundColor White "  - Admin component(s) already exist(s) in the farm."; $adminComponentReady = $true}

        Write-Host -ForegroundColor White "  - Checking content processing component..." -NoNewline
        $contentProcessingComponents = $clone.GetComponents() | Where-Object {$_.Name -like "ContentProcessingComponent*"}
        if ($installContentProcessingComponent) {
          if (!($contentProcessingComponents | Where-Object {MatchComputerName $_.ServerName $env:COMPUTERNAME})) {
            Write-Host -ForegroundColor White "Creating..." -NoNewline
            New-SPEnterpriseSearchContentProcessingComponent -SearchTopology $clone -SearchServiceInstance $searchSvc | Out-Null
            If ($?) {
              Write-Host -ForegroundColor White "OK."
              $componentsModified = $true
            }
          }
          else {
              Write-Host -ForegroundColor White "Already exists on this server."
            }
          $contentProcessingComponentReady = $true
        }
        else {
          Write-Host -ForegroundColor White "Not requested for this server."
          [array]$componentsToRemove = $contentProcessingComponents | Where-Object {MatchComputerName $_.ServerName $env:COMPUTERNAME}
          if ($componentsToRemove) {
            foreach ($componentToRemove in $componentsToRemove) {
              Write-Host -ForegroundColor White "   - Removing component $($componentToRemove.ComponentId)..." -NoNewline
              $componentToRemove | Remove-SPEnterpriseSearchComponent -SearchTopology $clone -Confirm:$false
              If ($?) {
                Write-Host -ForegroundColor White "OK."
                $componentsModified = $true
              }
            }
          }
          $componentsToRemove = $null
        }
        if ($contentProcessingComponents) {Write-Host -ForegroundColor White "  - Content processing component(s) already exist(s) in the farm."; $contentProcessingComponentReady = $true}

        Write-Host -ForegroundColor White "  - Checking analytics processing component..." -NoNewline
        $analyticsProcessingComponents = $clone.GetComponents() | Where-Object {$_.Name -like "AnalyticsProcessingComponent*"}
        if ($installAnalyticsProcessingComponent) {
          if (!($analyticsProcessingComponents | Where-Object {MatchComputerName $_.ServerName $env:COMPUTERNAME})) {
            Write-Host -ForegroundColor White "Creating..." -NoNewline
            New-SPEnterpriseSearchAnalyticsProcessingComponent -SearchTopology $clone -SearchServiceInstance $searchSvc | Out-Null
            If ($?) {
              Write-Host -ForegroundColor White "OK."
              $componentsModified = $true
            }
          }
          else {
              Write-Host -ForegroundColor White "Already exists on this server."
            }
          $analyticsProcessingComponentReady = $true
        }
        else {
          Write-Host -ForegroundColor White "Not requested for this server."
          [array]$componentsToRemove = $analyticsProcessingComponents | Where-Object {MatchComputerName $_.ServerName $env:COMPUTERNAME}
          if ($componentsToRemove) {
            foreach ($componentToRemove in $componentsToRemove) {
              Write-Host -ForegroundColor White "   - Removing component $($componentToRemove.ComponentId)..." -NoNewline
              $componentToRemove | Remove-SPEnterpriseSearchComponent -SearchTopology $clone -Confirm:$false
              If ($?) {
                Write-Host -ForegroundColor White "OK."
                $componentsModified = $true
              }
            }
          }
          $componentsToRemove = $null
        }
        if ($analyticsProcessingComponents) {Write-Host -ForegroundColor White "  - Analytics processing component(s) already exist(s) in the farm."; $analyticsProcessingComponentReady = $true}

        Write-Host -ForegroundColor White "  - Checking crawl component..." -NoNewline
        $crawlComponents = $clone.GetComponents() | Where-Object {$_.Name -like "CrawlComponent*"}
        if ($installCrawlComponent) {
          if (!($crawlComponents | Where-Object {MatchComputerName $_.ServerName $env:COMPUTERNAME})) {
            Write-Host -ForegroundColor White "Creating..." -NoNewline
            New-SPEnterpriseSearchCrawlComponent -SearchTopology $clone -SearchServiceInstance $searchSvc | Out-Null
            If ($?) {
              Write-Host -ForegroundColor White "OK."
              $componentsModified = $true
            }
          }
          else {
              write-Host -ForegroundColor White "Already exists on this server."
            }
          $crawlComponentReady = $true
        }
        else {
          Write-Host -ForegroundColor White "Not requested for this server."
          [array]$componentsToRemove = $crawlComponents | Where-Object {MatchComputerName $_.ServerName $env:COMPUTERNAME}
          if ($componentsToRemove) {
            foreach ($componentToRemove in $componentsToRemove) {
              Write-Host -ForegroundColor White "   - Removing component $($componentToRemove.ComponentId)..." -NoNewline
              $componentToRemove | Remove-SPEnterpriseSearchComponent -SearchTopology $clone -Confirm:$false
              If ($?) {
                Write-Host -ForegroundColor White "OK."
                $componentsModified = $true
              }
            }
          }
          $componentsToRemove = $null
        }
        if ($crawlComponents) {Write-Host -ForegroundColor White "  - Crawl component(s) already exist(s) in the farm."; $crawlComponentReady = $true}

        Write-Host -ForegroundColor White "  - Checking index component..." -NoNewline
        $indexingComponents = $clone.GetComponents() | Where-Object {$_.Name -like "IndexComponent*"}
        if ($installIndexComponent) {
          if (!($indexingComponents | Where-Object {MatchComputerName $_.ServerName $env:COMPUTERNAME})) {
            Write-Host -ForegroundColor White "Creating..." -NoNewline
            # Specify the RootDirectory parameter only if it's different than the default path
            if ($indexLocation -ne "$dataDir\Office Server\Applications") {
                $rootDirectorySwitch = @{RootDirectory = $indexLocation}
            }
            else {
                $rootDirectorySwitch = @{}
            }
            New-SPEnterpriseSearchIndexComponent -SearchTopology $clone -SearchServiceInstance $searchSvc @rootDirectorySwitch | Out-Null
            If ($?) {
              Write-Host -ForegroundColor White "OK."
              $componentsModified = $true
            }
          }
          else {
              Write-Host -ForegroundColor White "Already exists on this server."
            }
          $indexComponentReady = $true
        }
        else {
          Write-Host -ForegroundColor White "Not requested for this server."
          [array]$componentsToRemove = $indexingComponents | Where-Object { MatchComputerName $_.ServerName $env:COMPUTERNAME }
          if ($componentsToRemove) {
            foreach ($componentToRemove in $componentsToRemove) {
              Write-Host -ForegroundColor White "   - Removing component $($componentToRemove.ComponentId)..." -NoNewline
              $componentToRemove | Remove-SPEnterpriseSearchComponent -SearchTopology $clone -Confirm:$false
              If ($?) {
                Write-Host -ForegroundColor White "OK."
                $componentsModified = $true
              }
            }
          }
          $componentsToRemove = $null
        }
        if ($indexingComponents) {Write-Host -ForegroundColor White "  - Index component(s) already exist(s) in the farm."; $indexComponentReady = $true}

        Write-Host -ForegroundColor White "  - Checking query processing component..." -NoNewline
        $queryComponents = $clone.GetComponents() | Where-Object { $_.Name -like "QueryProcessingComponent*" }
        if ($installQueryComponent) {
          if (!($queryComponents | Where-Object { MatchComputerName $_.ServerName $env:COMPUTERNAME })) {
            Write-Host -ForegroundColor White "Creating..." -NoNewline
            New-SPEnterpriseSearchQueryProcessingComponent -SearchTopology $clone -SearchServiceInstance $searchSvc | Out-Null
            If ($?) {
              Write-Host -ForegroundColor White "OK."
              $componentsModified = $true
            }
          }
          else {
              Write-Host -ForegroundColor White "Already exists on this server."
            }
          $queryComponentReady = $true
        }
        else {
          Write-Host -ForegroundColor White "Not requested for this server."
          [array]$componentsToRemove = $queryComponents | Where-Object {MatchComputerName $_.ServerName $env:COMPUTERNAME}
          if ($componentsToRemove) {
            foreach ($componentToRemove in $componentsToRemove) {
              Write-Host -ForegroundColor White "   - Removing component $($componentToRemove.ComponentId)..." -NoNewline
              $componentToRemove | Remove-SPEnterpriseSearchComponent -SearchTopology $clone -Confirm:$false
              If ($?) {
                Write-Host -ForegroundColor White "OK."
                $componentsModified = $true
              }
            }
          }
          $componentsToRemove = $null
        }
        if ($queryComponents) {
            Write-Host -ForegroundColor White "  - Query component(s) already exist(s) in the farm."
            $queryComponentReady = $true
        }

        $searchApp | Get-SPEnterpriseSearchAdministrationComponent | Set-SPEnterpriseSearchAdministrationComponent -SearchServiceInstance $searchSvc

        if ($adminComponentReady -and $contentProcessingComponentReady -and $analyticsProcessingComponentReady -and $indexComponentReady -and $crawlComponentReady -and $queryComponentReady) {$activateTopology = $true}
        # Check if any new search components were added (or if we have a clone with more components than the current active topology) and if we're ready to activate the topology
        if ($componentsModified -or ($clone.ComponentCount -gt $searchApp.ActiveTopology.ComponentCount)) {
          if ($activateTopology) {
            Write-Host -ForegroundColor White "  - Activating Search Topology..." -NoNewline
            $clone.Activate()
            If ($?) {
              Write-Host -ForegroundColor White "OK."
              # Clean up original or previous unsuccessfully-provisioned search topologies
              $inactiveTopologies = $searchApp.Topologies | Where-Object {$_.State -eq "Inactive"}
              if ($inactiveTopologies -ne $null) {
                Write-Host -ForegroundColor White "  - Removing old, inactive search topologies:"
                foreach ($inactiveTopology in $inactiveTopologies) {
                  Write-Host -ForegroundColor White "   -"$inactiveTopology.TopologyId.ToString()
                  $inactiveTopology.Delete()
                }
              }
            }
          }
          else {
            Write-Host -ForegroundColor White "  - Not activating topology yet as there seem to be components still pending."
          }
        }
        elseif ($keepClone -ne $true) {
          # Delete the newly-cloned topology since nothing was done
          # TODO: Check that the search topology is truly complete and there are no more servers to install
          Write-Host -ForegroundColor White "  - Deleting unneeded cloned topology..."
          $clone.Delete()
        }
        # Clean up any empty, inactive topologies
        $emptyTopologies = $searchApp.Topologies | Where-Object {$_.ComponentCount -eq 0 -and $_.State -eq "Inactive"}
        if ($emptyTopologies -ne $null) {
          Write-Host -ForegroundColor White "  - Removing empty and inactive search topologies:"
          foreach ($emptyTopology in $emptyTopologies) {
            Write-Host -ForegroundColor White "  -"$emptyTopology.TopologyId.ToString()
            $emptyTopology.Delete()
          }
        }
        Write-Host -ForegroundColor White "  - Checking search service application proxy..." -NoNewline
        If (!(Get-SPEnterpriseSearchServiceApplicationProxy -Identity $appConfig.Proxy.Name -ErrorAction SilentlyContinue)) {
          Write-Host -ForegroundColor White "Creating..." -NoNewline
          $searchAppProxy = New-SPEnterpriseSearchServiceApplicationProxy -Name $appConfig.Proxy.Name -SearchApplication $appConfig.Name
          If ($?) {
              Write-Host -ForegroundColor White "OK."
            }
        }
        Else {
            Write-Host -ForegroundColor White "Already exists."
        }

        # Check the Search Host Controller Service for a known issue ("stuck on starting")
        Write-Host -ForegroundColor White "  - Checking for stuck Search Host Controller Service (known issue)..."
        $searchHostServices = Get-SPServiceInstance | Where-Object {$_.TypeName -eq "Search Host Controller Service"}
        foreach ($sh in $searchHostServices) {
          Write-Host -ForegroundColor White "   - Server: $($sh.Parent.Address)..." -NoNewline
          if ($sh.Status -eq "Provisioning") {
            Write-Host -ForegroundColor White "Re-provisioning..." -NoNewline
            $sh.Unprovision()
            $sh.Provision($true)
            Write-Host -ForegroundColor Green "Done."
          }
          else {
              Write-Host -ForegroundColor White "OK."
            }
        }

        # Add link to resources list
        AddResourcesLink $appConfig.Name ("searchadministration.aspx?appid=" + $searchApp.Id)

        function SetSearchCenterUrl ($searchCenterURL, $searchApp) {
          Start-Sleep 10 # Wait for stuff to catch up so we don't get a concurrency error
          $searchApp.SearchCenterUrl = $searchCenterURL
          $searchApp.Update()
        }

        If (!([string]::IsNullOrEmpty($appConfig.SearchCenterUrl))) {
          # Set the SP2013+ Search Center URL per http://blogs.technet.com/b/speschka/archive/2012/10/29/how-to-configure-the-global-search-center-url-for-sharepoint-2013-using-powershell.aspx
          Write-Host -ForegroundColor White "  - Setting the Global Search Center URL to $($appConfig.SearchCenterURL)..." -NoNewline
          while ($done -ne $true) {
            try {
              # Get the #searchApp object again to prevent conflicts
              $searchApp = Get-SPEnterpriseSearchServiceApplication -Identity $appConfig.Name
              SetSearchCenterUrl $appConfig.SearchCenterURL.TrimEnd("/") $searchApp
              if ($?) {
                $done = $true
                Write-Host -ForegroundColor White "OK."
              }
            }
            catch {
              Write-Output $_
              if ($_ -like "*update conflict*") {
                Write-Host -ForegroundColor Yellow "  - An update conflict occurred, retrying..."
              }
              else {
                  Write-Output $_
                  $done = $true
                }
            }
          }
        }
        Else {
            Write-Host -ForegroundColor Yellow "  - SearchCenterUrl was not specified, skipping."
        }
        Write-Host -ForegroundColor White " - Search Service Application successfully provisioned."

        WriteLine
      }
    }

    # SLN: Create the network share (will report an error if exist)
    # default to primitives
    $pathToShare = """" + $svcConfig.ShareName + "=" + $indexLocation + """"
    # The path to be shared should exist if the Enterprise Search App creation succeeded earlier
    EnsureFolder $indexLocation
    Write-Host -ForegroundColor White " - Creating network share $pathToShare"
    Start-Process -FilePath net.exe -ArgumentList "share $pathToShare `"/GRANT:WSS_WPG,CHANGE`"" -NoNewWindow -Wait -ErrorAction SilentlyContinue

    # Set the crawl start addresses (including the elusive sps3:// URL required for People Search, if My Sites are provisioned)
    # Updated to include all web apps and host-named site collections, not just main Portal and MySites host
    ForEach ($webAppConfig in $xmlinput.Configuration.WebApplications.WebApplication) {
      if ([string]::IsNullOrEmpty($crawlStartAddresses)) {
        $crawlStartAddresses = $(($webAppConfig.url).TrimEnd("/")) + ":" + $($webAppConfig.Port)
      }
      else {
        $crawlStartAddresses += "," + $(($webAppConfig.url).TrimEnd("/")) + ":" + $($webAppConfig.Port)
      }
    }

    If ($mySiteHostHeaderAndPort) {
      # Need to set the correct sps (People Search) URL protocol in case the web app that hosts My Sites is SSL-bound
      If ($mySiteHostLocation -like "https*") {
          $peopleSearchProtocol = "sps3s://"
        }
      Else {
          $peopleSearchProtocol = "sps3://"
        }
      $crawlStartAddresses += "," + $peopleSearchProtocol + $mySiteHostHeaderAndPort
    }
    Write-Host -ForegroundColor White " - Setting up crawl addresses for default content source..." -NoNewline
    Get-SPEnterpriseSearchServiceApplication | Get-SPEnterpriseSearchCrawlContentSource | Set-SPEnterpriseSearchCrawlContentSource -StartAddresses $crawlStartAddresses
    If ($?) {
        Write-Host -ForegroundColor White "OK."
    }
    if ($env:spVer -ge "15") {
      # Invoke-WebRequest requires PowerShell 3.0 but if we're installing SP2013 and we've gotten this far, we must have v3.0
      # Issue a request to the Farm Search Administration page to avoid a Health Analyzer warning about 'Missing Server Side Dependencies'
      $ca = Get-SPWebApplication -IncludeCentralAdministration | Where-Object {$_.IsAdministrationWebApplication}
      $centralAdminUrl = $ca.Url
      if ($ca.Url -like "http://*" -or $ca.Url -like "*$($env:COMPUTERNAME)*") {
        # If Central Admin uses SSL, only attempt the web request if we're on the same server as Central Admin, otherwise it may throw a certificate error due to our self-signed cert
        try {
          Write-Host -ForegroundColor White " - Requesting searchfarmdashboard.aspx (resolves Health Analyzer error)..."
          $null = Invoke-WebRequest -Uri $centralAdminUrl"searchfarmdashboard.aspx" -UseDefaultCredentials -DisableKeepAlive -UseBasicParsing -ErrorAction SilentlyContinue
        }
        catch {}
      }
    }
    WriteLine
  }
  Else {
    WriteLine
    # Set the service account to something other than Local System to avoid Health Analyzer warnings
    If (!([string]::IsNullOrEmpty($searchServiceAccount.Username)) -and !([string]::IsNullOrEmpty($secSearchServicePassword))) {
      # Use the values for Search Service account and password, if they've been defined
      $username = $searchServiceAccount.Username
      $password = $secSearchServicePassword
    }
    Else {
      $spservice = Get-SPManagedAccountXML $xmlinput -CommonName "spservice"
      $username = $spservice.username
      $password = ConvertTo-SecureString "$($spservice.password)" -AsPlaintext -Force
    }
    Write-Host -ForegroundColor White " - Applying service account $username to Search Service..."
    Get-SPEnterpriseSearchService | Set-SPEnterpriseSearchService -ServiceAccount $username -ServicePassword $password
    If (!$?) {
        Write-Error " - An error occurred setting the Search Service account!"
    }
    WriteLine
  }
}