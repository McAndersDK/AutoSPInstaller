Function Get-ApplicationPool([System.Xml.XmlElement]$appPoolConfig) {
  # Try and get the application pool if it already exists
  # SLN: Updated names
  $pool = Get-SPServiceApplicationPool -Identity $appPoolConfig.Name -ErrorVariable err -ErrorAction SilentlyContinue
  If ($err) {
      # The application pool does not exist so create.
      Write-Host -ForegroundColor White "  - Getting $($searchServiceAccount.Username) account for application pool..."
      $managedAccountSearch = (Get-SPManagedAccount -Identity $searchServiceAccount.Username -ErrorVariable err -ErrorAction SilentlyContinue)
      If ($err) {
          If (!([string]::IsNullOrEmpty($searchServiceAccount.Password))) {
              $appPoolConfigPWD = (ConvertTo-SecureString $searchServiceAccount.Password -AsPlainText -force)
              $accountCred = New-Object System.Management.Automation.PsCredential $searchServiceAccount.Username, $appPoolConfigPWD
          }
          Else {
              $accountCred = Get-Credential $searchServiceAccount.Username
          }
          $managedAccountSearch = New-SPManagedAccount -Credential $accountCred
      }
      Write-Host -ForegroundColor White "  - Creating $($appPoolConfig.Name)..."
      $pool = New-SPServiceApplicationPool -Name $($appPoolConfig.Name) -Account $managedAccountSearch
  }
  Return $pool
}
