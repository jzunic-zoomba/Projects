# Load environment variables
$emailUsername = $env:EMAIL_USERNAME
$emailPassword = $env:EMAIL_PASSWORD
$clientId = $env:HALO_CLIENT_ID
$clientSecret = $env:HALO_CLIENT_SECRET
$tokenUrl = "https://yourcompany.halopsa.com/oauth2/token"
$haloBaseUrl = "https://yourcompany.halopsa.com/api"
$artifactPath = "last_check.txt"

# Get current time in EST
$nowUtc = Get-Date
$nowEst = $nowUtc.ToUniversalTime().AddHours(-5)
$hour = $nowEst.Hour
$isAfterHours = ($hour -ge 17 -or $hour -lt 8)  # Replace with your StartHour/EndHour if needed

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

# Step 1: Get access token via client credentials
$tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
} -ContentType "application/x-www-form-urlencoded"

$accessToken = $tokenResponse.access_token

# Step 2: Call HaloPSA API with Bearer token
$haloApiUrl = "$haloBaseUrl/tickets?created_gte=$($lastCheck.ToString("o"))"
$response = Invoke-RestMethod -Uri $haloApiUrl -Headers @{ Authorization = "Bearer $accessToken" }

# Step 3: Email any tickets created after hours
foreach ($ticket in $response) {
    $ticketTime = [datetime]$ticket.created
    if ($ticketTime -gt $lastCheck -and ($ticketTime.Hour -ge 17 -or $ticketTime.Hour -lt 8)) {
        $from = $emailUsername
        $to = "yourteam@yourcompany.com"
        $subject = "New HaloPSA Ticket: $($ticket.summary)"
        $body = "A new ticket was created after hours:`n`nID: $($ticket.id)`nSummary: $($ticket.summary)`nCreated: $($ticket.created)"
        $smtpServer = "smtp.office365.com"
        $smtpPort = 587

        Send-MailMessage -From $from -To $to -Subject $subject -Body $body -SmtpServer $smtpServer -Port $smtpPort -UseSsl -Credential (New-Object System.Management.Automation.PSCredential($from, (ConvertTo-SecureString $emailPassword -AsPlainText -Force)))
    }
}

# Step 4: Save current time for next run
$nowEst.ToString("o") | Set-Content $artifactPath
