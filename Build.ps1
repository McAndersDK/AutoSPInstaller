$RootPath = get-item $psscriptroot
$ModuleName = $RootPath.BaseName -split "-"
if($ModuleName.Count -gt 1) {
    $ModuleName = $ModuleName[1]
}
$ModulePath = "$psscriptroot/$ModuleName"
$release = "$psscriptroot/Release/$ModuleName"
$PublicFunctions = @()
$AliasToExports = @()
$FileList = @()
$manifest = "$release\$ModuleName.psd1"
if(test-path $release) {
    Remove-Item -Recurse -Force -Confirm:$false -Path $release
}
new-item $release -Force -ItemType directory
[version]$ModuleVersion = (Invoke-Expression  (get-content "$ModulePath\$ModuleName.psd1" -Raw)).ModuleVersion
$newVersion = "{0}.{1}.{2}.{3}" -f $ModuleVersion.Major, $ModuleVersion.Minor, $ModuleVersion.Build, ($ModuleVersion.Revision + 1)

try {
    copy-item "$ModulePath\$ModuleName.psd1" $manifest -Force -ErrorAction Stop
    $FileList += "$modulename.psd1"
}
catch {
    Write-Verbose "No PSD1 file to move"
}
try {
    copy-item "$ModulePath\$ModuleName.psm1" "$release\$ModuleName.psm1" -Force -ErrorAction Stop
    $FileList += "$modulename.psm1"
}
catch {
    Write-Verbose "No PSM1 file to move"
}

"########################" | Add-Content "$release\$ModuleName.psm1"
"### Public Functions ###" | Add-Content "$release\$ModuleName.psm1"
"########################" | Add-Content "$release\$ModuleName.psm1"
foreach($function in (get-childitem $ModulePath\Public\ -Recurse)) {
    $PublicFunctions += $function.basename
    $content = Get-Content $function.fullname 
    $content | Add-Content "$release\$ModuleName.psm1"
    if($content -match '\[Alias\(([^\)]*)') {
        foreach($alias in ($matches[1] -split ",") -replace ("`"",''))  {
            $AliasToExports += $alias
        }
    }
}
"#########################" | Add-Content "$release\$ModuleName.psm1"
"### Private Functions ###" | Add-Content "$release\$ModuleName.psm1"
"#########################" | Add-Content "$release\$ModuleName.psm1"
foreach($function in (get-childitem $ModulePath\Private\ -Recurse)) {
    Get-Content $function.fullname | Add-Content "$release\$ModuleName.psm1"
}
$Params = @{
    Path = $manifest;
    FunctionsToExport = $PublicFunctions;
    FileList = $FileList;
    RootModule = "$ModuleName.psm1"
    ModuleVersion = $newVersion
    }

if($AliasToExports.count -ge 1) {
    $Params.Add('AliasesToExport', $AliasesToExport)
}
Update-ModuleManifest @Params 
$Params.path = "$ModulePath\$modulename.psd1"
Update-ModuleManifest @Params 
#.\Publish.ps1