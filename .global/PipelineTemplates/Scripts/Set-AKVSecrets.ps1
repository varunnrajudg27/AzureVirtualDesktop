<#
.SYNOPSIS
Inject JSON deployment Outputs as secrets into Azure Key Vault

.DESCRIPTION
Inject JSON deployment Outputs as secrets into Azure Key Vault

.PARAMETER KeyVaultName
Mandatory. The name of the Key Vault to inject the secrets

.PARAMETER SecretName
Mandatory. The name of the secret key

.PARAMETER SecretValue
Mandatory. The name of the secret value

.PARAMETER ContentType
Mandatory. The name of the label identitying the pipeline as its source of creation

.EXAMPLE
CreateKeyVaultSecret -KeyVaultName $KeyVaultName -SecretName $SecretName -SecretValue $SecretValue
#>

Function CreateKeyVaultSecret {
    Param (
        [Parameter(Mandatory)]
        $KeyVaultName,

        [Parameter(Mandatory)]
        $SecretName,

        [Parameter(Mandatory)]
        $SecretValue,

        [Parameter(Mandatory = $false)]
        $ContentType = "PipelineInjected"
    ) 

    if ($SecretValue.GetType().Name -ne "SecureString") {
        $SecretValue = ConvertTo-SecureString $SecretValue -AsPlainText -Force
    }

    $Parameters = @{
        VaultName   = $keyVaultName
        Name        = $SecretName
        SecretValue = $SecretValue
        ContentType = $ContentType
    }

    Write-Host "INFO: Processing Output - $($SecretName)"
    Write-Host "##vso[task.setvariable variable=$SecretName]$SecretValue" #Makes Value visible to subsequent pipeline tasks
    New-Variable -Scope Global -Name $SecretName -Value "$SecretValue" -Force #Makes Value availble as a variable in current script 
    Set-AzKeyVaultSecret @Parameters -Verbose

}


Function InjectDeploymentOutputs {
    Param (
        [Parameter(Mandatory)]
        $KeyVaultName,

        [Parameter(Mandatory)]
        $ModuleName,

        [Parameter(Mandatory)]
        $ArmOutputs
    ) 

    if ($armOutputs) {
        $resName = $modulename + "Name"
        $resourceNameSegment = $armOutputs.$resName.value 
        Write-Host "INFO: Processing resourceNameSegment Output - $($resourceNameSegment)"

        $resId = $modulename + "ResourceId"                      
        $resourceIdSegment = $armOutputs.$resId.value 
        Write-Host "INFO: Processing resourceIdSegment Output - $($resourceIdSegment)"

        $resRG = $modulename + "ResourceGroup"                      
        $resourceRGSegment = $armOutputs.$resRG.value 
        Write-Host "INFO: Processing resourceRGSegment Output - $($resourceRGSegment)"

        if ($armOutputs.$resName.type -eq "Array") {
            $formatName = $armOutputs.$resName.value -replace('[\[\]]') -replace('["]') -replace('\s+', '')
            $arrayName = $formatName.split(",")
            $formatId = $armOutputs.$resId.value -replace('[\[\]]') -replace('["]') -replace('\s+', '')
            $arrayId = $formatId.split(",")
            $counter = 0
            foreach ($item in $arrayName) {
                $SecretName = $resName + "-" + $item
                $SecretValue = $item
                CreateKeyVaultSecret -KeyVaultName $KeyVaultName -SecretName $SecretName -SecretValue $SecretValue

                $SecretName = $resId + "-" + $item
                $SecretValue = $arrayId[$counter]
                $counter ++
                CreateKeyVaultSecret -KeyVaultName $KeyVaultName -SecretName $SecretName -SecretValue $SecretValue

                $SecretName = $resRG + "-" + $item
                $SecretValue = $resourceRGSegment
                CreateKeyVaultSecret -KeyVaultName $KeyVaultName -SecretName $SecretName -SecretValue $SecretValue
            }
        } 
        else {
            $SecretName = $resName + "-" + $resourceNameSegment
            $SecretValue = $resourceNameSegment
            CreateKeyVaultSecret -KeyVaultName $KeyVaultName -SecretName $SecretName -SecretValue $SecretValue

            $SecretName = $resId + "-" + $resourceNameSegment
            $SecretValue = $resourceIdSegment
            CreateKeyVaultSecret -KeyVaultName $KeyVaultName -SecretName $SecretName -SecretValue $SecretValue

            $SecretName = $resRG + "-" + $resourceNameSegment
            $SecretValue = $resourceRGSegment
            CreateKeyVaultSecret -KeyVaultName $KeyVaultName -SecretName $SecretName -SecretValue $SecretValue
        } 

        $otherOutputs = $armOutputs.PSObject.Properties | Where-Object {$_.Name -ne "$resName" -and $_.Name -ne "$resId" -and $_.Name -ne "$resRG"} 

        foreach ($output in $otherOutputs) {
            if ($output.value.type -eq "Array") {
                foreach ($arrayobj in $output.value.value) {
                    $string = $arrayobj -replace('[\[\]]') -replace('["]') -replace('\s+', '')
                    $array = $string.split(",")
                    foreach ($item in $array) {

                        if ($armOutputs.$resName.type -eq "Array") {
                            $jointName = $armOutputs.$resName.value -replace('[\[\]]') -replace('["]') -replace('\s+', '') -replace('[,]')
                            $SecretName = $output.name + "-" + $jointName
                        }
                        else {
                            $SecretName = $output.name + "-" + $resourceNameSegment
                        }
                        $SecretValue = $item
                        CreateKeyVaultSecret -KeyVaultName $KeyVaultName -SecretName $SecretName -SecretValue $SecretValue
                    }
                }
            }
            elseif ($output.value.type -eq "String") {
                if ($output.value.value -ne "") {
                    if ($armOutputs.$resName.type -eq "Array") {
                        $jointName = $armOutputs.$resName.value -replace('[\[\]]') -replace('["]') -replace('\s+', '') -replace('[,]')
                        $SecretName = $output.name + "-" + $jointName
                    }
                    else {
                        $SecretName = $output.name + "-" + $resourceNameSegment
                    }                                        
                    $SecretValue = $output.Value.value
                    CreateKeyVaultSecret -KeyVaultName $KeyVaultName -SecretName $SecretName -SecretValue $SecretValue
                }
            }  
        }
    Write-Host "INFO: Finished Processing Deployment Outputs"
    }

}