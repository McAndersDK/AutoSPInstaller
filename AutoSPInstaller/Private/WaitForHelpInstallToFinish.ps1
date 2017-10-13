# ===================================================================================
# Func: WaitForHelpInstallToFinish
# Desc: Waits for the Help Collection timer job to complete before proceeding, in order to avoid concurrency errors
# From: Adapted from a function submitted by CodePlex user jwthompson98
# ===================================================================================
Function WaitForHelpInstallToFinish {
  Write-Host -ForegroundColor Cyan "  - Waiting for Help Collection Installation timer job..." -NoNewline
  # Wait for the timer job to start
  Do {
      Write-Host -ForegroundColor Cyan "." -NoNewline
      Start-Sleep -Seconds 1
  }
  Until
  (
      (Get-SPFarm).TimerService.RunningJobs | Where-Object {$_.JobDefinition.TypeName -eq "Microsoft.SharePoint.Help.HelpCollectionInstallerJob"}
  )
  Write-Host -ForegroundColor Green "Started."
  Write-Host -ForegroundColor Cyan "  - Waiting for Help Collection Installation timer job to complete: " -NoNewline
  # Monitor the timer job and display progress
  $helpJob = (Get-SPFarm).TimerService.RunningJobs | Where-Object {$_.JobDefinition.TypeName -eq "Microsoft.SharePoint.Help.HelpCollectionInstallerJob"} | Sort-Object StartTime | Select-Object -Last 1
  While ($helpJob -ne $null) {
      Write-Host -ForegroundColor White "$($helpJob.PercentageDone)%" -NoNewline
      Start-Sleep -Milliseconds 250
      for ($i = 0; $i -lt 3; $i++) {
          Write-Host -ForegroundColor Cyan "." -NoNewline
          Start-Sleep -Milliseconds 250
      }
      $backspaceCount = (($helpJob.PercentageDone).ToString()).Length + 3
      for ($count = 0; $count -le $backspaceCount; $count++) {Write-Host "`b `b" -NoNewline}
      $helpJob = (Get-SPFarm).TimerService.RunningJobs | Where-Object {$_.JobDefinition.TypeName -eq "Microsoft.SharePoint.Help.HelpCollectionInstallerJob"} | Sort-Object StartTime | Select-Object -Last 1
  }
  Write-Host -ForegroundColor White "OK."
}