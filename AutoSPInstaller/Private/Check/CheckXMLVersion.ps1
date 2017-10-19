# Check that the version of the script matches the Version (essentially the schema) of the input XML so we don't have any unexpected behavior
Function CheckXMLVersion ([xml]$xmlinput) {
  $getXMLVersion = $xmlinput.Configuration.Version
  # The value below will increment whenever there is an update to the format of the AutoSPInstallerInput XML file
  $scriptCurrentVersion = "3.99.60"
  $scriptPreviousVersion = "3.99.51"
  if ($getXMLVersion -ne $scriptCurrentVersion) {
      if ($getXMLVersion -eq $scriptPreviousVersion) {
          Write-Host -ForegroundColor Yellow " - Warning! Your input XML version ($getXMLVersion) is one level behind the script's version."
          Write-Host -ForegroundColor Yellow " - Visit https://autospinstaller.com to update it to the current version before proceeding."
      }
      else {
          Write-Host -ForegroundColor Yellow " - Warning! Your versions of the XML ($getXMLVersion) and script ($scriptCurrentVersion) are mismatched."
          Write-Host -ForegroundColor Yellow " - You should compare against the latest AutoSPInstallerInput.XML for missing/updated elements."
          Write-Host -ForegroundColor Yellow " - Or, try to validate/update your XML input at https://autospinstaller.com"
      }
      Pause "proceed with running AutoSPInstaller if you are sure this is OK, or Ctrl-C to exit" "y"
  }
}