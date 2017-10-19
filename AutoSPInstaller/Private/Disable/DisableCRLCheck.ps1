Function DisableCRLCheck([xml]$xmlinput) {
  WriteLine
  If ($xmlinput.Configuration.Install.Disable.CertificateRevocationListCheck -eq "True") {
      Write-Host -ForegroundColor White " - Disabling Certificate Revocation List (CRL) check..."
      Write-Host -ForegroundColor White "  - Registry..."
      New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null
      New-ItemProperty -Path "HKU:\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing" -Name State -PropertyType DWord -Value 146944 -Force | Out-Null
      New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing" -Name State -PropertyType DWord -Value 146944 -Force | Out-Null
      Write-Host -ForegroundColor White "  - Machine.config files..."
      [array]$frameworkVersions = "v2.0.50727", "v4.0.30319" # For .Net 2.0 and .Net 4.0
      ForEach ($bitsize in ("", "64")) {
          foreach ($frameworkVersion in $frameworkVersions) {
              # Added a check below for $xml because on Windows Server 2012 machines, the path to $xml doesn't exist until the .Net Framework is installed, so the steps below were failing
              $xml = [xml](Get-Content "$env:windir\Microsoft.NET\Framework$bitsize\$frameworkVersion\CONFIG\Machine.config" -ErrorAction SilentlyContinue)
              if ($xml) {
                  if ($bitsize -eq "64") {Write-Host -ForegroundColor White "   - $frameworkVersion..." -NoNewline}
                  If (!$xml.DocumentElement.SelectSingleNode("runtime")) {
                      $runtime = $xml.CreateElement("runtime")
                      $xml.DocumentElement.AppendChild($runtime) | Out-Null
                  }
                  If (!$xml.DocumentElement.SelectSingleNode("runtime/generatePublisherEvidence")) {
                      $gpe = $xml.CreateElement("generatePublisherEvidence")
                      $xml.DocumentElement.SelectSingleNode("runtime").AppendChild($gpe) | Out-Null
                  }
                  $xml.DocumentElement.SelectSingleNode("runtime/generatePublisherEvidence").SetAttribute("enabled", "false") | Out-Null
                  $xml.Save("$env:windir\Microsoft.NET\Framework$bitsize\$frameworkVersion\CONFIG\Machine.config")
                  if ($bitsize -eq "64") {Write-Host -ForegroundColor White "OK."}
              }
              else {
                  if ($bitsize -eq "") {$bitsize = "32"}
                  Write-Warning "$bitsize-bit machine.config not found - could not disable CRL check."
              }
          }
      }
      Write-Host -ForegroundColor White " - Done."
  }
  Else {
      Write-Host -ForegroundColor White " - Not changing CRL check behavior."
  }
  WriteLine
}