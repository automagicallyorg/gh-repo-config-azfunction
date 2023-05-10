using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

$orgName = "automagicallyorg"
$protectedBranch = "main"
$Request = $Request.Body
$action  = $Request.action
$branch  = $Request.rule.name
Write-Host "Action Type:" $Request.action
Write-Host "Repository Name:" $Request.repository.name
Write-Host "Private Repository:" $Request.repository.private
Write-Host "Rule id:" $Request.rule.id
Write-Host "Protected branch name:" $Request.rule.name

# Header for GitHub API
$ghToken = $env:ghToken
# $ghTokenDecoded =  [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String( $env:ghToken))
Write-Host "ghToken:" $ghToken
# Write-Host "ghToken decoded:" $ghTokenDecoded

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Accept", "application/vnd.github+json")
$headers.Add("Authorization", "Bearer $ghToken")
$headers.Add("X-GitHub-Api-Version", "2022-11-28")
$headers.Add("Content-Type", "application/json")

$ghRepoName = $Request.repository.name

function ConfigureBranchProtection {
    $bodyConfigureProtection = "{
    `n    `"required_status_checks`": null,
    `n    `"enforce_admins`": true,
    `n    `"required_conversation_resolution`": true,
    `n    `"required_linear_history`": true,
    `n    `"required_pull_request_reviews`": {
    `n        `"dismissal_restrictions`": {},
    `n        `"dismiss_stale_reviews`": true,
    `n        `"require_code_owner_reviews`": true,
    `n        `"require_last_push_approval`": true,
    `n        `"required_approving_review_count`": 1
    `n    },
    `n    `"restrictions`": null
    `n}"
    
    $response = Invoke-RestMethod "https://api.github.com/repos/$orgName/$ghRepoName/branches/$protectedBranch/protection" -Method 'PUT' -Headers $headers -Body $bodyConfigureProtection
    $response | ConvertTo-Json
}

function AddReadMe {
    $bodyReadMe = "{
    `n  `"branch`": `"main`",
    `n  `"message`": `"add README`",
    `n  `"content`": `"QWRkIHNvbWUgbWVhbmluZ2Z1bCBkZXNjcmlwdGlvbiBwbGVhc2UuIEl0IHdpbGwgaGVscCB5b3UgbGF0ZXIu`"
    `n}"

    $response = Invoke-RestMethod "https://api.github.com/repos/$orgName/$ghRepoName/contents/README.md" -Method 'PUT' -Headers $headers -Body $bodyReadMe
    $response | ConvertTo-Json
}

# configure branch protection rules when repo created
if ($action -eq "created")
{
    try {
        Write-Host "Configuring branch protection"
        ConfigureBranchProtection
    }
    catch {
        Write-Host "No branches exist, creating init commit to initialize branch."
        AddReadMe
        ConfigureBranchProtection
    }
    finally {
        Write-Host "Branch protection configured"
    }
}

# enforce branch protection rules when updated manually
if(  ( ($action -eq "edited") -or ($action -eq "deleted") ) -and ($branch -eq $protectedBranch) )
{
    try {
        Write-Host "Enforcing branch protection"
        ConfigureBranchProtection
    }
    catch {
        Write-Host "EXCEPTION OCCURRED!"
        Write-Host $_.Exception.Message
        Write-Host "JSON RESPONSE:"
        Write-Host ($_ | ConvertTo-Json)
        Write-Host "STRING RESPONSE:"
        $_ | Format-List * -Force | Out-String
    }
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $Request
})
