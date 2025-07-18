param (
    [string]$startingDate,              # Employee start date
    [string]$birthDate,                 # Employee birth date
    [int]$UserType,                     # Custom user type flag
    [int]$VDIOption,                    # Virtual Desktop option (custom)
    [string]$email,                     # Employee email address
    [string]$firstName,                 # Employee first name
    [string]$lastName,                  # Employee last name
    [securestring]$password,            # Employee password (SecureString)
    [string]$usageLocation = "US",      # Licensing region (defaults to US)
    [int]$GeneratePassword              # Whether to generate a password automatically
)

# Output header
Write-Host "/--------------Corporate Services-------------\" -ForegroundColor Cyan

# Define the SMTP server to use (replace with your actual SMTP server)
$smtpServer = "smtp.yourdomain.com"
Write-Host "SMTP Server: $smtpServer"

# Prompt user for Organizational Unit (OU) path in Active Directory
$ouPath = Read-Host "Enter OU Path"

# Prepare Active Directory user account variables
$samAccountName = $email.Split("@")[0]         # Use email prefix as SAM account name
$userPrincipalName = $email                    # Full email address as UPN

# Create the AD user with the specified properties
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

# Set custom extension attributes in AD
Set-ADUser -Identity $samAccountName `
           -Replace @{
               'msDS-cloudExtensionAttribute1' = $startingDate;
               'msDS-cloudExtensionAttribute3' = $birthDate
           }

Write-Host "AD User created and attributes set successfully!" -ForegroundColor Green

# Start Azure AD Connect sync (delta)
Start-ADSyncSyncCycle -PolicyType Delta
Write-Host "Azure AD Connect sync started..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

# Ensure Microsoft Graph module is available
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Install-Module Microsoft.Graph -Scope CurrentUser -Force
}

# Connect to Microsoft Graph API with required permissions
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All", "Organization.Read.All"

# Check if the user already exists in Azure AD / Microsoft 365
$cloudUser = Get-MgUser -UserId $userPrincipalName -ErrorAction SilentlyContinue

if ($cloudUser) {
    Write-Host "Microsoft 365 account found for $userPrincipalName" -ForegroundColor Green
} else {
    Write-Host "Creating Microsoft 365 user: $userPrincipalName"

    try {
        # Convert SecureString password to plain text (for API use — use caution!)
        $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
        )

        # Create Microsoft 365 user
        $cloudUser = New-MgUser -AccountEnabled $true `
            -DisplayName "$firstName $lastName" `
            -MailNickname $samAccountName `
            -UserPrincipalName $userPrincipalName `
            -PasswordProfile @{ ForceChangePasswordNextSignIn = $true; Password = $plainPassword } `
            -GivenName $firstName `
            -Surname $lastName `
            -UsageLocation $usageLocation

        Write-Host "Microsoft 365 user created." -ForegroundColor Green
    } catch {
        Write-Host "Failed to create Microsoft 365 user: $_" -ForegroundColor Red
    }
}

# Assign Microsoft 365 license
$licenses = Get-MgSubscribedSku
$msLicense = $licenses | Where-Object { $_.SkuPartNumber -eq "ENTERPRISEPACK" }  # Replace with appropriate license SKU

if ($msLicense) {
    Set-MgUserLicense -UserId $cloudUser.Id -AddLicenses @{ SkuId = $msLicense.SkuId } -RemoveLicenses @()
    Write-Host "Microsoft 365 license assigned." -ForegroundColor Green
} else {
    Write-Host "Microsoft 365 license SKU not found." -ForegroundColor Red
}

# Assign Adobe license if available (searches for Adobe-related SKUs)
$adobeLicense = $licenses | Where-Object { $_.SkuPartNumber -like "*ADOBE*" }

if ($adobeLicense) {
    Set-MgUserLicense -UserId $cloudUser.Id -AddLicenses @{ SkuId = $adobeLicense.SkuId } -RemoveLicenses @()
    Write-Host "Adobe license assigned." -ForegroundColor Green
} else {
    Write-Host "Adobe license SKU not found." -ForegroundColor Red
}

# Optional: Add user to Adobe group in Azure AD
$groupName = "Adobe Users"     # Replace with your actual group name if different
$group = Get-MgGroup -Filter "displayName eq '$groupName'" -ConsistencyLevel eventual

if ($group) {
    New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $cloudUser.Id
    Write-Host "User added to Adobe group: $groupName"
} else {
    Write-Host "Adobe group '$groupName' not found. Skipping group assignment."
}

Write-Host "\---------------------------------------------/" -ForegroundColor Cyan

# Call follow-up script to continue onboarding (replace with a generic/local path)
& "C:\Path\To\Your\OnboardingScript\MMC_Onboarding.ps1" `
    -birthDate $birthDate `
    -UserType $UserType `
    -VDIOption $VDIOption `
    -GeneratePassword $GeneratePassword `
    -email $email `
    -firstName $firstName `
    -lastName $lastName
