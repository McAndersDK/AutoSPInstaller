# ===================================================================================
# Func: ConfigureObjectCache
# Desc: Applies the portal super accounts to the object cache for a web application
# ===================================================================================
Function ConfigureObjectCache([System.Xml.XmlElement]$webApp) {
  Try {
      $url = ($webApp.Url).TrimEnd("/") + ":" + $webApp.Port
      $wa = Get-SPWebApplication | Where-Object {$_.DisplayName -eq $webApp.Name}
      $superUserAcc = $xmlinput.Configuration.Farm.ObjectCacheAccounts.SuperUser
      $superReaderAcc = $xmlinput.Configuration.Farm.ObjectCacheAccounts.SuperReader
      # If the web app is using Claims auth, change the user accounts to the proper syntax
      If ($wa.UseClaimsAuthentication -eq $true) {
          $superUserAcc = 'i:0#.w|' + $superUserAcc
          $superReaderAcc = 'i:0#.w|' + $superReaderAcc
      }
      Write-Host -ForegroundColor White " - Applying object cache accounts to `"$url`"..."
      $wa.Properties["portalsuperuseraccount"] = $superUserAcc
      Set-WebAppUserPolicy $wa $superUserAcc "Super User (Object Cache)" "Full Control"
      $wa.Properties["portalsuperreaderaccount"] = $superReaderAcc
      Set-WebAppUserPolicy $wa $superReaderAcc "Super Reader (Object Cache)" "Full Read"
      $wa.Update()
      Write-Host -ForegroundColor White " - Done applying object cache accounts to `"$url`""
  }
  Catch {
      $_
      Write-Warning "An error occurred applying object cache to `"$url`""
      Pause "exit"
  }
}