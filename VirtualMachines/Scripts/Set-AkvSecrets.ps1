<#
	.NOTES
		==============================================================================================
		Copyright(c) Microsoft Corporation. All rights reserved.

		File:		Set-AkvSecrets.ps1

		Purpose:	Set Virtual Machines Key Secrets

		Version: 	3.0.0.0 - 1st November 2020
		==============================================================================================

		DISCLAIMER
		==============================================================================================
		This script is not supported under any Microsoft standard support program or service.

		This script is provided AS IS without warranty of any kind.
		Microsoft further disclaims all implied warranties including, without limitation, any
		implied warranties of merchantability or of fitness for a particular purpose.

		The entire risk arising out of the use or performance of the script
		and documentation remains with you. In no event shall Microsoft, its authors,
		or anyone else involved in the creation, production, or delivery of the
		script be liable for any damages whatsoever (including, without limitation,
		damages for loss of business profits, business interruption, loss of business
		information, or other pecuniary loss) arising out of the use of or inability
		to use the sample scripts or documentation, even if Microsoft has been
		advised of the possibility of such damages.

		IMPORTANT
		==============================================================================================
		This script uses or is used to either create or sets passwords and secrets.
		All coded passwords or secrests supplied from input files must be created and provided by the customer.
		Ensure all passwords used by any script are generated and provided by the customer
		==============================================================================================

	.SYNOPSIS
		Set Virtual Machines Key Secrets.

	.DESCRIPTION
		Set Virtual Machines Key Secrets.

		Deployment steps of the script are outlined below.
		1) Set Azure KeyVault Parameters
		2) Set Virtual Machines Parameters
		3) Create Azure KeyVault Secret

	.PARAMETER keyVaultName
		Specify the Azure KeyVault Name parameter.

	.PARAMETER vmNames
		Specify the Virtual Machines Name output parameter.

	.PARAMETER vmResourceIds
		Specify the Virtual Machines ResourceId output parameter.

	.PARAMETER vmResourceGroup
		Specify the Virtual Machines ResourceGroup output parameter.

	.EXAMPLE
		Default:
		C:\PS>.\Set-AkvSecrets.ps1
			-keyVaultName "$(keyVaultName)"
			-vmNames "$(vmNames)"
			-vmResourceIds "$(vmResourceIds)"
			-vmResourceGroup "$(vmResourceGroup)"
#>

#Requires -Module Az.KeyVault

[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true)]
	[string]$keyVaultName,

	[Parameter(Mandatory = $false)]
	[string]$vmNames,

	[Parameter(Mandatory = $false)]
	[string]$vmResourceIds,

	[Parameter(Mandatory = $false)]
	[string]$vmResourceGroup
)

#region - KeyVault Parameters
if (-not [string]::IsNullOrWhiteSpace($PSBoundParameters['keyVaultName']))
{
	Write-Output "KeyVault Name: $keyVaultName"
	$kvSecretParameters = @{ }

	#region - Virtual Machines Parameters
<#
	if (-not [string]::IsNullOrWhiteSpace($PSBoundParameters['vmNames']))
	{
		Write-Output "Virtual Machines Name: $vmNames"
		$kvSecretParameters.Add("VM-Name-$($vmNames)", $($vmNames))
	}
	else
	{
		Write-Output "Virtual Machines Name: []"
	}

	if (-not [string]::IsNullOrWhiteSpace($PSBoundParameters['vmResourceIds']))
	{
		Write-Output "Virtual Machines ResourceId: $vmResourceIds"
		$kvSecretParameters.Add("VM-ResourceId-$($vmNames)", $($vmResourceIds))
	}
	else
	{
		Write-Output "Virtual Machines ResourceId: []"
	}

	if (-not [string]::IsNullOrWhiteSpace($PSBoundParameters['vmResourceGroup']))
	{
		Write-Output "Virtual Machines ResourceGroup: $vmResourceGroup"
		$kvSecretParameters.Add("VM-ResourceGroup-$($vmNames)", $($vmResourceGroup))
	}
	else
	{
		Write-Output "Virtual Machines ResourceGroup: []"
	}
	#endregion
#>
	#region - Set Azure KeyVault Secret
	$kvSecretParameters.Keys | ForEach-Object {
		$key = $psitem
		$value = $kvSecretParameters.Item($psitem)

		if (-not [string]::IsNullOrWhiteSpace($value))
		{
			Write-Output "KeyVault Secret: $key : $value"
			$value = $kvSecretParameters.Item($psitem)
			$paramSetAzKeyVaultSecret = @{
				VaultName   = $keyVaultName
				Name        = $key
				SecretValue = (ConvertTo-SecureString $value -AsPlainText -Force)
				Verbose     = $true
			}
			Set-AzKeyVaultSecret @paramSetAzKeyVaultSecret
		}
		else
		{
			Write-Output "KeyVault Secret: $key - []"
		}
	}
	#endregion
}
else
{
	Write-Output "KeyVault Name: []"
}
#endregion