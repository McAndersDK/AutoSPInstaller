# ===================================================================================
# Func: ShouldIProvision
# Desc: Returns TRUE if the item whose configuration node is passed in should be provisioned.
#       on this machine.
#       This function supports wildcard computernames.   Computernames specified in the
#       AutoSpInstallerInput.xml may contain either a single * character
#       to do a wildcard match or may contain one or more # characters to match an integer.
#       Using wildcard computer names is not compatible with remote installation.
#
#   Examples:   WFE* would match computers named WFE-foo, WFEbar, etc.
#               WFE## would match WFE01, WFE02, but not WFE1
# ===================================================================================
Function ShouldIProvision([System.Xml.XmlNode] $node) {
  If (!$node) {Return $false} # In case the node doesn't exist in the XML file
  # Allow for comma- or space-delimited list of server names in Provision or Start attribute
  If ($node.GetAttribute("Provision")) {$v = $node.GetAttribute("Provision").Replace(",", " ")}
  ElseIf ($node.GetAttribute("Start")) {$v = $node.GetAttribute("Start").Replace(",", " ")}
  ElseIf ($node.GetAttribute("Install")) {$v = $node.GetAttribute("Install").Replace(",", " ")}
  If ($v -eq $true) { Return $true; }
  Return MatchComputerName $v $env:COMPUTERNAME
}