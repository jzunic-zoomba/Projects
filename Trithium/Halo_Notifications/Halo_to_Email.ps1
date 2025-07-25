# Load environment variables
$clientId = $env:HALO_CLIENT_ID
$clientSecret = $env:HALO_CLIENT_SECRET
$emailUsername = $env:EMAIL_USERNAME
$emailPassword = $env:EMAIL_PASSWORD
$artifactPath = "last_check.txt"

# Get current time in EST (manual UTC offset, not DST-aware)
$nowUtc = Get-Date
$nowEst = $nowUtc.ToUniversalTime().AddHours(-5)
$hour = $nowEst.Hour
$isAfterHours = ($hour -ge "StartTime" -or $hour -lt "End Time")

# Exit if during business hours
if (-not $isAfterHours) {
    Write-Output "Not after hours. Exiting."
    exit 0
}

# Load last check time or default to 15 minutes ago
if (Test-Path $artifactPath) {
    $lastCheck = Get-Content $artifactPath | Out-String | Get-Date
} else {
    $lastCheck = $nowEst.AddMinutes(-15)
}

# Request OAuth2 token from HaloPSA
$tokenUrl = "https://halo.trithium.com/auth/token"
$tokenBody = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
}

try {
    $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $tokenBody -ContentType "application/x-www-form-urlencoded"
    $accessToken = $tokenResponse.access_token
    Write-Output "Access token acquired successfully."
} catch {
    Write-Error "Failed to acquire token: $($_.Exception.Message)"
    exit 1
}

# Construct API URL with timestamp filter
$haloApiUrl = "https://halo.trithium.com/api/tickets?created_gte=$($lastCheck.ToString("o"))"

# Query HaloPSA for tickets created since last check
try {
    $response = Invoke-RestMethod -Uri $haloApiUrl -Headers @{ Authorization = "Bearer $accessToken" }
} catch {
    Write-Error "Failed to retrieve tickets: $($_.Exception.Message)"
    exit 1
}

# Send email for each qualifying after-hours ticket
foreach ($ticket in $response) {
    $ticketTime = [datetime]$ticket.created
    if ($ticketTime -gt $lastCheck -and ($ticketTime.Hour -ge 17 -or $ticketTime.Hour -lt 8)) {
        $from = $emailUsername
        $to = "yourteam@yourcompany.com"
        $subject = "New HaloPSA Ticket: $($ticket.summary)"
        $body = "A new ticket was created after hours:`n`nID: $($ticket.id)`nSummary: $($ticket.summary)`nCreated: $($ticket.created)"
        $smtpServer = "smtp.office365.com"
        $smtpPort = 587

        Send-MailMessage -From $from -To $to -Subject $subject -Body $body `
            -SmtpServer $smtpServer -Port $smtpPort -UseSsl `
            -Credential (New-Object System.Management.Automation.PSCredential(
                $from, (ConvertTo-SecureString $emailPassword -AsPlainText -Force)))
    }
}

# Save current time to artifact file for next run
$nowEst.ToString("o") | Set-Content $artifactPath
