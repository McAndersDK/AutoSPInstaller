# ===================================================================================
# Func: ConfigureOnlineWebPartCatalog
# Desc: Enables / Disables access to the online web parts catalog for each web application
# ===================================================================================
Function ConfigureOnlineWebPartCatalog([System.Xml.XmlElement]$webApp) {
  If ($webapp.UseOnlineWebPartCatalog -ne "") {
      $url = ($webApp.Url).TrimEnd("/") + ":" + $webApp.Port
      If ($url -like "*localhost*") {$url = $url -replace "localhost", "$env:COMPUTERNAME"}
      Write-Host -ForegroundColor White " - Setting online webpart catalog access for `"$url`""

      $wa = Get-SPWebApplication | Where-Object {$_.DisplayName -eq $webApp.Name}
      If ($webapp.UseOnlineWebPartCatalog -eq "True") {
          $wa.AllowAccessToWebpartCatalog = $true
      }
      Else {
          $wa.AllowAccessToWebpartCatalog = $false
      }
      $wa.Update()
  }
}