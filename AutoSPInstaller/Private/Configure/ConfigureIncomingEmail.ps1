Function ConfigureIncomingEmail {
  # Ensure the node exists in the XML first as we don't want to inadvertently disable the service if it wasn't explicitly specified
  if (($xmlinput.Configuration.Farm.Services.SelectSingleNode("IncomingEmail")) -and !(ShouldIProvision $xmlinput.Configuration.Farm.Services.IncomingEmail -eq $true)) {
      StopServiceInstance "Microsoft.SharePoint.Administration.SPIncomingEmailServiceInstance"
  }
}