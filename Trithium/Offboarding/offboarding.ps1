
# Define OAuth2 credentials and endpoints — Replace placeholders with secure values
$clientId     = "<your-client-id>"
$clientSecret = "<your-client-secret>"
$tokenUrl     = "https://halo.trithium.com/auth/token"
$apiUrl       = "https://halo.trithium.com/api/Tickets"

# Prepare request body for token acquisition
$body = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = "all"
}

# Request an access token
$tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body
$accessToken   = $tokenResponse.access_token

# If token retrieval fails, terminate
if (-not $accessToken) {
    Write-Error "Failed to retrieve access token."
    exit
}

# Prompt for ticket ID
$inputId = Read-Host "Enter Ticket ID"
$headers = @{ Authorization = "Bearer $accessToken" }

# Fetch ticket data
$ticket = Invoke-RestMethod -Uri "$apiUrl/$inputId" -Headers $headers -Method Get

# Validate retrieved ticket ID
if ($ticket.id -ne [int]$inputId) {
    Write-Host "Ticket ID not found."
    exit
}

# Find the custom field named CFemailAddress
$emailFields = $ticket.customfields | Where-Object { $_.name -eq "CFemailAddress" }

# Exit if the field is missing
if (-not $emailFields) {
    Write-Host "Email address not found in ticket."
    exit
}

# Extract the email value (handles both string and array formats)
$emailValue = $emailFields[0].value
$email = ($emailValue -is [System.Collections.IEnumerable] -and -not ($emailValue -is [string])) ? $emailValue[0] : $emailValue

Write-Host "Email found in ticket: $email"


$convertMailbox = Read-Host "Convert mailbox for $email to shared? (Y/N)"
if ($convertMailbox -ne "Y") {
    Write-Host "Mailbox conversion skipped."
} else {
    try {
        # Connect to Exchange Online
        Write-Host "Connecting to Exchange Online..."
        Connect-ExchangeOnline -ErrorAction Stop

        # Convert to shared mailbox
        Write-Host "Converting mailbox to shared..."
        Set-Mailbox -Identity $email -Type Shared -ErrorAction Stop
        Write-Host "Mailbox for $email successfully converted to shared."

        # Optional: Configure email forwarding
        $forwardChoice = Read-Host "Do you want to forward emails for $email to another address? (Y/N)"
        if ($forwardChoice -eq "Y") {
            $forwardTo = Read-Host "Enter the forwarding email address"
            Set-Mailbox -Identity $email -ForwardingSMTPAddress $forwardTo -DeliverToMailboxAndForward $true -ErrorAction Stop
            Write-Host "Email forwarding set to $forwardTo."
        }

        Disconnect-ExchangeOnline -Confirm:$false
    }
    catch {
        Write-Warning "Failed to convert mailbox or set forwarding: $_"
    }
}

$removeLicenses = Read-Host "Do you want to remove licenses from the user $email? (Y/N)"
if ($removeLicenses -eq 'Y') {
    try {
        # Connect to Microsoft Graph
        Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All"
        $user = Get-MgUser -UserId $email -ErrorAction Stop

        # Retrieve licenses
        $licenses = Get-MgUserLicenseDetail -UserId $user.Id

        if ($licenses.Count -eq 0) {
            Write-Host "No licenses found for user."
        } else {
            Write-Host "Licenses found:"
            $i = 1
            foreach ($license in $licenses) {
                Write-Host "$i. $($license.SkuPartNumber)"
                $i++
            }

            # Prompt for removal options
            $removeChoice = Read-Host "Enter license number to remove, comma-separated, or type 'all' to remove all"

            # Remove all licenses
            if ($removeChoice -eq 'all') {
                foreach ($license in $licenses) {
                    Set-MgUserLicense -UserId $user.Id -RemoveLicenses @($license.SkuId) -AddLicenses @{} -ErrorAction Stop
                    Write-Host "Removed license: $($license.SkuPartNumber)"
                }
            }
            # Remove selected licenses
            else {
                $indices = $removeChoice -split ',' | ForEach-Object { $_.Trim() }
                foreach ($index in $indices) {
                    $skuId = $licenses[[int]$index - 1].SkuId
                    Set-MgUserLicense -UserId $user.Id -RemoveLicenses @($skuId) -AddLicenses @{} -ErrorAction Stop
                    Write-Host "Removed license index $index."
                }
            }
        }
    }
    catch {
        Write-Warning "Could not remove licenses: $_"
    }
}


try {
    $deleteUser = Read-Host "Do you want to delete the user account '$email' from Entra ID? (Y/N)"
    if ($deleteUser -eq "Y") {
        Write-Host "Looking up user in Microsoft Entra ID..."

        $user = Get-MgUser -UserId $email -ErrorAction Stop

        # Confirm deletion — irreversible action
        $confirm = Read-Host "Are you absolutely sure you want to DELETE '$($user.DisplayName)' ($email)? This cannot be undone. (Y/N)"
        if ($confirm -eq "Y") {
            Remove-MgUser -UserId $user.Id -ErrorAction Stop
            Write-Host "User $email has been permanently deleted from Entra ID." -ForegroundColor Green
        } else {
            Write-Host "Deletion canceled." -ForegroundColor Yellow
        }
    } else {
        Write-Host "User account deletion skipped." -ForegroundColor Cyan
    }
}
catch {
    Write-Warning "Could not delete user: $_"
}
