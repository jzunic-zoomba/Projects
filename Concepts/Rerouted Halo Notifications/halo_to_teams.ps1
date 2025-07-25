# Load environment variables
$clientId = $env:HALO_CLIENT_ID
$clientSecret = $env:HALO_CLIENT_SECRET
$teamsWebhookUrl = $env:TEAMS_WEBHOOK_URL
$artifactPath = "last_check.txt"

# OAuth2 token endpoint (confirm this for your HaloPSA tenant)
$tokenUrl = "https://yourcompany.halopsa.com/oauth2/token"
$haloBaseUrl = "https://yourcompany.halopsa.com/api"

# Get current time in EST
$nowUtc = Get-Date
$nowEst = $nowUtc.ToUniversalTime().AddHours(-5)
$hour = $nowEst.Hour
$isAfterHours = ($hour -ge 17 -or $hour -lt 8)

if (-not $isAfterHours) {
    Write-Output "Not after hours. Exiting."
    exit 0
}

# Load last check time from artifact or default to 15 minutes ago
if (Test-Path $artifactPath) {
    $lastCheck = Get-Content $artifactPath | Out-String | Get-Date
} else {
    $lastCheck = $nowEst.AddMinutes(-15)
}

# Step 1: Get access token from Halo using client credentials
$tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
} -ContentType "application/x-www-form-urlencoded"

$accessToken = $tokenResponse.access_token

# Step 2: Query HaloPSA API for newly created tickets
$haloApiUrl = "$haloBaseUrl/tickets?created_gte=$($lastCheck.ToString("o"))"
$response = Invoke-RestMethod -Uri $haloApiUrl -Headers @{
    Authorization = "Bearer $accessToken"
}

# Step 3: Send ticket info to Microsoft Teams if created after hours
foreach ($ticket in $response) {
    $ticketTime = [datetime]$ticket.created
    if ($ticketTime -gt $lastCheck -and ($ticketTime.Hour -ge 17 -or $ticketTime.Hour -lt 8)) {
        $body = @{
            text = "New *after-hours* HaloPSA Ticket:\n**$($ticket.summary)**\nTicket ID: $($ticket.id)\nCreated: $($ticket.created)"
        } | ConvertTo-Json -Depth 3

        Invoke-RestMethod -Uri $teamsWebhookUrl -Method Post -Body $body -ContentType 'application/json'
    }
}

# Step 4: Save the current time for the next run
$nowEst.ToString("o") | Set-Content $artifactPath
