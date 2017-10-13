# ====================================================================================
# Func: CheckFor2013SP1
# Desc: Returns $true if the SharePoint 2013 farm build number or SharePoint prerequisiteinstaller.exe is at Service Pack 1 (4569 or 4567, respectively) or greater; otherwise returns $false
# ====================================================================================
Function CheckFor2013SP1 {
  if ($env:spVer -eq "15") {
      If (Get-Command Get-SPFarm -ErrorAction SilentlyContinue) {
          # Try to get the version of the farm first
          $build = (Get-SPFarm -ErrorAction SilentlyContinue).BuildVersion.Build
          If (!($build)) {
              # Get the ProductVersion of a SharePoint DLL instead, since the farm doesn't seem to exist yet
              $spProdVer = (Get-Command $env:CommonProgramFiles"\Microsoft Shared\Web Server Extensions\$env:spVer\isapi\microsoft.sharepoint.portal.dll").FileVersionInfo.ProductVersion
              $null, $null, [int]$build, $null = $spProdVer -split "\."
          }
          If ($build -ge 4569) {
              # SP2013 SP1
              Return $true
          }
      }
      # SharePoint probably isn't installed yet, so try to determine version of prerequisiteinstaller.exe...
      ElseIf (Get-Item "$env:SPbits\prerequisiteinstaller.exe" -ErrorAction SilentlyContinue) {
          $preReqInstallerVer = (Get-Command "$env:SPbits\prerequisiteinstaller.exe").FileVersionInfo.ProductVersion
          $null, $null, [int]$build, $null = $preReqInstallerVer -split "\."
          If ($build -ge 4567) {
              # SP2013 SP1
              Return $true
          }
      }
      Else {
          Return $false
      }
  }
  elseif ($env:spVer -ge "16") {
      Return $true
  }
  else {
      Return $false
  }
}