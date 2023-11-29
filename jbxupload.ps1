# License: MIT
# Copyright Joe Security 2023

<#
jbxupload.ps1 servers as un upload script for Joe Sandbox.
#>
function ReadAllBytes {
	param(
        [string]$file_path
    )
	return [System.IO.File]::ReadAllBytes($file_path)
}

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

.EXAMPLE
    SubmitFileToJoeSandbox -file_path "C:\path\to\file.exe" -api_key "your-api-key-here" -accept_tac $True

    This example submits "file.exe" to Joe Sandbox for analysis, using the specified API key and indicating acceptance of the Terms and Conditions.

.NOTES
    Ensure that the API key is valid and that the file path points to a legitimate file for analysis.
#>
function SubmitFileToJoeSandbox {
    param(
        [string]$file_path, 
		[string]$api_key, 
		[boolean]$accept_tac
    )

    if (-not $file_path) {
        throw "Please provide the file path."
    }
	
	 if (-not $api_key) {
        throw "Please provide the API key."
    }
	
	$accept_tac_int = 0;
	
	if($accept_tac)
	{
		$accept_tac_int = 1;
	}

	Write-Host "Submitting Sample $file_path to Joe Sandbox";

	# Joe Sandbox API URL, change for on-premise
	$url = "https://jbxcloud.joesecurity.org";
	
	$boundary = [System.Guid]::NewGuid().ToString();
	$file_name = Split-Path -Path $file_path -Leaf

	# Using default values, for all check https://jbxcloud.joesecurity.org/userguide?sphinxurl=usage/webapi.html#v2-submission-new
	$LF = "`r`n";
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
	) -join $LF;

	$response = Invoke-RestMethod -UserAgent $USER_AGENT -Uri ($url + "/api/v2/submission/new") -Method Post -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $bodyLines;
	
	$submission_id = $response.data.submission_id
	
	# Define the chunk size in bytes
	$chunkSize = 10 * 1024 * 1024

	# Read the file in chunks
	$fileBytes = ReadAllBytes($file_path)
	$chunkCount = [math]::Ceiling($fileBytes.Length / $chunkSize)
	$fileSize = $fileBytes.Length
	
	for ($i = 0; $i -lt $chunkCount; $i++) {
		$start = $i * $chunkSize
		$end = [math]::Min(($i + 1) * $chunkSize, $fileBytes.Length)
		$currentChunkSize = $end - $start
		$currentChunk = New-Object byte[] $currentChunkSize
		[Array]::Copy($fileBytes, $start, $currentChunk, 0, $currentChunkSize)
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
		$chunkResponse = Invoke-RestMethod -UserAgent $USER_AGENT -Uri ($url + "/api/v2/submission/chunked-sample") -Method Post -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $chunkBodyLines

	}
	
	Write-Host "Successfully submitted: $submission_id"

}

# Initialize parameters with default values
$FilePath = $null
$ApiKey = $null
$AcceptTAC = $null

# Parse arguments
foreach ($arg in $args) {
    if ($arg -match "^\-FilePath=(.*)") {
        $FilePath = $matches[1]
    } elseif ($arg -match "^\-ApiKey=(.*)") {
        $ApiKey = $matches[1]
    } elseif ($arg -match "^\-AcceptTAC=(.*)") {
        $AcceptTAC = [System.Convert]::ToBoolean($matches[1])
    }
}

# Show help if requested or if mandatory parameters are missing
if ($args -contains "-Help" -or $args -contains "/?" -or -not $FilePath -or -not $ApiKey -or $AcceptTAC -eq $null) {
    Write-Host "SubmitFileToJoeSandbox PowerShell Script"
    Write-Host "Usage: .\SubmitFileToJoeSandbox.ps1 -FilePath=<String> -ApiKey=<String> -AcceptTAC=<Boolean>"
    Write-Host "Example: .\SubmitFileToJoeSandbox.ps1 -FilePath='C:\path\to\file.exe' -ApiKey='your-api-key' -AcceptTAC=True"
    Write-Host "Parameters:"
    Write-Host "  -FilePath: The full local path to the file to be submitted."
    Write-Host "  -ApiKey: The API key for Joe Sandbox authentication."
    Write-Host "  -AcceptTAC: Acceptance of the Terms and Conditions."
    exit
}

# Proceed with the function call
try {
    SubmitFileToJoeSandbox -file_path $FilePath -api_key $ApiKey -accept_tac $AcceptTAC
}
catch {
    Write-Host "Error occurred: $_"
}