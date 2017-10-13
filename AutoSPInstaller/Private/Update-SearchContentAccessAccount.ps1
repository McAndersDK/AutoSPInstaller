function Update-SearchContentAccessAccount ($saName, $sa, $caa, $caapwd) {
  try {
      Write-Host -ForegroundColor White "  - Setting content access account for $saName..."
      $sa | Set-SPEnterpriseSearchServiceApplication -DefaultContentAccessAccountName $caa -DefaultContentAccessAccountPassword $caapwd -ErrorVariable err
  }
  catch {
      if ($err -like "*update conflict*") {
          Write-Warning "An update conflict error occured, trying again."
          Update-SearchContentAccessAccount $saName, $sa, $caa, $caapwd
          $sa | Set-SPEnterpriseSearchServiceApplication -DefaultContentAccessAccountName $caa -DefaultContentAccessAccountPassword $caapwd -ErrorVariable err
      }
      else {
          throw $_
      }
  }
  finally {Clear-Variable err}
}