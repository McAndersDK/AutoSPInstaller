Function GetFromNode([System.Xml.XmlElement]$node, [string] $item) {
  $value = $node.GetAttribute($item)
  If ($value -eq "") {
      $child = $node.SelectSingleNode($item);
      If ($child -ne $null) {
          Return $child.InnerText;
      }
  }
  Return $value;
}