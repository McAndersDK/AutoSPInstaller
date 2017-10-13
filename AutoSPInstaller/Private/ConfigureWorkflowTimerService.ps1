# ===================================================================================
# Func: ConfigureWorkflowTimerService
# Desc: Configures the Microsoft SharePoint Foundation Workflow Timer Service
# ===================================================================================
Function ConfigureWorkflowTimerService {
  # Ensure the node exists in the XML first as we don't want to inadvertently disable the service if it wasn't explicitly specified
  if (($xmlinput.Configuration.Farm.Services.SelectSingleNode("WorkflowTimer")) -and !(ShouldIProvision $xmlinput.Configuration.Farm.Services.WorkflowTimer -eq $true)) {
      StopServiceInstance "Microsoft.SharePoint.Workflow.SPWorkflowTimerServiceInstance"
  }
}