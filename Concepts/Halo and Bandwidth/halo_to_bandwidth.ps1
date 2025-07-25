# Sets environment variables or securely load credentials
$bandwidthUser = $env:BANDWIDTH_API_USER           # Bandwidth API username
$bandwidthPass = $env:BANDWIDTH_API_PASS           # Bandwidth API password
$bandwidthAccountId = $env:BANDWIDTH_ACCOUNT_ID    # Bandwidth account ID

$haloClientId = "<REDACTED_CLIENT_ID>"             # Halo API client ID
$haloClientSecret = "<REDACTED_CLIENT_SECRET>"     # Halo API client secret
$haloBaseUrl = "<REDACTED_URL>"                    # Halo token endpoint
$haloCustomerUpdateUrl = "<REDACTED_URL>"          # Halo customer update endpoint

# Retrieves Halo access token for authentication
function Get-HaloAccessToken {
    $body = @{
        grant_type = "client_credentials"           # OAuth flow type
        client_id = $haloClientId
        client_secret = $haloClientSecret
    }

    try {
        $response = Invoke-RestMethod -Uri $haloBaseUrl -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
        return $response.access_token                # Return bearer token
    } catch {
        Write-Error "Failed to retrieve Halo access token: $_"
        return $null
    }
}

# Pulls all Bandwidth customers using credentials
function Get-AllBandwidthCustomers {
    $url = "<REDACTED_URL>"
    $credential = New-Object System.Management.Automation.PSCredential($bandwidthUser, (ConvertTo-SecureString $bandwidthPass -AsPlainText -Force))

    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -Credential $credential
        return $response.customers                   # Return list of customers
    } catch {
        Write-Error "Failed to retrieve Bandwidth customers: $_"
        return @()
    }
}

# Retrieves the number of DIDs assigned to a customer
function Get-DIDCountFromBandwidth($customerId) {
    $url = "<REDACTED_URL>"
    $credential = New-Object System.Management.Automation.PSCredential($bandwidthUser, (ConvertTo-SecureString $bandwidthPass -AsPlainText -Force))

    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -Credential $credential
        return $response.Count                        # Return DID count
    } catch {
        Write-Warning "Failed to retrieve DIDs for customer $customerId, $_"
        return $null
    }
}

# Updates the Halo customer record with the retrieved DID count
function Update-HaloCustomer($haloCustomerId, $didCount, $accessToken) {
    $url = "<REDACTED_URL>"
    $headers = @{
        "Authorization" = "Bearer $accessToken"      # Include access token
        "Content-Type" = "application/json"
    }
    $body = @{
        customFields = @{
            CFdidCount = $didCount                   # Map count to custom field
        }
    } | ConvertTo-Json -Depth 3

    try {
        Invoke-RestMethod -Uri $url -Method Put -Headers $headers -Body $body
        Write-Host "Updated Halo customer $haloCustomerId with $didCount DIDs"
    } catch {
        Write-Warning "Failed to update Halo customer $haloCustomerId, $_"
    }
}

# Main workflow 
$accessToken = Get-HaloAccessToken
if (-not $accessToken) {
    Write-Error "Cannot proceed without Halo access token."
    exit                                             # Halt if token retrieval fails
}

$customers = Get-AllBandwidthCustomers              # Fetch all customers
$counter = 0                                         # Initialize update counter

foreach ($customer in $customers) {
    $bandwidthCustomerId = $customer.id              # Bandwidth customer ID
    $haloCustomerId = $customer.haloId               # Corresponding Halo ID (must be mapped)

    if ($null -ne $haloCustomerId) {
        $didCount = Get-DIDCountFromBandwidth $bandwidthCustomerId
        if ($null -ne $didCount) {
            Update-HaloCustomer $haloCustomerId $didCount $accessToken
            $counter++                               # Increment count of successful updates
        } else {
            Write-Warning "No DIDs found for Bandwidth customer $bandwidthCustomerId"
        }
    } else {
        Write-Warning "No Halo ID found for Bandwidth customer $bandwidthCustomerId"
    }
}

Write-Host "Completed. Total customers updated: $counter"  # Summary output
