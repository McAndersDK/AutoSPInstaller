# ====================================================================================
# Func: ConfigureTracing
# Desc: Updates the service account for SPTraceV4 (SharePoint Foundation (Help) Search)
# ====================================================================================

Function ConfigureTracing ([xml]$xmlinput) {
  # Make sure a credential deployment job doesn't already exist
  if (!(Get-SPTimerJob -Identity "windows-service-credentials-SPTraceV4")) {
      WriteLine
      $spservice = Get-SPManagedAccountXML $xmlinput -CommonName "spservice"
      $spTraceV4 = (Get-SPFarm).Services | Where-Object {$_.Name -eq "SPTraceV4"}
      $appPoolAcctDomain, $appPoolAcctUser = $spservice.username -Split "\\"
      Write-Host -ForegroundColor White " - Applying service account $($spservice.username) to service SPTraceV4..."
      #Add to Performance Monitor Users group
      Write-Host -ForegroundColor White " - Adding $($spservice.username) to local Performance Monitor Users group..."
      Try {
          ([ADSI]"WinNT://$env:COMPUTERNAME/Performance Monitor Users,group").Add("WinNT://$appPoolAcctDomain/$appPoolAcctUser")
          If (-not $?) {Throw}
      }
      Catch {
          Write-Host -ForegroundColor White " - $($spservice.username) is already a member of Performance Monitor Users."
      }
      #Add all managed accounts to Performance Log Users group
      foreach ($managedAccount in (Get-SPManagedAccount)) {
          $appPoolAcctDomain, $appPoolAcctUser = $managedAccount.UserName -Split "\\"
          Write-Host -ForegroundColor White " - Adding $($managedAccount.UserName) to local Performance Log Users group..."
          Try {
              ([ADSI]"WinNT://$env:COMPUTERNAME/Performance Log Users,group").Add("WinNT://$appPoolAcctDomain/$appPoolAcctUser")
              If (-not $?) {Throw}
          }
          Catch {
              Write-Host -ForegroundColor White "  - $($managedAccount.UserName) is already a member of Performance Log Users."
          }
      }
      Try {
          UpdateProcessIdentity $spTraceV4
      }
      Catch {
          Write-Output $_
          Throw " - An error occurred updating the service account for service SPTraceV4."
      }
      # Restart SPTraceV4 service so changes to group memberships above can take effect
      Write-Host -ForegroundColor White " - Restarting service SPTraceV4..."
      Restart-Service -Name "SPTraceV4" -Force
      WriteLine
  }
  else {
      Write-Warning "Timer job `"windows-service-credentials-SPTraceV4`" already exists."
      Write-Host -ForegroundColor Yellow "Check that $($spservice.username) is a member of the Performance Log Users and Performance Monitor Users local groups once install completes."
  }
}