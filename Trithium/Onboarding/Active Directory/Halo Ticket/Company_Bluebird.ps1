# Define parameters to accept input from the user
param (
    [string]$startingDate,        # The starting date of the user (e.g., hire date)
    [string]$birthDate,           # The birth date of the user
    [int]$UserType,               # The type of user (e.g., Admin, Regular User)
    [int]$VDIOption,              # The Virtual Desktop Infrastructure (VDI) option for the user
    [string]$email,               # The user's email address (used as their principal name)
    [string]$firstName,           # The user's first name
    [string]$lastName,            # The user's last name
    [securestring]$password       # The user's password (secure string for security)
)

# Output header indicating the start of the process for Bluebeam (or any other system-specific context)
Write-Host "/-------------------Account Setup------------------\" -ForegroundColor Cyan

# Define the SMTP server (for future email functionality if needed)
$smtpServer = "smtp.yourdomain.com"
Write-Host "SMTP Server: $smtpServer"

# Prompt for Organizational Unit (OU) path for AD user creation
$ouPath = Read-Host "Enter OU Path"

# Generate account identifiers
$samAccountName = $email.Split("@")[0]         # Extract username from email
$userPrincipalName = $email                    # Set UPN to full email address

# Create new user in Active Directory
New-ADUser -Name "$firstName $lastName" `
           -GivenName $firstName `
           -Surname $lastName `
           -SamAccountName $samAccountName `
           -UserPrincipalName $userPrincipalName `
           -Path $ouPath `
           -AccountPassword $password `
           -Enabled $true `
           -DisplayName "$firstName $lastName" `
           -EmailAddress $userPrincipalName

# Set custom AD attributes (extension attributes)
Set-ADUser -Identity $samAccountName `
           -Replace @{
               'msDS-cloudExtensionAttribute1' = $startingDate;  # Set the starting date
               'msDS-cloudExtensionAttribute3' = $birthDate      # Set the birth date
           }

Write-Host "AD User created and attributes set successfully!" -ForegroundColor Green

# Connect to Microsoft Graph API to manage Azure AD
try {
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All"
    $cloudUser = Get-MgUser -UserId $userPrincipalName

    Write-Host "Microsoft 365 account already exists for $userPrincipalName" -ForegroundColor Green
} catch {
    Write-Host "Microsoft 365 account NOT found for $userPrincipalName. Creating Azure AD user..." -ForegroundColor Yellow

    # Convert SecureString password to plain text
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    )

    try {
        # Create Azure AD user
        $aadUser = New-MgUser -AccountEnabled:$true `
            -DisplayName "$firstName $lastName" `
            -MailNickname $samAccountName `
            -UserPrincipalName $userPrincipalName `
            -PasswordProfile @{ ForceChangePasswordNextSignIn = $false; Password = $plainPassword } `
            -GivenName $firstName `
            -Surname $lastName `
            -Mail $userPrincipalName `
            -UsageLocation "US"

        Write-Host "Azure AD user created for $userPrincipalName" -ForegroundColor Green
        $cloudUser = $aadUser
    } catch {
        Write-Host "Failed to create Azure AD user: $_" -ForegroundColor Red
    }
}

# Start Azure AD Connect sync cycle
Start-ADSyncSyncCycle -PolicyType Delta
Write-Host "Azure AD Connect sync started..." -ForegroundColor Yellow
Start-Sleep -Seconds 60  # Wait for sync completion

# Assign Microsoft 365 license
try {
    $cloudUser = Get-MgUser -UserId $userPrincipalName

    if ($cloudUser) {
        $licenseSkuId = (Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -eq "ENTERPRISEPACK" }).SkuId

        Set-MgUserLicense -UserId $cloudUser.Id `
            -AddLicenses @{ SkuId = $licenseSkuId } `
            -RemoveLicenses @()

        Write-Host "License assigned to $userPrincipalName" -ForegroundColor Green
    } else {
        Write-Host "Microsoft 365 account NOT found for $userPrincipalName" -ForegroundColor Red
    }
} catch {
    Write-Host "Error checking or assigning Microsoft 365 license: $_" -ForegroundColor Red
}

# Output footer
Write-Host "\---------------------------------------------/" -ForegroundColor Cyan

# Call follow-up onboarding script (replace path with your actual path or configuration)
& "C:\Path\To\Your\OnboardingScript\MMC_Onboarding.ps1" `
    -birthDate $birthDate `
    -UserType $UserType `
    -VDIOption $VDIOption `
    -GeneratePassword $GeneratePassword `
    -email $email `
    -firstName $firstName `
    -lastName $lastName
