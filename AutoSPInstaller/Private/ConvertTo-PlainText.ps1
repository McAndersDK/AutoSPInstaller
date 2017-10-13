# ===================================================================================
# Func: ConvertTo-PlainText
# Desc: Convert string to secure phrase
#       Used (for example) to get the Farm Account password into plain text as input to provision the User Profile Sync Service
#       From http://www.vistax64.com/powershell/159190-read-host-assecurestring-problem.html
# ===================================================================================
Function ConvertTo-PlainText( [security.securestring]$secure ) {
  $marshal = [Runtime.InteropServices.Marshal]
  $marshal::PtrToStringAuto( $marshal::SecureStringToBSTR($secure) )
}