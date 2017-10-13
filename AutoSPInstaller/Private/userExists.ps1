# ====================================================================================
# Func: userExists
# Desc: "Here is a little powershell function I made to see check if specific active directory users exists or not."
# From: http://oyvindnilsen.com/powershell-function-to-check-if-active-directory-users-exists/
# ====================================================================================
function userExists ([string]$name) {
  #written by: Øyvind Nilsen (oyvindnilsen.com)
  [bool]$ret = $false #return variable
  $domainRoot = [ADSI]''
  $dirSearcher = New-Object System.DirectoryServices.DirectorySearcher($domainRoot)
  $dirSearcher.filter = "(&(objectClass=user)(sAMAccountName=$name))"
  $results = $dirSearcher.findall()
  if ($results.Count -gt 0) {
      #if a user object is found, that means the user exists.
      $ret = $true
  }
  return $ret
}