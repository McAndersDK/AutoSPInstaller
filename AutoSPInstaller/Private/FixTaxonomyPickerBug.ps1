# ====================================================================================
# Func: FixTaxonomyPickerBug
# Desc: Renames the TaxonomyPicker.ascx file which doesn't seem to be used anyhow
# Desc: Goes one step further than the fix suggested in http://support.microsoft.com/kb/2481844 (which doesn't work at all)
# ====================================================================================
Function FixTaxonomyPickerBug {
  $taxonomyPicker = "$env:CommonProgramFiles\Microsoft Shared\Web Server Extensions\$env:spVer\TEMPLATE\CONTROLTEMPLATES\TaxonomyPicker.ascx"
  If (Test-Path $taxonomyPicker) {
      WriteLine
      Write-Host -ForegroundColor White " - Renaming TaxonomyPicker.ascx..."
      Move-Item -Path $taxonomyPicker -Destination $taxonomyPicker".buggy" -Force
      Write-Host -ForegroundColor White " - Done."
      WriteLine
  }
}