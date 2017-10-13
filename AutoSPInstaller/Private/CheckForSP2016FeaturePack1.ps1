# ====================================================================================
# Func: CheckForSP2016FeaturePack1
# Desc: Returns $true if the SharePoint 2016 farm build number or SharePoint DLL indicates that Feature Pack 1 or greater is installed: otherwise returns $false
# Desc: Helps to determine whether certain new/updated cmdlets and MinRoles are available
# ====================================================================================
function CheckForSP2016FeaturePack1 {
  # Try to get the version of the farm first
  try {
      # Get-SPFarm lately seems to ignore -ErrorAction SilentlyContinue so we have to put it in a try-catch block
      $farm = Get-SPFarm -ErrorAction SilentlyContinue
  }
  catch {
      # Set $farm to null
      $farm = $null
  }
  $build = $farm.BuildVersion.Build
  If (!($build)) {
      # Get the ProductVersion of a SharePoint DLL instead, since the farm doesn't seem to exist yet
      $spProdVer = (Get-Command $env:CommonProgramFiles"\Microsoft Shared\Web Server Extensions\$env:spVer\isapi\microsoft.sharepoint.portal.dll" -ErrorAction SilentlyContinue).FileVersionInfo.ProductVersion
      $null, $null, [int]$build, $null = $spProdVer -split "\."
  }
  If ($build -ge 4453) {
      # SP2016 FP1
      return $true
  }
}