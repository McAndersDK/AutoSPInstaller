# ===================================================================================
# Func: InstallSpecifiedUpdate
# Desc: Installs a specified SharePoint Updates (CU or Service Pack)
# ===================================================================================
Function InstallSpecifiedUpdate ($updateFile, $updateName) {
  # Get the file name only, in case $updateFile includes part of a path (e.g. is in a subfolder)
  $splitUpdateFile = Split-Path -Path $updateFile -Leaf
  Write-Host -ForegroundColor Cyan "  - Installing SP$spYear $updateName $splitUpdateFile..." -NoNewline
  $startTime = Get-Date
  Start-Process -FilePath "$bits\$spYear\Updates\$updateFile" -ArgumentList "/passive /norestart"
  Show-Progress -Process $($splitUpdateFile -replace ".exe", "") -Color Cyan -Interval 5
  $delta, $null = (New-TimeSpan -Start $startTime -End (Get-Date)).ToString() -split "\."
  $oPatchInstallLog = Get-ChildItem -Path (Get-Item $env:TEMP).FullName | Where-Object {$_.Name -like "opatchinstall*.log"} | Sort-Object -Descending -Property "LastWriteTime" | Select-Object -first 1
  # Get install result from log
  $oPatchInstallResultMessage = $oPatchInstallLog | Select-String -SimpleMatch -Pattern "OPatchInstall: Property 'SYS.PROC.RESULT' value" | Select-Object -Last 1
  If (!($oPatchInstallResultMessage -like "*value '0'*")) {
      # Anything other than 0 means unsuccessful but that's not necessarily a bad thing
      $null, $oPatchInstallResultCode = $oPatchInstallResultMessage.Line -split "OPatchInstall: Property 'SYS.PROC.RESULT' value '"
      $oPatchInstallResultCode = $oPatchInstallResultCode.TrimEnd("'")
      # OPatchInstall: Property 'SYS.PROC.RESULT' value '17028' means the patch was not needed or installed product was newer
      if ($oPatchInstallResultCode -eq "17028") {Write-Host -ForegroundColor White "   - Patch not required; installed product is same or newer."}
      elseif ($oPatchInstallResultCode -eq "17031") {
          Write-Warning "Error 17031: Detection: Invalid baseline"
          Write-Warning "A baseline patch (e.g. March 2013 PU for SP2013, SP1 for SP2010) is missing!"
          Write-Host -ForegroundColor Yellow "   - Either slipstream the missing patch first, or include the patch package in the ..\$spYear\Updates folder."
          Pause "continue"
      }
      else {Write-Host "  - $($oPatchInstallResultCodes.$oPatchInstallResultCode)"}
  }
  Write-Host -ForegroundColor White "  - $updateName install completed in $delta."
}