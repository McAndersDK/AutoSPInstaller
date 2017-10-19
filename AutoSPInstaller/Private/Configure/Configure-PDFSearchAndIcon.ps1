# ====================================================================================
# Func: Configure-PDFSearchAndIcon
# Desc: Downloads and installs the PDF iFilter, registers the PDF search file type and document icon for display in SharePoint
# From: Adapted/combined from @brianlala's additions, @tonifrankola's http://www.sharepointusecases.com/index.php/2011/02/automate-pdf-configuration-for-sharepoint-2010-via-powershell/
# And : Paul Hickman's Patch 9609 at http://autospinstaller.codeplex.com/SourceControl/list/patches
# ====================================================================================

Function Configure-PDFSearchAndIcon {
  WriteLine
  Get-MajorVersionNumber $xmlinput
  Write-Host -ForegroundColor White " - Configuring PDF file search, display and handling..."
  $sharePointRoot = "$env:CommonProgramFiles\Microsoft Shared\Web Server Extensions\$env:spVer"
  $sourceFileLocations = @("$bits\$spYear\PDF\", "$bits\PDF\", "$bits\AdobePDF\", "$((Get-Item $env:TEMP).FullName)\")
  # Only install/configure iFilter if specified, and we are running SP2010 (as SP2013 includes one)
  If ((ShouldIProvision $xmlinput.Configuration.AdobePDF.iFilter -eq $true) -and ($env:spVer -eq "14")) {
      $pdfIfilterUrl = "http://download.adobe.com/pub/adobe/acrobat/win/9.x/PDFiFilter64installer.zip"
      Write-Host -ForegroundColor White " - Configuring PDF file iFilter and indexing..."
      # Look for the installer or the installer zip in the possible locations
      ForEach ($sourceFileLocation in $sourceFileLocations) {
          If (Get-Item $($sourceFileLocation + "PDFFilter64installer.msi") -ErrorAction SilentlyContinue) {
              Write-Host -ForegroundColor White " - PDF iFilter installer found in $sourceFileLocation."
              $iFilterInstaller = $sourceFileLocation + "PDFFilter64installer.msi"
              Break
          }
          ElseIf (Get-Item $($sourceFileLocation + "PDFiFilter64installer.zip") -ErrorAction SilentlyContinue) {
              Write-Host -ForegroundColor White " - PDF iFilter installer zip file found in $sourceFileLocation."
              $zipLocation = $sourceFileLocation
              $sourceFile = $sourceFileLocation + "PDFiFilter64installer.zip"
              Break
          }
      }
      # If the MSI hasn't been extracted from the zip yet then extract it
      If (!($iFilterInstaller)) {
          # If the zip file isn't present then download it first
          If (!($sourceFile)) {
              Write-Host -ForegroundColor White " - PDF iFilter installer or zip not found, downloading..."
              If (Confirm-LocalSession) {
                  $zipLocation = (Get-Item $env:TEMP).FullName
                  $destinationFile = $zipLocation + "\PDFiFilter64installer.zip"
                  Import-Module BitsTransfer | Out-Null
                  Start-BitsTransfer -Source $pdfIfilterUrl -Destination $destinationFile -DisplayName "Downloading Adobe PDF iFilter..." -Priority Foreground -Description "From $pdfIfilterUrl..." -ErrorVariable err
                  If ($err) {Write-Warning "Could not download Adobe PDF iFilter!"; Pause "exit"; break}
                  $sourceFile = $destinationFile
              }
              Else {Write-Warning "The remote use of BITS is not supported. Please pre-download the PDF install files and try again."}
          }
          Write-Host -ForegroundColor White " - Extracting Adobe PDF iFilter installer..."
          $shell = New-Object -ComObject Shell.Application
          $iFilterZip = $shell.Namespace($sourceFile)
          $location = $shell.Namespace($zipLocation)
          $location.Copyhere($iFilterZip.items())
          $iFilterInstaller = $zipLocation + "\PDFFilter64installer.msi"
      }
      Try {
          Write-Host -ForegroundColor White " - Installing Adobe PDF iFilter..."
          Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$iFilterInstaller`" /passive /norestart" -NoNewWindow -Wait
      }
      Catch {$_}
      If ((Get-PsSnapin | Where-Object {$_.Name -eq "Microsoft.SharePoint.PowerShell"}) -eq $null) {
          Write-Host -ForegroundColor White " - Loading SharePoint PowerShell Snapin..."
          Add-PsSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue | Out-Null
      }
      Write-Host -ForegroundColor White " - Setting PDF search crawl extension..."
      $searchApplications = Get-SPEnterpriseSearchServiceApplication
      If ($searchApplications) {
          ForEach ($searchApplication in $searchApplications) {
              Try {
                  Get-SPEnterpriseSearchCrawlExtension -SearchApplication $searchApplication -Identity "pdf" -ErrorAction Stop | Out-Null
                  Write-Host -ForegroundColor White " - PDF file extension already set for $($searchApplication.DisplayName)."
              }
              Catch {
                  New-SPEnterpriseSearchCrawlExtension -SearchApplication $searchApplication -Name "pdf" | Out-Null
                  Write-Host -ForegroundColor White " - PDF extension for $($searchApplication.DisplayName) now set."
              }
          }
      }
      Else {Write-Warning "No search applications found."}
      Write-Host -ForegroundColor White " - Updating registry..."
      If ((Get-Item -Path Registry::"HKLM\SOFTWARE\Microsoft\Office Server\$env:spVer.0\Search\Setup\Filters\.pdf" -ErrorAction SilentlyContinue) -eq $null) {
          $item = New-Item -Path Registry::"HKLM\SOFTWARE\Microsoft\Office Server\$env:spVer.0\Search\Setup\Filters\.pdf"
          $item | New-ItemProperty -Name Extension -PropertyType String -Value "pdf" | Out-Null
          $item | New-ItemProperty -Name FileTypeBucket -PropertyType DWord -Value 1 | Out-Null
          $item | New-ItemProperty -Name MimeTypes -PropertyType String -Value "application/pdf" | Out-Null
      }
      If ((Get-Item -Path Registry::"HKLM\SOFTWARE\Microsoft\Office Server\$env:spVer.0\Search\Setup\ContentIndexCommon\Filters\Extension\.pdf" -ErrorAction SilentlyContinue) -eq $null) {
          $registryItem = New-Item -Path Registry::"HKLM\SOFTWARE\Microsoft\Office Server\$env:spVer.0\Search\Setup\ContentIndexCommon\Filters\Extension\.pdf"
          $registryItem | New-ItemProperty -Name "(default)" -PropertyType String -Value "{E8978DA6-047F-4E3D-9C78-CDBE46041603}" | Out-Null
      }
      $spSearchService = "OSearch" + $env:spVer # Substitute the correct SharePoint version into the service name so we can handle SP2013 as well as SP2010
      If ((Get-Service $spSearchService).Status -eq "Running") {
          Write-Host -ForegroundColor White " - Restarting SharePoint Search Service..."
          Restart-Service $spSearchService
      }
      Write-Host -ForegroundColor White " - Done configuring PDF iFilter and indexing."
  }
  If ($xmlinput.Configuration.AdobePDF.Icon.Configure -eq $true) {
      $docIconFolderPath = "$sharePointRoot\TEMPLATE\XML"
      $docIconFilePath = "$docIconFolderPath\DOCICON.XML"
      $xml = New-Object XML
      $xml.Load($docIconFilePath)
      # Only configure PDF icon if we are running SP2010 (as SP2013 includes one)
      if ($env:spVer -eq "14") {
          $pdfIconUrl = "http://www.adobe.com/images/pdficon_small.png"
          Write-Host -ForegroundColor White " - Configuring PDF Icon..."
          $pdfIcon = "pdficon_small.png"
          If (!(Get-Item $sharePointRoot\Template\Images\$pdfIcon -ErrorAction SilentlyContinue)) {
              ForEach ($sourceFileLocation in $sourceFileLocations) {
                  # Check each possible source file location for the PDF icon
                  $copyIcon = Copy-Item -Path $sourceFileLocation\$pdfIcon -Destination $sharePointRoot\Template\Images\$pdfIcon -PassThru -ErrorAction SilentlyContinue
                  If ($copyIcon) {
                      Write-Host -ForegroundColor White " - PDF icon found at $sourceFileLocation\$pdfIcon"
                      Break
                  }
              }
              If (!($copyIcon)) {
                  Write-Host -ForegroundColor White " - `"$pdfIcon`" not found; downloading it now..."
                  If (Confirm-LocalSession) {
                      Import-Module BitsTransfer | Out-Null
                      Start-BitsTransfer -Source $pdfIconUrl -Destination "$sharePointRoot\Template\Images\$pdfIcon" -DisplayName "Downloading PDF Icon..." -Priority Foreground -Description "From $pdfIconUrl..." -ErrorVariable err
                      If ($err) {Write-Warning "Could not download PDF Icon!"; Pause "exit"; break}
                  }
                  Else {Write-Warning "The remote use of BITS is not supported. Please pre-download the PDF icon and try again."}
              }
              If (Get-Item $sharePointRoot\Template\Images\$pdfIcon) {Write-Host -ForegroundColor White " - PDF icon copied successfully."}
              Else {Throw}
          }
          If ($xml.SelectSingleNode("//Mapping[@Key='pdf']") -eq $null) {
              Try {
                  $pdf = $xml.CreateElement("Mapping")
                  $pdf.SetAttribute("Key", "pdf")
                  $pdf.SetAttribute("Value", $pdfIcon)
              }
              Catch {$_; Pause "exit"; Break}
          }
      }
      # Perform the rest of the DOCICON.XML modifications to allow PDF edit etc., and write out the new DOCICON.XML file
      Try {
          $date = Get-Date -UFormat "%y%m%d%H%M%S"
          Write-Host -ForegroundColor White " - Creating backup of DOCICON.XML file..."
          $backupFile = "$docIconFolderPath\DOCICON_Backup_$date.xml"
          Copy-Item $docIconFilePath $backupFile
          Write-Host -ForegroundColor White " - Writing new DOCICON.XML..."
          if (!$pdf) {$pdf = $xml.SelectSingleNode("//Mapping[@Key='pdf']")}
          if (!$pdf) {$pdf = $xml.CreateElement("Mapping")}
          $pdf.SetAttribute("EditText", "Adobe Acrobat or Reader X")
          $pdf.SetAttribute("OpenControl", "AdobeAcrobat.OpenDocuments")
          $xml.DocIcons.ByExtension.AppendChild($pdf) | Out-Null
          $xml.Save($docIconFilePath)
          Write-Host -ForegroundColor White " - Restarting IIS..."
          iisreset
      }
      Catch {$_; Pause "exit"; Break}
  }
  If ($xmlinput.Configuration.AdobePDF.MIMEType.Configure -eq $true) {
      # Add the PDF MIME type to each web app so PDFs can be directly viewed/opened without saving locally first
      # More granular and generally preferable to setting the whole web app to "Permissive" file handling
      $mimeType = "application/pdf"
      Write-Host -ForegroundColor White " - Adding PDF MIME type `"$mimeType`" web apps..."
      Load-SharePoint-PowerShell
      ForEach ($webAppConfig in $xmlinput.Configuration.WebApplications.WebApplication) {
          $webAppUrl = $(($webAppConfig.url).TrimEnd("/")) + ":" + $($webAppConfig.Port)
          $webApp = Get-SPWebApplication -Identity $webAppUrl
          If ($webApp.AllowedInlineDownloadedMimeTypes -notcontains $mimeType) {
              Write-Host -ForegroundColor White "  - "$webAppUrl": Adding "`"$mimeType"`"..." -NoNewline
              $webApp.AllowedInlineDownloadedMimeTypes.Add($mimeType)
              $webApp.Update()
              Write-Host -ForegroundColor White "OK."
          }
          Else {
              Write-Host -ForegroundColor White "  - "$webAppUrl": "`"$mimeType"`" already added."
          }
      }
  }
  Write-Host -ForegroundColor White " - Done configuring PDF indexing and icon display."
  WriteLine
}