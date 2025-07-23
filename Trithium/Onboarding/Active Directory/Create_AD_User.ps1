# Import necessary PowerShell modules
Import-Module ActiveDirectory
Import-Module ADSync
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Identity.DirectoryManagement
Import-Module Microsoft.Graph.Authentication

# Set up API details (REDACTED for security)
$clientId = "<CLIENT_ID>"                   # Placeholder for OAuth2 Client ID
$clientSecret = "<CLIENT_SECRET>"           # Placeholder for OAuth2 Client Secret
$tokenUrl = "https://<your-api-domain>.com/auth/token"     # OAuth2 token URL
$apiUrl = "https://<your-api-domain>.com/api/Tickets"      # API endpoint to fetch tickets

# Request access token using client credentials
$body = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = "all"
}

# Obtain OAuth2 token
$accessToken = (Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body).access_token

# Prompt for Ticket ID
$inputId = Read-Host "Enter Ticket ID"

# Setup authorization header
$headers = @{ Authorization = "Bearer $accessToken" }

# Fetch ticket from API
$ticket = Invoke-RestMethod -Uri "$apiUrl/$inputId" -Headers $headers -Method Get

# Validate ticket
if ($ticket.id -ne [int]$inputId) {
    Write-Host "Ticket ID not found." -ForegroundColor Red
    Exit
}

# Extract fields from ticket
Write-Host "Ticket ID matched. Extracting custom field values" -NoNewline -ForegroundColor Green
Start-Sleep -Seconds 3; Write-Host "." -NoNewline -ForegroundColor Green
Start-Sleep -Seconds 3; Write-Host "." -NoNewline -ForegroundColor Green
Start-Sleep -Seconds 3; Write-Host "." -ForegroundColor Green
Start-Sleep -Seconds 1

$ticketDate         = Get-Date $ticket.datecreated
$firstName          = ($ticket.customfields | Where-Object { $_.name -eq "CFfirstName" }).value -split '\s+' | Select-Object -First 1
$lastName           = ($ticket.customfields | Where-Object { $_.name -eq "CFlastName" }).value -split '\s+' | Select-Object -First 1
$email              = ($ticket.customfields | Where-Object { $_.name -eq "CFemailAddress" }).value -split '\s+' | Select-Object -First 1
$startingDate       = ($ticket.customfields | Where-Object { $_.name -eq "CFstartingDate" }).value
$birthDate          = ($ticket.customfields | Where-Object { $_.name -eq "CFbirthDateFull" }).value
$formattedHireDate  = (Get-Date $startingDate).ToString("yyyyMMddHHmmss") + ".0Z"
$formattedBirthDate = (Get-Date $birthDate).ToString("yyyyMMddHHmmss") + ".0Z"
$VDIOption          = ($ticket.customfields | Where-Object { $_.name -eq "CFmmcVDIOption" }).value
$VDIGroup           = ($ticket.customfields | Where-Object { $_.name -eq "CFmmcVDIGroup" }).value
$GeneratePassword   = ($ticket.customfields | Where-Object { $_.name -eq "CFgeneratePasswordYN" }).value
$UserType           = ($ticket.customfields | Where-Object { $_.name -eq "CFmmcUserType" }).value

# Extract domain and company from email
$Company = ($email -split "@")[1] -split "\." | Select-Object -First 1

# Display extracted values
Write-Host "`n/------------------ Details ------------------\" -ForegroundColor Cyan
Write-Host "Ticket Date: $ticketDate"
Write-Host "Employee Name: $firstName $lastName"
Write-Host "Employee Email: $email"
Write-Host "Starting Date: $startingDate"
Write-Host "Formatted Starting Date: $formattedHireDate"
Write-Host "Company: $Company"
Write-Host "VDI Group: $VDIGroup"
Write-Host "\---------------------------------------------/" -ForegroundColor Cyan

# Simulate company lookup
Write-Host "Searching for $Company" -NoNewline -ForegroundColor Yellow
Start-Sleep -Seconds 3; Write-Host "." -NoNewline -ForegroundColor Yellow
Start-Sleep -Seconds 3; Write-Host "." -NoNewline -ForegroundColor Yellow
Start-Sleep -Seconds 3; Write-Host "." -ForegroundColor Yellow
Start-Sleep -Seconds 1

# Execute onboarding script based on company and VDI settings
if ($Company -eq "<your-company-name>" -and $VDIOption -ne 0) {
    & "C:\Path\To\Onboarding\VDI_Onboarding.ps1" `
        -startDate $formattedHireDate `
        -birthDate $birthDate `
        -formattedBirthDate $formattedBirthDate `
        -UserType $UserType `
        -VDIOption $VDIGroup `
        -GeneratePassword $GeneratePassword `
        -email $email `
        -firstName $firstName `
        -lastName $lastName
} else {
    & "C:\Path\To\Onboarding\General_Onboarding.ps1" `
        -GeneratePassword $GeneratePassword `
        -email $email `
        -firstName $firstName `
        -lastName $lastName
}
