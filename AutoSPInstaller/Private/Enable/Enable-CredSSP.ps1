Function Enable-CredSSP ($remoteFarmServers) {
  ForEach ($server in $remoteFarmServers) {Write-Host -ForegroundColor White " - Enabling WSManCredSSP for `"$server`""}
  Enable-WSManCredSSP -Role Client -Force -DelegateComputer $remoteFarmServers | Out-Null
  If (!$?) {Pause "exit"; throw $_}
}