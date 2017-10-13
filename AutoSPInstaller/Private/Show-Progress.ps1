# ====================================================================================
# Func: Show-Progress
# Desc: Shows a row of dots to let us know that $process is still running
# From: Brian Lalancette, 2012
# ====================================================================================
Function Show-Progress ($process, $color, $interval) {
  While (Get-Process -Name $process -ErrorAction SilentlyContinue) {
      Write-Host -ForegroundColor $color "." -NoNewline
      Start-Sleep $interval
  }
  Write-Host -ForegroundColor Green "Done."
}