# ====================================================================================
# Func: Run-HealthAnalyzerJobs
# Desc: Runs all Health Analyzer Timer Jobs Immediately
# From: http://www.sharepointconfig.com/2011/01/instant-sharepoint-health-analysis/
# ====================================================================================
Function Run-HealthAnalyzerJobs {
  $healthJobs = Get-SPTimerJob | Where-Object {$_.Name -match "health-analysis-job"}
  Write-Host -ForegroundColor White " - Running all Health Analyzer jobs..."
  ForEach ($job in $healthJobs) {
      $job.RunNow()
  }
}