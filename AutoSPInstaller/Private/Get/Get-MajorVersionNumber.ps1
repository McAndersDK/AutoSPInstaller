function Get-MajorVersionNumber ([xml]$xmlinput) {
  # Create hash tables with major version to product year mappings & vice-versa
  $spYears = @{"14" = "2010"; "15" = "2013"; "16" = "2016"}
  $spVersions = @{"2010" = "14"; "2013" = "15"; "2016" = "16"}
  $env:spVer = $spVersions.($xmlinput.Configuration.Install.SPVersion)
}