function Set-ProxyGroupsMembership([System.Xml.XmlElement[]]$groups, [Microsoft.SharePoint.Administration.SPServiceApplicationProxy[]]$inputObject) {
  begin {}
  process {
      $proxy = $_
      # Clear any existing proxy group assignments
      Get-SPServiceApplicationProxyGroup | Where-Object {$_.Proxies -contains $proxy} | ForEach-Object {
          $proxyGroupName = $_.Name
          If ([string]::IsNullOrEmpty($proxyGroupName)) { $proxyGroupName = "Default" }
          $group = $null
          [bool]$matchFound = $false
          ForEach ($g in $groups) {
              $group = $g.ProxyGroup
              If ($group -eq $proxyGroupName) {
                  $matchFound = $true
                  break
              }
          }
          If (!$matchFound) {
              Write-Host -ForegroundColor White " - Removing ""$($proxy.DisplayName)"" from ""$proxyGroupName"""
              $_ | Remove-SPServiceApplicationProxyGroupMember -Member $proxy -Confirm:$false -ErrorAction SilentlyContinue
          }
      }
      ForEach ($g in $groups) {
          $group = $g.ProxyGroup
          $pg = $null
          If ($group -eq "Default" -or [string]::IsNullOrEmpty($group)) {
              $pg = [Microsoft.SharePoint.Administration.SPServiceApplicationProxyGroup]::Default
          }
          Else {
              $pg = Get-SPServiceApplicationProxyGroup $group -ErrorAction SilentlyContinue -ErrorVariable err
              If ($pg -eq $null) {
                  $pg = New-SPServiceApplicationProxyGroup -Name $name
              }
          }
          $pg = $pg | Where-Object {$_.Proxies -notcontains $proxy}
          If ($pg -ne $null) {
              Write-Host -ForegroundColor White " - Adding ""$($proxy.DisplayName)"" to ""$($pg.DisplayName)"""
              $pg | Add-SPServiceApplicationProxyGroupMember -Member $proxy | Out-Null
          }
      }
  }
  end {}
}