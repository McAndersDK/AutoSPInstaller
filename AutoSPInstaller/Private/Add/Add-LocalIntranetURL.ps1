# ====================================================================================
# Func: Add-LocalIntranetURL
# Desc: Adds a URL to the local Intranet zone (Internet Control Panel) to allow pass-through authentication in Internet Explorer (avoid prompts)
# ====================================================================================
Function Add-LocalIntranetURL ($url) {
  If (($url -like "*.*") -and (($webApp.AddURLToLocalIntranetZone) -eq $true)) {
      # Strip out any protocol value
      $url = $url -replace "http://", "" -replace "https://", ""
      $splitURL = $url -split "\."
      # Thanks to CodePlex user Eulenspiegel for the updates $urlDomain syntax (https://autospinstaller.codeplex.com/workitem/20486)
      $urlDomain = $url.Substring($splitURL[0].Length + 1)
      Write-Host -ForegroundColor White " - Adding *.$urlDomain to local Intranet security zone..."
      New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains" -Name $urlDomain -ItemType Leaf -Force | Out-Null
      New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\$urlDomain" -Name '*' -value "1" -PropertyType dword -Force | Out-Null
  }
}