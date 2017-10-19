# This is from http://autospinstaller.codeplex.com/discussions/228507?ProjectName=autospinstaller courtesy of rybocf
Function ConfigureOutgoingEmail {
  If ($($xmlinput.Configuration.Farm.Services.OutgoingEmail.Configure) -eq $true) {
      WriteLine
      Try {
          $SMTPServer = $xmlinput.Configuration.Farm.Services.OutgoingEmail.SMTPServer
          $emailAddress = $xmlinput.Configuration.Farm.Services.OutgoingEmail.EmailAddress
          $replyToEmail = $xmlinput.Configuration.Farm.Services.OutgoingEmail.ReplyToEmail
          Write-Host -ForegroundColor White " - Configuring Outgoing Email..."
          $loadasm = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint")
          $spGlobalAdmin = New-Object Microsoft.SharePoint.Administration.SPGlobalAdmin
          $spGlobalAdmin.UpdateMailSettings($SMTPServer, $emailAddress, $replyToEmail, 65001)
      }
      Catch {
          Write-Output $_
      }
      WriteLine
  }
}