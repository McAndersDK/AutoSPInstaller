# ====================================================================================
# Func: EnsureFolder
# Desc: Checks for the existence and validity of a given path, and attempts to create if it doesn't exist.
# From: Modified from patch 9833 at http://autospinstaller.codeplex.com/SourceControl/list/patches by user timiun
# ====================================================================================
Function EnsureFolder ($path) {
  If (!(Test-Path -Path $path -PathType Container)) {
      Write-Host -ForegroundColor White " - $path doesn't exist; creating..."
      Try {
          New-Item -Path $path -ItemType Directory | Out-Null
      }
      Catch {
          Write-Warning "$($_.Exception.Message)"
          Throw " - Could not create folder $path!"
      }
  }
}