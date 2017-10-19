Function CheckInput {
  # Check that the config file exists.
  If (-not $(Test-Path -Path $inputFile -Type Leaf)) {
      Write-Error -message (" - Input file '" + $inputFile + "' does not exist.")
  }
}