# ====================================================================================
# Func: PinToTaskbar
# Desc: Pins a program to the taskbar
# From: http://techibee.com/powershell/pin-applications-to-task-bar-using-powershell/685
# ====================================================================================
Function PinToTaskbar([string]$application) {
  $shell = New-Object -ComObject "Shell.Application"
  $folder = $shell.Namespace([System.IO.Path]::GetDirectoryName($application))

  Foreach ($verb in $folder.ParseName([System.IO.Path]::GetFileName($application)).verbs()) {
      If ($verb.name.replace("&", "") -match "Pin to Taskbar") {
          $verb.DoIt()
      }
  }
}