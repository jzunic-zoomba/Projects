# Define parameters to accept input from the user
param (
    [string]$startingDate,         # The starting date of the user (e.g., hire date)
    [string]$birthDate,            # The birth date of the user
    [int]$UserType,                # The type of user (e.g., Admin, Regular User)
    [int]$VDIOption,               # The Virtual Desktop Infrastructure (VDI) option for the user
    [SecureString]$password,       # The user's password (secure string for security)
    [string]$email,                # The user's email address (used as their principal name)
    [string]$firstName,            # The user's first name
    [string]$lastName              # The user's last name
)

################################################################################################

# Output header indicating the start of the process
Write-Host "/-----------------No VDI Group----------------\" -ForegroundColor Cyan

# Prompt for the Organizational Unit (OU) path for AD user creation
$ouPath = Read-Host "Enter OU Path"

# Generate the SamAccountName (username) based on the user's email address
$samAccountName = $email.Split("@")[0]
$userPrincipalName = $email

# Create the Active Directory (AD) user with the provided details
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

# Set extension attributes in AD (e.g., custom attributes for HR info)
Set-ADUser -Identity $samAccountName `
           -Replace @{
               'msDS-cloudExtensionAttribute1' = $startingDate;
               'msDS-cloudExtensionAttribute3' = $birthDate
           }

Write-Host "AD User created and attributes set successfully!" -ForegroundColor Green

################################################################################################

# Initiate Azure AD Connect sync to push changes to Azure AD
Start-ADSyncSyncCycle -PolicyType Delta
Write-Host "Azure AD Connect sync started..." -ForegroundColor Yellow

# Wait for sync to propagate
Start-Sleep -Seconds 60

################################################################################################

# Assign Microsoft 365 license if user exists in Azure AD
try {
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All"
    
    $cloudUser = Get-MgUser -UserId $userPrincipalName

    if ($cloudUser) {
        Write-Host "Microsoft 365 account found for $userPrincipalName" -ForegroundColor Green

        $licenses = Get-MgSubscribedSku
        $licenseSkuId = ($licenses | Where-Object { $_.SkuPartNumber -eq "ENTERPRISEPACK" }).SkuId

        Set-MgUserLicense -UserId $cloudUser.Id -AddLicenses @{SkuId = $licenseSkuId} -RemoveLicenses @()
        Write-Host "License assigned to $userPrincipalName" -ForegroundColor Green
    } else {
        Write-Host "Microsoft 365 account NOT found for $userPrincipalName" -ForegroundColor Red
    }
} catch {
    Write-Host "Error checking or assigning Microsoft 365 license: $_" -ForegroundColor Red
}

Write-Host "\---------------------------------------------/" -ForegroundColor Cyan

################################################################################################

# Return to the main onboarding script (adjust path accordingly)
& "C:\Path\To\MMC_Email.ps1" `
    -birthDate $birthDate `
    -UserType $UserType `
    -VDIOption $VDIOption `
    -password $password `
    -email $email `
    -firstName $firstName `
    -lastName $lastName
