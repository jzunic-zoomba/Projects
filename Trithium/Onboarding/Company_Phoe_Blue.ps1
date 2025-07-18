# Define parameters to accept input from the user
param (
    [string]$startingDate,        # The starting date of the user (e.g., hire date)
    [string]$birthDate,           # The birth date of the user
    [int]$UserType,               # The type of user (e.g., Admin, Regular User)
    [int]$VDIOption,              # The Virtual Desktop Infrastructure (VDI) option for the user
    [SecureString]$password,      # The user's password (secure string for security)
    [string]$email,               # The user's email address (used as their principal name)
    [string]$firstName,           # The user's first name
    [string]$lastName             # The user's last name
)

# Output header for this process
Write-Host "/------------------Phoe Blue------------------\" -ForegroundColor Cyan

# Placeholder SMTP server (you can replace this if email notifications are implemented)
$smtpServer = "smtp.yourdomain.com"
Write-Host "SMTP Server: $smtpServer"

# Prompt for the AD Organizational Unit (OU) path
$ouPath = Read-Host "Enter OU Path"

# Generate SAM account name and UPN based on email
$samAccountName = $email.Split("@")[0]
$userPrincipalName = $email

# Prompt for password if not provided
if (-not $password) {
    $password = Read-Host -AsSecureString "Enter Password"
}

# Create Active Directory user account
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

# Set extension attributes for user in AD
Set-ADUser -Identity $samAccountName `
           -Replace @{
               'msDS-cloudExtensionAttribute1' = $startingDate;
               'msDS-cloudExtensionAttribute3' = $birthDate
           }

Write-Host "AD User created and attributes set successfully!" -ForegroundColor Green

# Connect to Microsoft Graph and check/create Azure AD user
try {
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All"
    $cloudUser = Get-MgUser -UserId $userPrincipalName
    Write-Host "Microsoft 365 account already exists for $userPrincipalName" -ForegroundColor Green
} catch {
    Write-Host "Microsoft 365 account NOT found for $userPrincipalName. Creating Azure AD user..." -ForegroundColor Yellow

    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    )

    try {
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

# Trigger Azure AD Connect sync
Start-ADSyncSyncCycle -PolicyType Delta
Write-Host "Azure AD Connect sync started..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

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
    Write-Host "Error assigning Microsoft 365 license: $_" -ForegroundColor Red
}

# Onboard the user to AD group(s)
Write-Host "Starting onboarding for $samAccountName into Phoenix & Bluebeam VDI..."
Add-ADGroupMember -Identity "Phoenix_VDI_Group" -Members $samAccountName

# Define path to Defender onboarding script (used for VDI/non-persistent machines)
$onboardingScript = "C:\Path\To\Defender\Onboard-NonPersistentMachine.ps1"

# Check if script exists and run it
if (Test-Path $onboardingScript) {
    & $onboardingScript
    Write-Host "Defender onboarding script executed."
} else {
    Write-Host "Onboarding script not found at $onboardingScript"
}

Write-Host "Onboarding complete for $samAccountName." -ForegroundColor Green
Write-Host "\---------------------------------------------/" -ForegroundColor Cyan

# Return to the main onboarding email script (update this path to reflect your actual environment)
& "C:\Path\To\Your\Onboarding\MMC_Email.ps1" `
    -birthDate $birthDate `
    -UserType $UserType `
    -VDIOption $VDIOption `
    -GeneratePassword $true `
    -email $email `
    -firstName $firstName `
    -lastName $lastName
