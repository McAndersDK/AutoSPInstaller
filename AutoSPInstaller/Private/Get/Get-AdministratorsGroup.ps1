# ====================================================================================
# Func: Get-AdministratorsGroup
# Desc: Returns the actual (localized) name of the built-in Administrators group
# From: Proposed by Codeplex user Sheppounet at http://autospinstaller.codeplex.com/discussions/265749
# ====================================================================================
Function Get-AdministratorsGroup {
  If (!$builtinAdminGroup) {
      $builtinAdminGroup = (Get-WmiObject -Class Win32_Group -computername $env:COMPUTERNAME -Filter "SID='S-1-5-32-544' AND LocalAccount='True'" -errorAction "Stop").Name
  }
  Return $builtinAdminGroup
}
