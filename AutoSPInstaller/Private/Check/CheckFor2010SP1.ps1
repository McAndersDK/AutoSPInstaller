# ====================================================================================
# Func: CheckFor2010SP1
# Desc: Returns $true if the SharePoint 2010 farm build number or SharePoint DLL is at Service Pack 1 (6029) or greater (or if slipstreamed SP1 is detected); otherwise returns $false
# Desc: Helps to determine whether certain new/updated cmdlets are available
# ====================================================================================
Function CheckFor2010SP1 {
  # First off, if this is SP2013 or higher, we're good
  if ($env:spVer -ge "15") {
      return $true
  }
  # Otherwise, if it's 2010, run some additional checks
  elseif (Get-Command Get-SPFarm -ErrorAction SilentlyContinue) {
      # Try to get the version of the farm first
      $build = (Get-SPFarm).BuildVersion.Build
      If (!($build)) {
          # Get the ProductVersion of a SharePoint DLL instead, since the farm doesn't seem to exist yet {
          $spProdVer = (Get-Command $env:CommonProgramFiles"\Microsoft Shared\Web Server Extensions\$env:spVer\isapi\microsoft.sharepoint.portal.dll" -ErrorAction SilentlyContinue).FileVersionInfo.ProductVersion
          $null, $null, [int]$build, $null = $spProdVer -split "\."
      }
      If ($build -ge 6029) {
          # SP2010 SP1
          return $true
      }
  }
  # SharePoint probably isn't installed yet, so try to see if we have slipstreamed SP1 in the \Updates folder at least...
  elseIf (Get-Item "$env:SPbits\Updates\oserversp1-x-none.msp" -ErrorAction SilentlyContinue) {
      return $true
  }
  else {
      return $false
  }
}