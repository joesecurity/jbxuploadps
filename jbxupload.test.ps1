BeforeAll {
    Import-Module .\jbxupload.ps1 -Force
}

Describe "Joe Sandbox File Upload Tests" {

    It "Check Single Chunk" {
        
        $script:capturedBodies = @()
        
        Mock Invoke-RestMethod -ParameterFilter { $Body } { $script:capturedBodies += $Body; return @{ data = @{ submission_id = "12345" } } } 
        Mock ReadAllBytes { return New-Object Byte[] 1000 }
        
        SubmitFileToJoeSandbox -file_path "C:\test" -api_key "1234"

        Assert-MockCalled Invoke-RestMethod -Times 2 -Exactly
        
        $script:capturedBodies[0] | Should -Match "name=`"apikey`"`r`n`r`n1234`r"
        $script:capturedBodies[0] | Should -Match "name=`"accept-tac`"`r`n`r`n1`r"
        $script:capturedBodies[0] | Should -Match "name=`"chunked-sample`"`r`n`r`ntest`r"
    
        $script:capturedBodies[1] | Should -Match "name=`"apikey`"`r`n`r`n1234`r"
        $script:capturedBodies[1] | Should -Match "name=`"file-size`"`r`n`r`n1000`r"
        $script:capturedBodies[1] | Should -Match "name=`"chunk-size`"`r`n`r`n10485760`r"
        $script:capturedBodies[1] | Should -Match "name=`"chunk-count`"`r`n`r`n1`r"
        $script:capturedBodies[1] | Should -Match "name=`"current-chunk-index`"`r`n`r`n1`r"
        $script:capturedBodies[1] | Should -Match "name=`"current-chunk-size`"`r`n`r`n1000`r"
        $script:capturedBodies[1] | Should -Match "name=`"chunk`"; filename=`"test`""
    }
    
    It "Check Multiple Chunk" {
        
        $script:capturedBodies = @()
        
        Mock Invoke-RestMethod -ParameterFilter { $Body } { $script:capturedBodies += $Body; return @{ data = @{ submission_id = "12345" } } } 
        Mock ReadAllBytes { return New-Object Byte[] 123456789 }
        
        SubmitFileToJoeSandbox -file_path "C:\test" -api_key "1234"

        Assert-MockCalled Invoke-RestMethod -Times 13 -Exactly
        
        $final = 123456789 - 11 * 10485760
        
        $script:capturedBodies[0] | Should -Match "name=`"apikey`"`r`n`r`n1234`r"
        $script:capturedBodies[0] | Should -Match "name=`"accept-tac`"`r`n`r`n1`r"
        $script:capturedBodies[0] | Should -Match "name=`"chunked-sample`"`r`n`r`ntest`r"
    
        $script:capturedBodies[1] | Should -Match "name=`"apikey`"`r`n`r`n1234`r"
        $script:capturedBodies[1] | Should -Match "name=`"file-size`"`r`n`r`n123456789`r"
        $script:capturedBodies[1] | Should -Match "name=`"chunk-size`"`r`n`r`n10485760`r"
        $script:capturedBodies[1] | Should -Match "name=`"chunk-count`"`r`n`r`n12`r"
        $script:capturedBodies[1] | Should -Match "name=`"current-chunk-index`"`r`n`r`n1`r"
        $script:capturedBodies[1] | Should -Match "name=`"current-chunk-size`"`r`n`r`n10485760`r"
        $script:capturedBodies[1] | Should -Match "name=`"chunk`"; filename=`"test`""
        
        $script:capturedBodies[12] | Should -Match "name=`"apikey`"`r`n`r`n1234`r"
        $script:capturedBodies[12] | Should -Match "name=`"file-size`"`r`n`r`n123456789`r"
        $script:capturedBodies[12] | Should -Match "name=`"chunk-size`"`r`n`r`n10485760`r"
        $script:capturedBodies[12] | Should -Match "name=`"chunk-count`"`r`n`r`n12`r"
        $script:capturedBodies[12] | Should -Match "name=`"current-chunk-index`"`r`n`r`n12`r"
        $script:capturedBodies[12] | Should -Match "name=`"current-chunk-size`"`r`n`r`n$final`r"
        $script:capturedBodies[12] | Should -Match "name=`"chunk`"; filename=`"test`""
    }
    

}
