# ===================================================================================
# Func: AssignCert
# Desc: Create and assign SSL Certificate
# ===================================================================================
Function AssignCert($SSLHostHeader, $SSLPort, $SSLSiteName) {
  ImportWebAdministration
  if (!$env:spVer) {Get-MajorVersionNumber $xmlinput}
  Write-Host -ForegroundColor White " - Assigning certificate to site `"https://$SSLHostHeader`:$SSLPort`""
  # If our SSL host header is a FQDN (contains a dot), look for an existing wildcard cert
  If ($SSLHostHeader -like "*.*") {
      # Remove the host portion of the URL and the leading dot
      $splitSSLHostHeader = $SSLHostHeader -split "\."
      $topDomain = $SSLHostHeader.Substring($splitSSLHostHeader[0].Length + 1)
      # Create a new wildcard cert so we can potentially use it on other sites too
      if ($SSLHostHeader -like "*.$env:USERDNSDOMAIN") {
          $certCommonName = "*.$env:USERDNSDOMAIN"
      }
      elseif ($SSLHostHeader -like "*.$topDomain") {
          $certCommonName = "*.$topDomain"
      }
      Write-Host -ForegroundColor White " - Looking for existing `"$certCommonName`" wildcard certificate..."
      $cert = Get-ChildItem cert:\LocalMachine\My | Where-Object {$_.Subject -eq "CN=$certCommonName"}
  }
  Else {
      # Just create a cert that matches the SSL host header
      $certCommonName = $SSLHostHeader
      Write-Host -ForegroundColor White " - Looking for existing `"$certCommonName`" certificate..."
      $cert = Get-ChildItem cert:\LocalMachine\My | Where-Object {$_.Subject -eq "CN=$certCommonName"}
  }
  If (!$cert) {
      Write-Host -ForegroundColor White " - None found."
      if (Get-Command -Name New-SelfSignedCertificate -ErrorAction SilentlyContinue) {
          # SP2016 no longer seems to ship with makecert.exe, but we should be able to use PowerShell native commands instead in Windows 2012 R2 / PowerShell 4.0 and higher
          # New PowerShelly way to create self-signed certs, so we don't need makecert.exe
          # From http://windowsitpro.com/blog/creating-self-signed-certificates-powershell
          Write-Host -ForegroundColor White " - Creating new self-signed certificate $certCommonName..."
          $cert = New-SelfSignedCertificate -certstorelocation cert:\localmachine\my -dnsname $certCommonName
          ##$cert = Get-ChildItem cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=``*$certCommonName"}
      }
      else {
          # Try to create the cert using makecert.exe instead
          # Get the actual location of makecert.exe in case we installed SharePoint in the non-default location
          $spInstallPath = (Get-Item -Path "HKLM:\SOFTWARE\Microsoft\Office Server\$env:spVer.0").GetValue("InstallPath")
          $makeCert = "$spInstallPath\Tools\makecert.exe"
          If (Test-Path "$makeCert") {
              Write-Host -ForegroundColor White " - Creating new self-signed certificate $certCommonName..."
              Start-Process -NoNewWindow -Wait -FilePath "$makeCert" -ArgumentList "-r -pe -n `"CN=$certCommonName`" -eku 1.3.6.1.5.5.7.3.1 -ss My -sr localMachine -sky exchange -sp `"Microsoft RSA SChannel Cryptographic Provider`" -sy 12"
              $cert = Get-ChildItem cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=``*$certCommonName"}
              if (!$cert) {$cert = Get-ChildItem cert:\LocalMachine\My | Where-Object {$_.Subject -eq "CN=$SSLHostHeader"}}
          }
          Else {
              Write-Host -ForegroundColor Yellow " - `"$makeCert`" not found."
              Write-Host -ForegroundColor White " - Looking for any machine-named certificates we can use..."
              # Select the first certificate with the most recent valid date
              $cert = Get-ChildItem cert:\LocalMachine\My | Where-Object {$_.Subject -like "*$env:COMPUTERNAME"} | Sort-Object NotBefore -Desc | Select-Object -First 1
              If (!$cert) {
                  Write-Host -ForegroundColor Yellow " - None found, skipping certificate creation."
              }
          }
      }
  }
  If ($cert) {
      $certSubject = $cert.Subject
      Write-Host -ForegroundColor White " - Certificate `"$certSubject`" found."
      # Fix up the cert subject name to a file-friendly format
      $certSubjectName = $certSubject.Split(",")[0] -replace "CN=", "" -replace "\*", "wildcard"
      $certsubjectname = $certsubjectname.TrimEnd("/")
      # Export our certificate to a file, then import it to the Trusted Root Certification Authorites store so we don't get nasty browser warnings
      # This will actually only work if the Subject and the host part of the URL are the same
      # Borrowed from https://www.orcsweb.com/blog/james/powershell-ing-on-windows-server-how-to-import-certificates-using-powershell/
      Write-Host -ForegroundColor White " - Exporting `"$certSubject`" to `"$certSubjectName.cer`"..."
      $cert.Export("Cert") | Set-Content -Path "$((Get-Item $env:TEMP).FullName)\$certSubjectName.cer" -Encoding byte
      $pfx = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
      Write-Host -ForegroundColor White " - Importing `"$certSubjectName.cer`" to Local Machine\Root..."
      $pfx.Import("$((Get-Item $env:TEMP).FullName)\$certSubjectName.cer")
      $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
      $store.Open("MaxAllowed")
      $store.Add($pfx)
      $store.Close()
      Write-Host -ForegroundColor White " - Assigning certificate `"$certSubject`" to SSL-enabled site..."
      #Set-Location IIS:\SslBindings -ErrorAction Inquire
      if (!(Get-Item IIS:\SslBindings\0.0.0.0!$SSLPort -ErrorAction SilentlyContinue)) {
          $cert | New-Item IIS:\SslBindings\0.0.0.0!$SSLPort -ErrorAction SilentlyContinue | Out-Null
      }
      # Check if we have specified no host header
      if (!([string]::IsNullOrEmpty($webApp.UseHostHeader)) -and $webApp.UseHostHeader -eq $false) {
          Set-ItemProperty IIS:\Sites\$SSLSiteName -Name bindings -Value @{protocol = "https"; bindingInformation = "*:$($SSLPort):"} -ErrorAction SilentlyContinue
      }
      else {
          # Set the binding to the host header {
          Set-ItemProperty IIS:\Sites\$SSLSiteName -Name bindings -Value @{protocol = "https"; bindingInformation = "*:$($SSLPort):$($SSLHostHeader)"} -ErrorAction SilentlyContinue
      }
      ## Set-WebBinding -Name $SSLSiteName -BindingInformation ":$($SSLPort):" -PropertyName Port -Value $SSLPort -PropertyName Protocol -Value https
      Write-Host -ForegroundColor White " - Certificate has been assigned to site `"https://$SSLHostHeader`:$SSLPort`""
  }
  Else {Write-Host -ForegroundColor White " - No certificates were found, and none could be created."}
  $cert = $null
}