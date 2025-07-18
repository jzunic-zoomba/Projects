# Load environment variables
$apiKey = $env:HALO_API_KEY
$teamsWebhookUrl = $env:TEAMS_WEBHOOK_URL
$artifactPath = "last_check.txt"

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

# Query HaloPSA API
$haloApiUrl = "https://yourcompany.halopsa.com/api/tickets?created_gte=$($lastCheck.ToString("o"))"
$response = Invoke-RestMethod -Uri $haloApiUrl -Headers @{ "apiKey" = $apiKey }

foreach ($ticket in $response) {
    $ticketTime = [datetime]$ticket.created
    if ($ticketTime -gt $lastCheck -and ($ticketTime.Hour -ge 17 -or $ticketTime.Hour -lt 8)) {
        $body = @{
            text = "New HaloPSA Ticket: *$($ticket.summary)* (ID: $($ticket.id))"
        } | ConvertTo-Json -Depth 3

        Invoke-RestMethod -Uri $teamsWebhookUrl -Method Post -Body $body -ContentType 'application/json'
    }
}

# Save current time for next run
$nowEst.ToString("o") | Set-Content $artifactPath
