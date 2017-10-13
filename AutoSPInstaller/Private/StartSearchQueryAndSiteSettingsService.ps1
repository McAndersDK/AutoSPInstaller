Function StartSearchQueryAndSiteSettingsService {
  If (ShouldIProvision $xmlinput.Configuration.Farm.Services.SearchQueryAndSiteSettingsService -eq $true) {
      WriteLine
      Try {
          # Get the service instance
          $searchQueryAndSiteSettingsServices = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.Office.Server.Search.Administration.SearchQueryAndSiteSettingsServiceInstance"}
          $searchQueryAndSiteSettingsService = $searchQueryAndSiteSettingsServices | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
          If (-not $?) { Throw " - Failed to find Search Query and Site Settings service instance" }
          # Start Service instance
          Write-Host -ForegroundColor White " - Starting Search Query and Site Settings Service Instance..."
          If ($searchQueryAndSiteSettingsService.Status -eq "Disabled") {
              $searchQueryAndSiteSettingsService.Provision()
              If (-not $?) { Throw " - Failed to start Search Query and Site Settings service instance" }
              # Wait
              Write-Host -ForegroundColor Cyan " - Waiting for Search Query and Site Settings service..." -NoNewline
              While ($searchQueryAndSiteSettingsService.Status -ne "Online") {
                  Write-Host -ForegroundColor Cyan "." -NoNewline
                  Start-Sleep 1
                  $searchQueryAndSiteSettingsServices = Get-SPServiceInstance | Where-Object {$_.GetType().ToString() -eq "Microsoft.Office.Server.Search.Administration.SearchQueryAndSiteSettingsServiceInstance"}
                  $searchQueryAndSiteSettingsService = $searchQueryAndSiteSettingsServices | Where-Object {MatchComputerName $_.Server.Address $env:COMPUTERNAME}
              }
              Write-Host -BackgroundColor Green -ForegroundColor Black $($searchQueryAndSiteSettingsService.Status)
          }
          Else {Write-Host -ForegroundColor White " - Search Query and Site Settings Service already started."}
      }
      Catch {
          Write-Output $_
          Throw " - Error provisioning Search Query and Site Settings Service"
      }
      WriteLine
  }
}