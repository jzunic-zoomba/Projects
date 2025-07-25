# Define parameters to accept input from the user
param (
    [string]$startDate,              # The starting date of the user (e.g., hire date)
    [string]$birthDate,              # The birth date of the user
    [string]$formattedBirthDate,     # Formatted birth date (for display or database)
    [int]$UserType,                  # The type of user (e.g., Admin, Regular User)
    [int]$VDIOption,                 # The Virtual Desktop Infrastructure (VDI) option for the user
    [int]$GeneratePassword,          # Flag to indicate whether to generate a password or input one
    [string]$email,                  # The user's email address (used as their principal name)
    [string]$firstName,              # The user's first name
    [string]$lastName                # The user's last name
)

# Default password value — REPLACE THIS with secure policy or random generator
$password = "DefaultPassword123!"  # Placeholder password — change this in production

# Output Company Details section
Write-Host "/---------------Company Details---------------\" -ForegroundColor Cyan
Write-Host "Birth Date: $birthDate"
Write-Host "Formatted Birth Date: $formattedBirthDate"

# User Type Mapping - Convert user type integer value to string for readability
$userTypeMap = @{
    0 = "Type1"
    1 = "Type2"
    2 = "Type3"
    3 = "Type4"
    4 = "Type5"
}

# Check if the UserType is valid
if ($userTypeMap.ContainsKey($UserType)) {
    Write-Host "User Type: $($userTypeMap[$UserType])"
} else {
    Write-Host "User Type Not found" -ForegroundColor Red
    exit 1
}

# VDI Option Mapping - Match option to a group name
$vdiGroupMap = @{
    1 = "VDI1"
    2 = "VDI2"
    3 = "VDI3"
    4 = "VDI4"
    5 = "VDI5"
}

# Validate VDI Option
if ($vdiGroupMap.ContainsKey($VDIOption)) {
    Write-Host "VDI Option: Yes"
    $VDIGroup = $vdiGroupMap[$VDIOption]
    Write-Host "VDI Group: $VDIGroup"
} else {
    Write-Host "VDI Group Not found" -ForegroundColor Red
    exit 1
}

# Handle password generation or prompt
if ($GeneratePassword -eq 1) {
    Write-Host "Generate Password: Yes"
    $password = Read-Host -AsSecureString "Enter Password"
}

Write-Host "\---------------------------------------------/" -ForegroundColor Cyan
Write-Host "Searching for VDI Group..." -ForegroundColor Yellow

# VDI Script Mapping
$scriptMap = @{
    1 = "Company_Gen_User.ps1"
    2 = "Company_Corporate_Services.ps1"
    3 = "Company_Bluebeam.ps1"
    4 = "Company_Phoe_Blue.ps1"
    5 = "Company_Project_Management.ps1"
}

$defaultScript = "Company_General_Onboarding.ps1"

# Determine which script to execute
$scriptName = $scriptMap[$VDIOption]
if (-not $scriptName) {
    $scriptName = $defaultScript
}

# Define path to script — replace this with actual deployment location
$scriptPath = "C:\Path\To\Onboarding\$scriptName"

# Execute the selected onboarding script
& $scriptPath `
    -startingDate $startDate `
    -birthDate $formattedBirthDate `
    -UserType $UserType `
    -VDIOption $VDIOption `
    -password $password `
    -email $email `
    -firstName $firstName `
    -lastName $lastName
