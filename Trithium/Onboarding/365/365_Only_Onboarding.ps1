# Import required Microsoft Graph PowerShell modules
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Groups
Import-Module Microsoft.Graph.Authentication

# Connect to Microsoft Graph with necessary permissions
Write-Host "Connecting to Microsoft Graph..."
Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "Directory.ReadWrite.All"

# Retrieve the current Microsoft Graph context (tenant info)
$context = Get-MgContext
Write-Host "Connected to Microsoft Graph."
Write-Host "Tenant Display Name : $($context.TenantDisplayName)"
Write-Host "Tenant ID           : $($context.TenantId)"
Write-Host "Account             : $($context.Account)"

# Define the name of the group to ensure it exists
$groupName = "MMC F1 licensing"

# Check if the group already exists in Azure AD
$group = Get-MgGroup -Filter "displayName eq '$groupName'" -ErrorAction SilentlyContinue

# If the group doesn't exist, create it
if (-not $group) {
    Write-Host "Group '$groupName' not found. Creating it..."
    $group = New-MgGroup -DisplayName $groupName `
        -MailEnabled:$false `
        -MailNickname "MMCF1Licensing" `
        -SecurityEnabled:$true `
        -GroupTypes @()
    Write-Host "Group '$groupName' created: $($group.Id)"
} else {
    Write-Host "Group '$groupName' already exists: $($group.Id)"
}

# Load the CSV file containing user information
$csvPath = "C:\Path\To\Your\CSV\users.csv"
Write-Host "Using CSV from path: $csvPath"
$users = Import-Csv $csvPath

# Loop through each user in the CSV and process them
foreach ($user in $users) {
    # Extract user attributes from CSV
    $firstName = $user.'First Name'.Trim()
    $rawLastName = $user.'Last Name'.Trim()
    $rawHireDate = $user.'Hire Date (MM/DD/YY)' -as [string]
    $birthDate = $user.'Birth Date (MM/YY)' -as [string]
    $division = $user.'Division'
    $jobTitle = $user.'Job Title'

    # Skip user if missing required attributes
    if (-not $firstName -or -not $rawLastName) {
        Write-Warning "Skipping row due to missing first or last name."
        continue
    }

    # Build the user's full name and email address
    $lastName = $rawLastName.Split(" ")[0]
    $fullName = "$firstName $lastName"
    $userPrincipalName = "$firstName.$lastName@domain.com".ToLower() # Replace domain as necessary

    Write-Host "Processing $fullName <$userPrincipalName>..."

    # Parse the hire date into ISO format if it's valid
    $hireDateISO = $null
    if ($rawHireDate -and $rawHireDate -match '^\d{1,2}/\d{1,2}/\d{2}$') {
        try {
            $parsedHireDate = [datetime]::ParseExact($rawHireDate, 'MM/dd/yy', $null)
            $hireDateISO = $parsedHireDate.ToString("yyyy-MM-dd")
        } catch {
            Write-Warning "Invalid hire date for ${fullName}: '$rawHireDate'"
        }
    }

    # Set default password and force password change at next sign-in
    $password = "TemporaryPassword123!"  # Replace with a policy-compliant password if needed
    $passwordProfile = @{
        ForceChangePasswordNextSignIn = $true
        Password = $password
    }

    # Check if the user already exists in Azure AD
    $existingUser = Get-MgUser -UserId $userPrincipalName -ErrorAction SilentlyContinue
    if (-not $existingUser) {
        Write-Host "Creating new Azure AD user: $userPrincipalName..."

        # Define the new user body
        $newUserBody = @{
            AccountEnabled        = $true
            DisplayName           = $fullName
            MailNickname          = "$firstName$lastName"
            UserPrincipalName     = $userPrincipalName
            GivenName             = $firstName
            Surname               = $lastName
            Department            = $division
            JobTitle              = $jobTitle
            PasswordProfile       = $passwordProfile
        }

        # Include hire date and birth date as extension attributes if present
        if ($hireDateISO -or $birthDate) {
            $newUserBody.OnPremisesExtensionAttributes = @{}
            if ($hireDateISO) { $newUserBody.OnPremisesExtensionAttributes.employeeHireDate = $hireDateISO }
            if ($birthDate)   { $newUserBody.OnPremisesExtensionAttributes.extensionAttribute3 = $birthDate }
        }

        try {
            # Create the new user in Azure AD
            $createdUser = New-MgUser -BodyParameter $newUserBody
            Write-Host "User created: $($createdUser.Id)"
            $userId = $createdUser.Id
        } catch {
            Write-Warning "Failed to create user: $_"
            continue
        }
    } else {
        Write-Host "User already exists: $userPrincipalName"
        $userId = $existingUser.Id

        # Update user information if needed
        $updateBody = @{
            Department = $division
            JobTitle   = $jobTitle
        }

        if ($hireDateISO -or $birthDate) {
            $updateBody.OnPremisesExtensionAttributes = @{}
            if ($hireDateISO) { $updateBody.OnPremisesExtensionAttributes.employeeHireDate = $hireDateISO }
            if ($birthDate)   { $updateBody.OnPremisesExtensionAttributes.extensionAttribute3 = $birthDate }
        }

        try {
            # Update user attributes in Azure AD
            Update-MgUser -UserId $userId -BodyParameter $updateBody
            Write-Host "Updated user info for $userPrincipalName"
        } catch {
            Write-Warning "Failed to update user: $_"
        }
    }

    # Add the user to the previously validated group
    if ($userId) {
        try {
            New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $userId -ErrorAction Stop
            Write-Host "Added to group '$groupName'"
        } catch {
            if ($_ -match "added object references already exist") {
                Write-Host "User already in group."
            } else {
                Write-Warning "Failed to add to group: $_"
            }
        }
    } else {
        Write-Warning "User ID is missing, cannot add to group."
    }
}
