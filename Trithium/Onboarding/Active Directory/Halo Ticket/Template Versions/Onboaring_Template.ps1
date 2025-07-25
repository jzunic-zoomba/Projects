# Import required modules
Import-Module ActiveDirectory
Import-Module ADSync
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Identity.DirectoryManagement
Import-Module Microsoft.Graph.Authentication

# API Configuration
$clientId = "<YOUR_CLIENT_ID>"
$clientSecret = "<YOUR_CLIENT_SECRET>"
$tokenUrl = "https://<YOUR_AUTH_DOMAIN>/auth/token"
$apiUrl = "https://<YOUR_API_DOMAIN>/api/Tickets"

# Get Access Token (OAuth)
$body = @{
    grant_type = "client_credentials"
    client_id = $clientId
    client_secret = $clientSecret
    scope = "all"
}

try {
    $accessToken = (Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body).access_token
} catch {
    Write-Host "Failed to get token. Check credentials or URL." -ForegroundColor Red
    exit 1
}

# Prompt for Ticket ID
$inputId = Read-Host "Enter Ticket ID"
$headers = @{ Authorization = "Bearer $accessToken" }

# Retrieve Ticket Info
try {
    $ticket = Invoke-RestMethod -Uri "$apiUrl/$inputId" -Headers $headers -Method Get
} catch {
    Write-Host "Error retrieving ticket. Check ID and connection." -ForegroundColor Red
    exit 1
}

if ($ticket.id -ne [int]$inputId) {
    Write-Host "Ticket ID not found or mismatched." -ForegroundColor Red
    exit 1
}

# Extract Custom Fields
Write-Host "`nExtracting custom field values..." -ForegroundColor Green
Start-Sleep -Seconds 1
$ticketDate = Get-Date $ticket.datecreated
$ParameterOne = ($ticket.customfields | Where-Object { $_.name -eq "Needed Parameter" }).value -split '\s+' | Select-Object -First 1

# Derive company from email address
$Company = ($email -split "@")[1] -split "\." | Select-Object -First 1

# Display Summary
Write-Host "`n/----------- Extracted Info -----------\" -ForegroundColor Cyan
#Print relevant information like name, emails, dates, etc.
Write-Host "\----------------------------------------/" -ForegroundColor Cyan

# Simulate Company Lookup.Not needed
=Write-Host "`nSearching for company profile: $Company" -NoNewline -ForegroundColor Yellow
Start-Sleep -Seconds 1; Write-Host "." -NoNewline
Start-Sleep -Seconds 1; Write-Host "." -NoNewline
Start-Sleep -Seconds 1; Write-Host "." 

# Execute Onboarding Script
if ($Company -eq "<EXPECTED_COMPANY_NAME>" -and $VDIOption -ne 0) {
    & "C:\Path\To\Relevant_File1.ps1" `
# Needed parameters
} 
# Can add other paths to files for different companies 
else {
    & "C:\Path\To\General_Onboarding.ps1" `
# Needed parameters
}
