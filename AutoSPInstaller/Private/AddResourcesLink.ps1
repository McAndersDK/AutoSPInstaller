#region Shortcuts
# ====================================================================================
# Func: AddResourcesLink
# Desc: Adds an item to the Resources list shown on the Central Admin homepage
#       $url should be relative to the central admin home page and should not include the leading /
# ====================================================================================
Function AddResourcesLink([string]$title, [string]$url) {
  $centraladminapp = Get-SPWebApplication -IncludeCentralAdministration | Where-Object {$_.IsAdministrationWebApplication}
  $centraladminurl = $centraladminapp.Url
  $centraladmin = (Get-SPSite $centraladminurl)

  $item = $centraladmin.RootWeb.Lists["Resources"].Items | Where-Object { $_["URL"] -match ".*, $title" }
  If ($item -eq $null ) {
      $item = $centraladmin.RootWeb.Lists["Resources"].Items.Add();
  }

  $url = $centraladminurl + $url + ", $title";
  $item["URL"] = $url;
  $item.Update();
}