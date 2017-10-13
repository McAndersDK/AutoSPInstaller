# ===================================================================================
# Func: CreateWebApplications
# Desc: Create and  configure the required web applications
# ===================================================================================
Function CreateWebApplications([xml]$xmlinput) {
  WriteLine
  If ($xmlinput.Configuration.WebApplications) {
      Write-Host -ForegroundColor White " - Creating web applications..."
      ForEach ($webApp in $xmlinput.Configuration.WebApplications.WebApplication) {
          CreateWebApp $webApp
          ConfigureOnlineWebPartCatalog $webApp
          Add-LocalIntranetURL ($webApp.URL).TrimEnd("/")
          WriteLine
      }
      # Updated so that we don't add URLs to the local hosts file of a server that's not been specified to run the Foundation Web Application service, or the Search MinRole
      If ($xmlinput.Configuration.WebApplications.AddURLsToHOSTS -eq $true -and !(ShouldIProvision ($xmlinput.Configuration.Farm.ServerRoles.Search)) -and !(($xmlinput.Configuration.Farm.Services.SelectSingleNode("FoundationWebApplication")) -and !(ShouldIProvision $xmlinput.Configuration.Farm.Services.FoundationWebApplication -eq $true)))
      {AddToHOSTS}
  }
  WriteLine
}