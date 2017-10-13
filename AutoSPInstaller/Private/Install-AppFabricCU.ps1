# ===================================================================================
# Func: Install-AppFabricCU
# Desc: Attempts to install a recently-released cumulative update for AppFabric, if found in $env:SPbits\PrerequisiteInstallerFiles
# ===================================================================================
function Install-AppFabricCU {
  WriteLine
  # Create a hash table with major version to product year mappings
  $spYears = @{"14" = "2010"; "15" = "2013"; "16" = "2016"}
  $spYear = $spYears.$env:spVer
  [hashtable]$updates = @{"CU7" = "AppFabric-KB3092423-x64-ENU.exe";
      "CU6"                     = "AppFabric-KB3042099-x64-ENU.exe";
      "CU5"                     = "AppFabric1.1-KB2932678-x64-ENU.exe";
      "CU4"                     = "AppFabric1.1-RTM-KB2800726-x64-ENU.exe"
  }
  $installSucceeded = $false
  Write-Host -ForegroundColor White " - Checking for AppFabric CU4 or newer..."
  $appFabricKB = (((Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Updates\AppFabric 1.1 for Windows Server\KB2800726" -Name "IsInstalled" -ErrorAction SilentlyContinue).IsInstalled -eq 1) -or `
      ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Updates\AppFabric 1.1 for Windows Server\KB2932678" -Name "IsInstalled" -ErrorAction SilentlyContinue).IsInstalled -eq 1) -or
      ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Updates\AppFabric 1.1 for Windows Server\KB3042099" -Name "IsInstalled" -ErrorAction SilentlyContinue).IsInstalled -eq 1) -or
      ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Updates\AppFabric 1.1 for Windows Server\KB3092423" -Name "IsInstalled" -ErrorAction SilentlyContinue).IsInstalled -eq 1))
  if (!$appFabricKB) {
      # Try to install the AppFabric update if it isn't detected
      foreach ($CU in ($updates.Keys | Sort-Object -Descending)) {
          try {
              $currentUpdate = $updates.$CU
              # Check that we haven't already succeded with one of the CUs
              if (!$installSucceeded) {
                  # Check if the current CU exists in the current path
                  Write-Host -ForegroundColor White "CU4 or newer was not found."
                  Write-Host -ForegroundColor White "  - Looking for update: `"$env:SPbits\PrerequisiteInstallerFiles\$currentUpdate`"..."
                  if (Test-Path -Path "$env:SPbits\PrerequisiteInstallerFiles\$currentUpdate" -ErrorAction SilentlyContinue) {
                      Write-Host "  - Installing $currentUpdate..."
                      Start-Process -FilePath "$env:SPbits\PrerequisiteInstallerFiles\$currentUpdate" -ArgumentList "/passive /promptrestart" -Wait -NoNewWindow
                      if ($?) {
                          $installSucceeded = $true
                          Write-Host " - Done."
                      }
                  }
                  else {
                      Write-Host -ForegroundColor White "  - AppFabric CU $currentUpdate wasn't found, looking for other update files..."
                  }
              }
          }
          catch {
              $installSucceeded = $false
              Write-Warning "  - Something went wrong with the installation of $currentUpdate."
          }
      }
  }
  else {
      $installSucceeded = $true
      Write-Host -ForegroundColor White " - Already installed."
  }
  if (!$installSucceeded) {
      Write-Host -ForegroundColor White " - Either no required AppFabric updates were found in $env:SPbits\PrerequisiteInstallerFiles, or the installation failed."
  }
  WriteLine
}