# ===================================================================================
# Func: Set-WebAppUserPolicy
# AMW 1.7.2
# Desc: Set the web application user policy
# Refer to http://technet.microsoft.com/en-us/library/ff758656.aspx
# Updated based on Gary Lapointe example script to include Policy settings 18/10/2010
# ===================================================================================
Function Set-WebAppUserPolicy($wa, $userName, $displayName, $perm) {
  [Microsoft.SharePoint.Administration.SPPolicyCollection]$policies = $wa.Policies
  [Microsoft.SharePoint.Administration.SPPolicy]$policy = $policies.Add($userName, $displayName)
  [Microsoft.SharePoint.Administration.SPPolicyRole]$policyRole = $wa.PolicyRoles | Where-Object {$_.Name -eq $perm}
  If ($policyRole -ne $null) {
      Write-Host -ForegroundColor White " - Granting $userName $perm to $($wa.Url)..."
      $policy.PolicyRoleBindings.Add($policyRole)
  }
  $wa.Update()
}