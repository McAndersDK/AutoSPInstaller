Function Check-PSConfig {
  $PSConfigLogLocation = $((Get-SPDiagnosticConfig).LogLocation) -replace "%CommonProgramFiles%", "$env:CommonProgramFiles"
  $PSConfigLog = Get-ChildItem -Path $PSConfigLogLocation | Where-Object {$_.Name -like "PSCDiagnostics*"} | Sort-Object -Descending -Property "LastWriteTime" | Select-Object -first 1
  If ($PSConfigLog -eq $null) {
      Throw " - Could not find PSConfig log file!"
  }
  Else {
      # Get error(s) from log
      $PSConfigLastError = $PSConfigLog | select-string -SimpleMatch -CaseSensitive -Pattern "ERR" | Select-Object -Last 1
      return $PSConfigLastError
  }
}