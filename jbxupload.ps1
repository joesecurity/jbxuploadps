# License: MIT
# Copyright Joe Security 2023

<#
jbxupload.ps1 servers as un upload script for Joe Sandbox.
#>

<#
.SYNOPSIS
    Submits a file to Joe Sandbox for malware analysis.

.DESCRIPTION
    This PowerShell function automates the submission of a file to Joe Sandbox, a service for analyzing files for potential malware. It's used in cybersecurity contexts for automated threat analysis.

.PARAMETER file_path
    The full local path to the file that needs to be submitted. 
    Example: "C:\path\to\file.exe"

.PARAMETER api_key
    The API key for Joe Sandbox authentication. 
    This is essential for utilizing the Joe Sandbox API for file submissions.
    Example: "your-api-key-here"

.PARAMETER accept_tac
    A boolean parameter indicating whether the user accepts the Terms and Conditions of Joe Sandbox at https://jbxcloud.joesecurity.org/tandc. 
    This is often required for API usage. 
    Acceptable values: True or False
	
.PARAMETER api_url
    The URL to the Joe Sandbox Web interface, defaults to https://jbxcloud.joesecurity.org.
    Acceptable values: "http URL"

.EXAMPLE
    SubmitFileToJoeSandbox -file_path "C:\path\to\file.exe" -api_key "your-api-key-here" -accept_tac $True

    This example submits "file.exe" to Joe Sandbox for analysis, using the specified API key and indicating acceptance of the Terms and Conditions.
#>
function SubmitFileToJoeSandbox {
    param(
        [string]$file_path, 
		[string]$api_key, 
		[boolean]$accept_tac,
		[string]$api_url
    )

    if (-not $file_path) {
        throw "Please provide the file path."
    }
	
	if (-not (Test-Path $filePath)) 
	{
		throw "File $filePath does not exist."
	}

	if (-not $api_key) {
        throw "Please provide the API key."
    }
	
	$accept_tac_int = 0
	
	if($accept_tac)
	{
		$accept_tac_int = 1
	}

	Write-Host "Submitting Sample $file_path to Joe Sandbox";

	if ($api_url -eq "$null" -or $api_url -eq $null -or $api_url -eq "") 
	{
		$api_url = "https://jbxcloud.joesecurity.org"
	}
	
	$boundary = [System.Guid]::NewGuid().ToString()
	$file_name = Split-Path -Path $file_path -Leaf

	# Using default values, for all check https://jbxcloud.joesecurity.org/userguide?sphinxurl=usage/webapi.html#v2-submission-new
	$LF = "`r`n"
	$bodyLines = (
		"--$boundary",
		"Content-Disposition: form-data; name=`"accept-tac`"$LF",
		"$accept_tac_int",
		"--$boundary",
		"Content-Disposition: form-data; name=`"apikey`"$LF",
		"$api_key",
		"--$boundary",
		"Content-Disposition: form-data; name=`"chunked-sample`"$LF",
		"$file_name",
		"--$boundary--$LF"
	) -join $LF

	$response = Invoke-RestMethod -UserAgent $USER_AGENT -Uri ($api_url + "/api/v2/submission/new") -Method Post -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $bodyLines;
	
	$responseJSON = $response | ConvertTo-Json
	
	$submission_id = $response.data.submission_id
	
	# Define the chunk size in bytes
	$chunkSize = 10 * 1024 * 1024
	
	try
	{
		$fileStream = [System.IO.FileStream]::new($filePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)

		# Read the file in chunks
		$chunkCount = [math]::Ceiling($fileStream.Length / $chunkSize)
		$fileSize = $fileStream.Length
		
		for ($i = 0; $i -lt $chunkCount; $i++) {
			$start = $i * $chunkSize
			$end = [math]::Min(($i + 1) * $chunkSize, $fileStream.Length)
			$currentChunkSize = $end - $start
			$currentChunk = New-Object byte[] $currentChunkSize
			
			$r = $fileStream.Seek($start, [System.IO.SeekOrigin]::Begin)
			$r = $fileStream.Read($currentChunk, 0, $currentChunkSize)
			$currentChunk = [System.Text.Encoding]::GetEncoding('iso-8859-1').GetString($currentChunk)
			
			$chunkIndex = $i + 1
			
			# Prepare the body for chunk upload
			$chunkBodyLines = (
				"--$boundary",
				"Content-Disposition: form-data; name=`"apikey`"$LF",
				"$API_KEY",
				"--$boundary",
				"Content-Disposition: form-data; name=`"submission_id`"$LF",
				"$submission_id",
				"--$boundary",
				"Content-Disposition: form-data; name=`"file-size`"$LF",
				"$fileSize",
				"--$boundary",
				"Content-Disposition: form-data; name=`"chunk-size`"$LF",
				"$chunkSize",
				"--$boundary",
				"Content-Disposition: form-data; name=`"chunk-count`"$LF",
				"$chunkCount",
				"--$boundary",
				"Content-Disposition: form-data; name=`"current-chunk-index`"$LF",
				"$chunkIndex",
				"--$boundary",
				"Content-Disposition: form-data; name=`"current-chunk-size`"$LF",
				"$currentChunkSize",
				"--$boundary",
				"Content-Disposition: form-data; name=`"chunk`"; filename=`"$file_name`"",
				"Content-Type: application/octet-stream$LF",
				$currentChunk,
				"--$boundary--$LF"
			) -join $LF
			
			# Upload the chunk
			$chunkResponse = Invoke-RestMethod -UserAgent $USER_AGENT -Uri ($api_url + "/api/v2/submission/chunked-sample") -Method Post -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $chunkBodyLines
			
		}
		
		return $responseJSON

	} finally
	{
		$fileStream.Dispose()
	}
	
	return ""

}

# Initialize parameters with default values
$FilePath = $null
$ApiKey = $null
$AcceptTAC = $null
$ApiUrl = $null 

# Parse arguments
foreach ($arg in $args) {
    if ($arg -match "^\-FilePath=(.*)") {
        $FilePath = $matches[1]
    } elseif ($arg -match "^\-ApiKey=(.*)") {
        $ApiKey = $matches[1]
    } elseif ($arg -match "^\-AcceptTAC=(.*)") {
        $AcceptTAC = [System.Convert]::ToBoolean($matches[1])
    } elseif ($arg -match "^\-ApiUrl=(.*)") {
        $ApiUrl = $matches[1]
    }
}

# Show help if requested or if mandatory parameters are missing
if ($args -contains "-Help" -or $args -contains "/?" -or -not $FilePath -or -not $ApiKey -or $AcceptTAC -eq $null) {
    Write-Host "SubmitFileToJoeSandbox PowerShell Script"
    Write-Host "Usage: .\SubmitFileToJoeSandbox.ps1 -FilePath=<String> -ApiKey=<String> -AcceptTAC=<Boolean> [-ApiUrl=<String>]"
    Write-Host "Example: .\SubmitFileToJoeSandbox.ps1 -FilePath='C:\path\to\file.exe' -ApiKey='your-api-key' -AcceptTAC=$True -ApiUrl='https://youronpremiseinstance.com'"
    Write-Host "Parameters:"
    Write-Host "  -FilePath: The full local path to the file to be submitted."
    Write-Host "  -ApiKey: The API key for Joe Sandbox authentication."
    Write-Host "  -AcceptTAC: Acceptance of the Terms and Conditions."
    Write-Host "  -ApiUrl: Optional. The URL of the Joe Sandbox Web Interface."
    exit
}

try {
    $response = SubmitFileToJoeSandbox -file_path $FilePath -api_key $ApiKey -accept_tac $AcceptTAC -api_url $ApiUrl
	Write-Host $response
}
catch {
    Write-Host "Error occurred: $_"
}