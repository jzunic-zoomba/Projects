# Set environment variables or replace with actual values
$bandwidthUser = $env:BANDWIDTH_API_USER
$bandwidthPass = $env:BANDWIDTH_API_PASS
$bandwidthAccountId = $env:BANDWIDTH_ACCOUNT_ID
$haloApiKey = $env:HALO_API_KEY
$haloBaseUrl = $env:HALO_BASE_URL

# Map Bandwidth customer IDs to Halo customer IDs
$customerMap = @{
    "customer1" = 1234
    "customer2" = 5678
}

function Get-DIDCountFromBandwidth($customerId) {
    $url = "https://api.bandwidth.com/api/accounts/$bandwidthAccountId/customers/$customerId/dids"
    $response = Invoke-RestMethod -Uri $url -Method Get -Credential (New-Object System.Management.Automation.PSCredential($bandwidthUser, (ConvertTo-SecureString $bandwidthPass -AsPlainText -Force)))
    return $response.Count
}

function Update-HaloCustomer($haloCustomerId, $didCount) {
    $url = "$haloBaseUrl/api/Client/$haloCustomerId"
    $headers = @{
        "ApiKey" = $haloApiKey
        "Content-Type" = "application/json"
    }
    $body = @{
        id = $haloCustomerId
        customFields = @{
            CFdidCount = $didCount
        }
    } | ConvertTo-Json -Depth 3

    Invoke-RestMethod -Uri $url -Method Put -Headers $headers -Body $body
}

foreach ($entry in $customerMap.GetEnumerator()) {
    $didCount = Get-DIDCountFromBandwidth $entry.Key
    if ($didCount -ne $null) {
        Update-HaloCustomer $entry.Value $didCount
        Write-Host "Updated Halo customer $($entry.Value) with DID count $didCount"
    } else {
        Write-Warning "Failed to retrieve DIDs for Bandwidth customer $($entry.Key)"
    }
}
