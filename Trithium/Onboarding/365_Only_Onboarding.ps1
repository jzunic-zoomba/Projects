# Import required Microsoft Graph modules
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Groups
Import-Module Microsoft.Graph.Authentication

# Connect to Microsoft Graph with required permissions
Write-Host "Connecting to Microsoft Graph..."
Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "Directory.ReadWrite.All"

# Display context information for verification
$context = Get-MgContext
Write-Host "`nConnected to Microsoft Graph.`n"
Write-Host "Connected Directory:"
Write-Host "Tenant Display Name : $($context.TenantDisplayName)"
Write-Host "Tenant ID           : $($context.TenantId)"
Write-Host "Account             : $($context.Account)"

# Define group display name (replace with actual group name)
$groupName = "REPLACE_WITH_GROUP_NAME"

# Check if the group already exists
$group = Get-MgGroup -Filter "displayName eq '$groupName'" -ErrorAction SilentlyContinue

# Create the group if it doesn't exist
if (-not $group) {
    Write-Host "`nGroup '$groupName' not found. Creating it..."
    $group = New-MgGroup -DisplayName $groupName `
        -MailEnabled:$false `
        -MailNickname "REPLACE_WITH_GROUP_ALIAS" `
        -SecurityEnabled:$true `
        -GroupTypes @()
    Write-Host "Group '$groupName' created: $($group.Id)"
} else {
    Write-Host "`nGroup '$groupName' already exists: $($group.Id)"
}

# Path to the input CSV file
$csvPath = ".\users.csv"
Write-Host "`nUsing CSV from path: $csvPath"
$users = Import-Csv $csvPath

# Iterate through each user in the CSV
foreach ($user in $users) {
    # Normalize name fields
    $firstName = $user.'First Name'.Trim()
    $lastName = $user.'Last Name'.Trim().Split(" ")[0]
    $fullName = "$firstName $lastName"

    # Construct userPrincipalName (replace with your domain)
    $userPrincipalName = "$firstName.$lastName@yourdomain.com".ToLower()

    Write-Host "`nProcessing $fullName <$userPrincipalName>..."

    ### Handle Hire Date (format: MM/DD/YY) ###
    $hireDateISO = $null
    $rawHireDate = $user.'Hire Date (MM/DD/YY)' -as [string]
    if ($rawHireDate -and $rawHireDate -match '^\d{1,2}/\d{1,2}/\d{2}$') {
        try {
            $parsedHireDate = [datetime]::ParseExact($rawHireDate, 'MM/dd/yy', $null)
            $hireDateISO = $parsedHireDate.ToString("yyyy-MM-dd")
        } catch {
            Write-Warning "Invalid hire date for $fullName: '$rawHireDate'"
        }
    }

    ### Handle Birth Date (format: MM/YY) ###
    $birthDate = $user.'Birth Date (MM/YY)' -as [string]

    # Custom directory extension attributes
    $additionalProps = @{}
    if ($hireDateISO) { $additionalProps.employeeHireDate = $hireDateISO }
    if ($birthDate)    { $additionalProps.extensionAttribute3 = $birthDate }

    if ($additionalProps.Count -eq 0) { $additionalProps = $null }

    ### Password Configuration (placeholder only — replace with secure password handling) ###
    $password = "REPLACE_WITH_SECURE_PASSWORD"
    $passwordProfile = @{
        ForceChangePasswordNextSignIn = $true
        Password = $password
    }

    ### Check if the user already exists ###
    $existingUser = Get-MgUser -UserId $userPrincipalName -ErrorAction SilentlyContinue

    if (-not $existingUser) {
        Write-Host "Creating new Azure AD user: $userPrincipalName..."

        $newUserParams = @{
            AccountEnabled    = $true
            DisplayName       = $fullName
            MailNickname      = "$firstName$lastName"
            UserPrincipalName = $userPrincipalName
            GivenName         = $firstName
            Surname           = $lastName
            PasswordProfile   = $passwordProfile
        }

        if ($additionalProps) {
            $newUserParams['AdditionalProperties'] = $additionalProps
        }

        try {
            $createdUser = New-MgUser @newUserParams
            Write-Host "User created: $($createdUser.Id)"
        } catch {
            Write-Warning "Failed to create user: $_"
            continue
        }

        $userId = $createdUser.Id
    } else {
        Write-Host "User already exists: $userPrincipalName"
        $userId = $existingUser.Id
    }

    ### Add the user to the group ###
    if ($userId) {
        try {
            New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $userId -ErrorAction Stop
            Write-Host "Added to group '$groupName'"
        } catch {
            Write-Warning "Failed to add to group: $_"
        }
    } else {
        Write-Warning "User ID is missing, cannot add to group."
    }
}
