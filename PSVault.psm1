param(
	[string]$vaultFile = "$($Env:USERPROFILE)\.psvault"
)

#import-module C:\Users\Anonymous\go\src\github.com\mcfly722\PSVault\psvault.psm1
#Add-ToVault -name 'git push to myrepository.biz' -exeTool 'C:\Program Files\Git\bin\git.exe' -includeForParameters $('push',"pop") -parametersToEncrypt $('https://username:password@myrepository.biz/file.git')


Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Windows.Forms

function encryptWithCertificate {
	param($sensitiveData, [System.Security.Cryptography.X509Certificates.X509Certificate2]$encryptionCertificate)
	$encryptedBytes = [system.convert]::ToBase64String($cert.PublicKey.Key.Encrypt([system.text.encoding]::UTF8.GetBytes($sensitiveData), $true))
}


function addToVault {
	param(
		[String]$name,
		[String]$exeTool,
		[String[]]$includeForParameters,
		[String[]]$excludeForParameters,
		[System.Security.Cryptography.X509Certificates.X509Certificate2]$encryptionCertificate
	)
	
	
}

function Add-ToVault{
	<#
	.Synopsis
	Add new sensitive parameters to current encrypted vault

	.Description
	Cmdlet adds new sensitive credential parameters to current encrypted vault
	
	.Parameter name
	Credentials name
	
	.Parameter exeTool
	Full path to exe tool, which have no safe method to store it passwords (ansible/git/kubectl/etc...)
	
	.Parameter includeForParameters
	To be able to use new credentials, all inputted parameters should match with all this filters.
	
	.Parameter excludeForParameters
	If one of this filters have match with inputted paramenters, this credentials are not applyed to case.
	
	.Parameter parametersToEncrypt
	Sensitive parameters which would be added at the end of final command.
	(passwords/tokens/bareers etc.)
	
	.Parameter encryptionCertificate
	Certificate to sensitive paramenters.
	If it not specified, cmdlet will ask it from certificates select list.

	.Example
	
	Add-ToVault -name 'git push to myrepository.biz' -exeTool 'C:\Program Files\Git\bin\git.exe' -includeForParameters $('push') -parametersToEncrypt $('https://username:password@myrepository.biz/file.git')

#>
	param(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$name,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)][AllowEmptyString()][String]$exeTool,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)][AllowEmptyString()][String[]]$includeForParameters,
		[Parameter(Mandatory=$false,ValueFromPipeline=$false)][AllowEmptyString()][String[]]$excludeForParameters,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)][String[]]$parametersToEncrypt,
		[Parameter(Mandatory=$false,ValueFromPipeline=$true)][System.Security.Cryptography.X509Certificates.X509Certificate2]$encryptionCertificate
	)

	BEGIN { 
		$ErrorActionPreference = "Stop"

		
		if ([string]::IsNullOrEmpty($exeTool)){
			
			$dialogProperties = @{
				'InitialDirectory' = [Environment]::GetFolderPath('Desktop');
				'Filter' = 'exe files (*.exe)|*.exe|All files (*.*)|*.*'
			}
			
			$fileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property $dialogProperties
			$null = $fileBrowser.ShowDialog()
			
			$exeTool = $fileBrowser.FileName
		}
		
		if (!(Test-Path $exeTool)) {
			throw "file '$exeTool' not found"
		}
		
		if ([string]::IsNullOrEmpty($encryptionCertificate)){
			$msg = "select certificate to encrypt your additional parameters"
			$collection = new-object -type System.Security.Cryptography.X509Certificates.X509Certificate2Collection
			Get-ChildItem -Path Cert:\CurrentUser\My | % {$collection.add($_) > $null}
			$msg
			
			$selected = [System.Security.Cryptography.X509Certificates.X509Certificate2UI]::SelectFromCollection($collection,
				"Certificate Select",
				$msg,
				[System.Security.Cryptography.X509Certificates.X509SelectionFlag]::SingleSelection
			)

			if (!([string]::IsNullOrEmpty($selected))){
				$encryptionCertificate = $selected[0]
			}

			$encryptionCertificate
		}

		#$vault = get-content $vaultFile | convertFrom-JSON
		$credentials = Get-VaultCredentials

		$sensitiveData = $parametersToEncrypt | convertTo-JSON -compress

		if ([string]::IsNullOrEmpty($excludeForParameters)) {
			$excludeForParameters=@()
		}

		$newRecord = @{
			'name'=$name;
			'exeTool'=$exeTool;
			'includeForParameters'=@($includeForParameters);
			'excludeForParameters'=@($excludeForParameters);
			'encryptedParameters'= [system.convert]::ToBase64String($encryptionCertificate.PublicKey.Key.Encrypt([system.text.encoding]::UTF8.GetBytes($sensitiveData), $true));
			'thumbprint'=$encryptionCertificate.Thumbprint
		}

		$newRecordCompressedString = $newRecord | convertTo-JSON -compress
		
		#$newRecord | convertTo-JSON | write-host
		#write-host "signing with cert=$($encryptionCertificate.Thumbprint)"	

		$signature = [Convert]::ToBase64String($encryptionCertificate.PrivateKey.SignData([System.Text.Encoding]::UTF8.GetBytes($newRecordCompressedString),'SHA512'))
		
		$newRecord["signature"] = $signature

		$credentials = @($credentials) + $newRecord

		Save-VaultCredentials $credentials
		
	}
	PROCESS {}        
	END {}
}

Export-ModuleMember -Function Add-ToVault -Cmdlet "Add-ToVault" -Alias "Add-ToVault"

function Get-VaultCredentials {
	$vault = get-content $vaultFile | convertFrom-JSON
	$vault.Credentials
}

Export-ModuleMember -Function Get-VaultCredentials -Cmdlet "Get-VaultCredentials" -Alias "Get-VaultCredentials"

function Save-VaultCredentials {
	param($credentials)

	if ([string]::IsNullOrEmpty($credentials)){
		$credentials = @()
	}
	@{"Credentials"=$credentials} | convertTo-JSON -Depth 5 > $vaultFile
}

function Remove-FromVault {
	PROCESS {
		$signature = $_.signature
		
		$credentials = Get-VaultCredentials

		$updatedCredentials = $credentials | ? {-not($_.signature -like $signature)}
		
		Save-VaultCredentials $updatedCredentials
	}

}

Export-ModuleMember -Function Remove-FromVault -Cmdlet "Remove-FromVault" -Alias "Remove-FromVault"


$credentials = Get-VaultCredentials

$grouped = $credentials | group-object {($_.exeTool | dir).baseName} -asHashTable -asString

#get-process | out-gridview -Title "select authentication method" -OutputMode Single
