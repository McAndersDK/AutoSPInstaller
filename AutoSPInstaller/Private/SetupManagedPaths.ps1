# ===================================================================================
# Func: SetupManagedPaths
# Desc: Sets up managed paths for a given web application
# ===================================================================================
Function SetupManagedPaths([System.Xml.XmlElement]$webApp) {
  $url = ($webApp.Url).TrimEnd("/") + ":" + $webApp.Port
  If ($url -like "*localhost*") {$url = $url -replace "localhost", "$env:COMPUTERNAME"}
  Write-Host -ForegroundColor White " - Setting up managed paths for `"$url`""

  If ($webApp.ManagedPaths) {
      ForEach ($managedPath in $webApp.ManagedPaths.ManagedPath) {
          If ($managedPath.Delete -eq "true") {
              Write-Host -ForegroundColor White "  - Deleting managed path `"$($managedPath.RelativeUrl)`" at `"$url`""
              Remove-SPManagedPath -Identity $managedPath.RelativeUrl -WebApplication $url -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
          }
          Else {
              If ($managedPath.Explicit -eq "true") {
                  Write-Host -ForegroundColor White "  - Setting up explicit managed path `"$($managedPath.RelativeUrl)`" at `"$url`" and HNSCs..."
                  New-SPManagedPath -RelativeUrl $managedPath.RelativeUrl -WebApplication $url -Explicit -ErrorAction SilentlyContinue | Out-Null
                  # Let's create it for host-named site collections too, in case we have any
                  New-SPManagedPath -RelativeUrl $managedPath.RelativeUrl -HostHeader -Explicit -ErrorAction SilentlyContinue | Out-Null
              }
              Else {
                  Write-Host -ForegroundColor White "  - Setting up managed path `"$($managedPath.RelativeUrl)`" at `"$url`" and HNSCs..."
                  New-SPManagedPath -RelativeUrl $managedPath.RelativeUrl -WebApplication $url -ErrorAction SilentlyContinue | Out-Null
                  # Let's create it for host-named site collections too, in case we have any
                  New-SPManagedPath -RelativeUrl $managedPath.RelativeUrl -HostHeader -ErrorAction SilentlyContinue | Out-Null
              }
          }
      }
  }

  Write-Host -ForegroundColor White " - Done setting up managed paths at `"$url`""
}