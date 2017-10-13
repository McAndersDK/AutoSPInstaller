# ===================================================================================
# Func: Pause
# Desc: Wait for user to press a key - normally used after an error has occured or input is required
# ===================================================================================
Function Pause($action, $key) {
  # From http://www.microsoft.com/technet/scriptcenter/resources/pstips/jan08/pstip0118.mspx
  if ($key -eq "any" -or ([string]::IsNullOrEmpty($key))) {
      $actionString = "Press any key to $action..."
      if (-not $unattended) {
          Write-Host $actionString
          $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      }
      else {
          Write-Host "Skipping pause due to -unattended switch: $actionString"
      }
  }
  else {
      $actionString = "Enter `"$key`" to $action"
      $continue = Read-Host -Prompt $actionString
      if ($continue -ne $key) {pause $action $key}

  }
}