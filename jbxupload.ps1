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

function SubmitFileToJoeSandbox {
    param(
        [string]$file_path, [string]$api_key
    )

    if (-not $file_path) {
        throw "Please provide the file path."
    }
	
	 if (-not $api_key) {
        throw "Please provide the API key."
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
		"1",
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

$API_KEY = "<TOBESET>";

try {
    SubmitFileToJoeSandbox -file_path $args[0] -api_key $API_KEY
}
catch {
    Write-Host "Error occurred: $_"
}






