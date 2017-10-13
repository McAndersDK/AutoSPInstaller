# ===================================================================================
# Func: MatchComputerName
# Desc: Returns TRUE if the $computerName specified matches one of the items in $computersList.
#       Supports wildcard matching (# for a a number, * for any non whitepace character)
# ===================================================================================
Function MatchComputerName($computersList, $computerName) {
  If ($computersList -like "*$computerName*") { Return $true; }
  foreach ($v in $computersList) {
      If ($v.Contains("*") -or $v.Contains("#")) {
          # wildcard processing
          foreach ($item in -split $v) {
              $item = $item -replace "#", "[\d]"
              $item = $item -replace "\*", "[\S]*"
              if ($computerName -match $item) {return $true; }
          }
      }
  }
}