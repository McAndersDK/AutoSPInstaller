Function ValidateCredentials([xml]$xmlinput) {
  WriteLine
  Write-Host -ForegroundColor White " - Validating user accounts and passwords..."
  If ($env:COMPUTERNAME -eq $env:USERDOMAIN) {
      Throw " - You are running this script under a local machine user account. You must be a domain user"
  }

  ForEach ($node in $xmlinput.SelectNodes("//*[@Password]|//*[@password]|//*[@ContentAccessAccountPassword]|//*[@UnattendedIDPassword]|//*[@SyncConnectionAccountPassword]|//*[Password]|//*[password]|//*[ContentAccessAccountPassword]|//*[UnattendedIDPassword]|//*[SyncConnectionAccountPassword]")) {
      $user = (GetFromNode $node "username")
      If ($user -eq "") { $user = (GetFromNode $node "Username") }
      If ($user -eq "") { $user = (GetFromNode $node "Account") }
      If ($user -eq "") { $user = (GetFromNode $node "ContentAccessAccount") }
      If ($user -eq "") { $user = (GetFromNode $node "UnattendedIDUser") }
      If ($user -eq "") { $user = (GetFromNode $node "SyncConnectionAccount") }

      $password = (GetFromNode $node "password")
      If ($password -eq "") { $password = (GetFromNode $node "Password") }
      If ($password -eq "") { $password = (GetFromNode $node "ContentAccessAccountPassword") }
      If ($password -eq "") { $password = (GetFromNode $node "UnattendedIDPassword") }
      If ($password -eq "") { $password = (GetFromNode $node "SyncConnectionAccountPassword") }

      If (($password -ne "") -and ($user -ne "")) {
          $currentDomain = "LDAP://" + ([ADSI]"").distinguishedName
          Write-Host -ForegroundColor White " - Account `"$user`" ($($node.Name))..." -NoNewline
          $dom = New-Object System.DirectoryServices.DirectoryEntry($currentDomain, $user, $password)
          If ($dom.Path -eq $null) {
              Write-Host -BackgroundColor Red -ForegroundColor Black "Invalid!"
              $acctInvalid = $true
          }
          Else {
              Write-Host -ForegroundColor Black -BackgroundColor Green "Verified."
          }
      }
  }
  if ($xmlinput.Configuration.WebApplications) {
      # Get application pool accounts
      foreach ($webApp in $($xmlinput.Configuration.WebApplications.WebApplication)) {
          $appPoolAccounts = @($appPoolAccounts + $webApp.applicationPoolAccount)
          # Get site collection owners #
          foreach ($siteCollection in $($webApp.SiteCollections.SiteCollection)) {
              if (!([string]::IsNullOrEmpty($siteCollection.Owner))) {
                  $siteCollectionOwners = @($siteCollectionOwners + $siteCollection.Owner)
              }
          }
      }
  }
  $appPoolAccounts = $appPoolAccounts | Select-Object -Unique
  $siteCollectionOwners = $siteCollectionOwners | Select-Object -Unique
  # Check for the existence of object cache accounts and other ones for which we don't need to specify passwords
  $accountsToCheck = @($xmlinput.Configuration.Farm.ObjectCacheAccounts.SuperUser, $xmlinput.Configuration.Farm.ObjectCacheAccounts.SuperReader) + $appPoolAccounts + $siteCollectionOwners | Select-Object -Unique
  foreach ($account in $accountsToCheck) {
      $domain, $accountName = $account -split "\\"
      Write-Host -ForegroundColor White " - Account `"$account`"..." -NoNewline
      if (!(userExists $accountName)) {
          Write-Host -BackgroundColor Red -ForegroundColor Black "Invalid!"
          $acctInvalid = $true
      }
      else {
          Write-Host -ForegroundColor Black -BackgroundColor Green "Verified."
      }
  }
  If ($acctInvalid) {Throw " - At least one set of credentials is invalid.`n - Check usernames and passwords in each place they are used."}
  WriteLine
}