# ===================================================================================
# Func: CreateMetadataServiceApp
# Desc: Managed Metadata Service Application
# ===================================================================================
Function CreateMetadataServiceApp([xml]$xmlinput) {
  If ((ShouldIProvision $xmlinput.Configuration.ServiceApps.ManagedMetadataServiceApp -eq $true) -and (Get-Command -Name New-SPMetadataServiceApplication -ErrorAction SilentlyContinue)) {
      WriteLine
      Try {
          Get-MajorVersionNumber $xmlinput
          $dbPrefix = Get-DBPrefix $xmlinput
          $metaDataDB = $dbPrefix + $xmlinput.Configuration.ServiceApps.ManagedMetadataServiceApp.Database.Name
          $dbServer = $xmlinput.Configuration.ServiceApps.ManagedMetadataServiceApp.Database.DBServer
          # If we haven't specified a DB Server then just use the default used by the Farm
          If ([string]::IsNullOrEmpty($dbServer)) {
              $dbServer = $xmlinput.Configuration.Farm.Database.DBServer
          }
          $farmAcct = $xmlinput.Configuration.Farm.Account.Username
          $metadataServiceName = $xmlinput.Configuration.ServiceApps.ManagedMetadataServiceApp.Name
          $metadataServiceProxyName = $xmlinput.Configuration.ServiceApps.ManagedMetadataServiceApp.ProxyName
          If ($metadataServiceName -eq $null) {$metadataServiceName = "Metadata Service Application"}
          If ($metadataServiceProxyName -eq $null) {$metadataServiceProxyName = $metadataServiceName}
          Write-Host -ForegroundColor White " - Provisioning Managed Metadata Service Application"
          $applicationPool = Get-HostedServicesAppPool $xmlinput
          Write-Host -ForegroundColor White " - Starting Managed Metadata Service:"
          # Get the service instance
          $metadataServiceInstances = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.SharePoint.Taxonomy.MetadataWebServiceInstance"}
          $metadataServiceInstance = $metadataServiceInstances | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
          If (-not $?) { Throw " - Failed to find Metadata service instance" }
          # Start Service instances
          If ($metadataServiceInstance.Status -eq "Disabled") {
              Write-Host -ForegroundColor White " - Starting Metadata Service Instance..."
              $metadataServiceInstance.Provision()
              If (-not $?) { Throw " - Failed to start Metadata service instance" }
              # Wait
              Write-Host -ForegroundColor Cyan " - Waiting for Metadata service..." -NoNewline
              While ($metadataServiceInstance.Status -ne "Online") {
                  Write-Host -ForegroundColor Cyan "." -NoNewline
                  Start-Sleep 1
                  $metadataServiceInstances = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.SharePoint.Taxonomy.MetadataWebServiceInstance"}
                  $metadataServiceInstance = $metadataServiceInstances | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
              }
              Write-Host -BackgroundColor Green -ForegroundColor Black ($metadataServiceInstance.Status)
          }
          Else {Write-Host -ForegroundColor White " - Managed Metadata Service already started."}

          $metaDataServiceApp = Get-SPServiceApplication | Where-Object {$_.GetType().ToString() -eq "Microsoft.SharePoint.Taxonomy.MetadataWebServiceApplication"}
          # Create a Metadata Service Application if we don't already have one
          If ($metaDataServiceApp -eq $null) {
              # Create Service App
              Write-Host -ForegroundColor White " - Creating Metadata Service Application..."
              $metaDataServiceApp = New-SPMetadataServiceApplication -Name $metadataServiceName -ApplicationPool $applicationPool -DatabaseServer $dbServer -DatabaseName $metaDataDB
              If (-not $?) { Throw " - Failed to create Metadata Service Application" }
          }
          Else {
              Write-Host -ForegroundColor White " - Managed Metadata Service Application already provisioned."
          }
          $metaDataServiceAppProxy = Get-SPServiceApplicationProxy | Where-Object {$_.GetType().ToString() -eq "Microsoft.SharePoint.Taxonomy.MetadataWebServiceApplicationProxy"}
          if ($metaDataServiceAppProxy -eq $null) {
              # create proxy
              Write-Host -ForegroundColor White " - Creating Metadata Service Application Proxy..."
              $metaDataServiceAppProxy = New-SPMetadataServiceApplicationProxy -Name $metadataServiceProxyName -ServiceApplication $metaDataServiceApp -DefaultProxyGroup -ContentTypePushdownEnabled -DefaultKeywordTaxonomy -DefaultSiteCollectionTaxonomy
              If (-not $?) { Throw " - Failed to create Metadata Service Application Proxy" }
          }
          else {
              Write-Host -ForegroundColor White " - Managed Metadata Service Application Proxy already provisioned."
          }
          if ($metaDataServiceApp -or $metaDataServiceAppProxy) {
              # Added to enable Metadata Service Navigation for SP2013, per http://www.toddklindt.com/blog/Lists/Posts/Post.aspx?ID=354
              If ($env:spVer -eq "15") {
                  If ($metaDataServiceAppProxy.Properties.IsDefaultSiteCollectionTaxonomy -ne $true) {
                      Write-Host -ForegroundColor White " - Configuring Metadata Service Application Proxy..."
                      $metaDataServiceAppProxy.Properties.IsDefaultSiteCollectionTaxonomy = $true
                      $metaDataServiceAppProxy.Update()
                  }
              }
              Write-Host -ForegroundColor White " - Granting rights to Metadata Service Application:"
              # Get ID of "Managed Metadata Service"
              $metadataServiceAppToSecure = Get-SPServiceApplication | Where-Object {$_.GetType().ToString() -eq "Microsoft.SharePoint.Taxonomy.MetadataWebServiceApplication"}
              $metadataServiceAppIDToSecure = $metadataServiceAppToSecure.Id
              # Create a variable that contains the list of administrators for the service application
              $metadataServiceAppSecurity = Get-SPServiceApplicationSecurity $metadataServiceAppIDToSecure
              ForEach ($account in ($xmlinput.Configuration.Farm.ManagedAccounts.ManagedAccount)) {
                  # Create a variable that contains the claims principal for the service accounts
                  Write-Host -ForegroundColor White "  - $($account.username)..."
                  $accountPrincipal = New-SPClaimsPrincipal -Identity $account.username -IdentityType WindowsSamAccountName
                  # Give permissions to the claims principal you just created
                  Grant-SPObjectSecurity $metadataServiceAppSecurity -Principal $accountPrincipal -Rights "Full Access to Term Store"
              }
              # Apply the changes to the Metadata Service application
              Set-SPServiceApplicationSecurity $metadataServiceAppIDToSecure -objectSecurity $metadataServiceAppSecurity
              Write-Host -ForegroundColor White " - Done granting rights."
              Write-Host -ForegroundColor White " - Done creating Managed Metadata Service Application."
          }
      }
      Catch {
          Write-Output $_
          Throw " - Error provisioning the Managed Metadata Service Application"
      }
      WriteLine
  }
}