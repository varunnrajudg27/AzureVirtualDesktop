<#
.SYNOPSIS
Invoke the removal of a deployed module

.DESCRIPTION
Invoke the removal of a deployed module.
Requires the resource in question to be tagged with 'RemoveModule = <moduleName>'

.PARAMETER moduleName
Mandatory. The name of the module to remove

.PARAMETER resourceGroupName
Mandatory. The resource group of the resource to remove

.PARAMETER maximumRemovalRetries
Optional. As the removal fetches all resources with the removal tag, and then tries to remove them one by one it can happen that the function tries to removed that as an active dependency on it (e.g. a VM disk of a VM deployment).
If the removal fails, the resource in question is moved back in the removal queue and another attempt is made after processing each other resource found.
This parameter controls, how often we want to push resources back in the queue and retry a removal.

.PARAMETER modulePath
Mandatory. Path to the module from root.

.PARAMETER componentsBasePath
Mandatory. The path to the component/module root

.EXAMPLE
Remove-DeployedModule -moduleName 'KeyVault' -resourceGroupName 'validation-rg' -modulePath 'Modules/ARM/KeyVault' -componentsBasePath '$(System.DefaultWorkingDirectory)'

Remove any resource in the resource group 'validation-rg' with tag 'RemoveModule = KeyVault'
#>
function Remove-DeployedModule {

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string] $moduleName,

        [Parameter(Mandatory)]
        [string] $resourceGroupName,

        [Parameter(Mandatory)]
        [string] $modulePath,

        [Parameter(Mandatory)]
        [string] $componentsBasePath,

        [Parameter(Mandatory = $false)]
        [int] $maximumRemovalRetries = 3
    )

    begin {
        Write-Debug ("{0} entered" -f $MyInvocation.MyCommand)
    }

    process {

        $templateFilePath = "$componentsBasePath/$modulePath/deploy.json"
        Write-Verbose "Got path: $templateFilePath" -Verbose
        $deploymentSchema = (ConvertFrom-Json (Get-Content -Path $templateFilePath -Raw )).'$schema'
        if ($deploymentSchema -match '\/subscriptionDeploymentTemplate.json#$') {
            $resourceGroupToRemove = Get-AzResourceGroup -Tag @{ RemoveModule = $moduleName }
            if ($resourceGroupToRemove) {
                if ($resourceGroupToRemove.Count -gt 1) {
                    Write-Error "More than 1 Resource Group has been found with tag [RemoveModule=$moduleName]. Only 1 Resource Group is expected."
                }
                elseif (Get-AzResource -ResourceGroupName $resourceGroupToRemove.ResourceGroupName) {
                    Write-Error "Resource Group [$resourceGroupName] still has resources provisioned."
                }
                else {
                    Write-Verbose ("Removing Resource Group: {0}" -f $resourceGroupToRemove.ResourceGroupName) -Verbose
                    try {
                        $removeStatus = $resourceGroupToRemove |
                        Remove-AzResourceGroup -Force -ErrorAction Stop
                        if ($removeStatus) {
                            Write-Verbose ("Successfully removed Resource Group: {0}" -f $resourceGroupToRemove.ResourceGroupName) -Verbose
                        }
                    }
                    catch {
                        Write-Error ("Resource Group removal failed. Reason: [{0}]" -f $_.Exception.Message)
                    }
                }
            }
            else {
                Write-Error ("Unable to find Resource Group by tag [RemoveModule={0}]." -f $moduleName)
            }
        }
        else {
            $resourcesToRemove = Get-AzResource -Tag @{ RemoveModule = $moduleName } -ResourceGroupName $resourceGroupName
            if ($resourcesToRemove) {

                # If VMs are available, delete those first
                if($vmsContained = $resourcesToRemove | Where-Object { $_.resourcetype -eq 'Microsoft.Compute/virtualMachines' }) {
                    Remove-Resource -resourcesToRemove $vmsContained
                    # refresh
                    $resourcesToRemove = Get-AzResource -Tag @{ RemoveModule = $moduleName } -ResourceGroupName $resourceGroupName
                }

                $currentRety = 0
                $resourcesToRetry = @()
                if ($PSCmdlet.ShouldProcess(("[{0}] Resource(s) with a maximum of [$maximumRemovalRetries] attempts." -f $resourcesToRemove.Count), "Remove")) {
                    while (($resourcesToRetry = Remove-Resource -resourcesToRemove $resourcesToRemove).Count -gt 0 -and $currentRety -le $maximumRemovalRetries) {
                        Write-Verbose ("Re-try removal of remaining [{0}] resources. Round [{1}|{2}]" -f $resourcesToRetry.Count, $currentRety, $maximumRemovalRetries)
                        $currentRety++
                    }

                    if ($resourcesToRetry.Count -gt 0) {
                        throw ("The removal failed for resources [{0}]" -f ($resourcesToRetry.Name -join ', '))
                    }
                    else {
                        Write-Verbose "The removal completed successfully"
                    }
                }
                else {
                    Remove-Resource -resourcesToRemove $resourcesToRemove -WhatIf
                }
            }
            else {
                Write-Error ("Unable to find resources by tags [RemoveModule=$moduleName] in resource group [$resourceGroupName].")
            }
        }
    }
    end {
        Write-Debug ("{0} exited" -f $MyInvocation.MyCommand)
    }
}

function Remove-Resource {

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [object[]] $resourcesToRemove
    )

    $resourcesToRetry = @()
    Write-Verbose "----------------------------------"
    foreach ($resource in $resourcesToRemove) {
        try {
            if ($PSCmdlet.ShouldProcess(("Resource [{0}] of type [{1}] from resource group [{2}]" -f $resource.Name, $resource.ResourceType, $resource.ResourceGroupName), "Remove")) {
                $null = Remove-AzResource -ResourceId $resource.ResourceId -Force -ErrorAction 'Stop'
                Write-Verbose ("Removed resource [{0}] of type [{1}] from resource group [{2}]" -f  $resource.Name,  $resource.ResourceType,  $resource.ResourceGroupName)
            }
        }
        catch {
            Write-Warning ("Removal moved back for re-try. Reason: [{0}]" -f $_.Exception.Message)
            $resourcesToRetry += $resource
        }
    }
    Write-Verbose "----------------------------------"
    return $resourcesToRetry
}