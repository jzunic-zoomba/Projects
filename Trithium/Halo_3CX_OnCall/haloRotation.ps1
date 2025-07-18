# ================================
# OAuth2 Token Request and Technician Rotation for HaloPSA
# ================================

# Set environment-based credentials for OAuth2 authentication
$ClientId = $env:HALO_CLIENT_ID           # Replace with your Halo client ID (stored in environment variable)
$ClientSecret = $env:HALO_CLIENT_SECRET   # Replace with your Halo client secret (stored in environment variable)

# Set the OAuth2 token endpoint for HaloPSA
$TokenUrl = "https://<your-halo-domain>.halo.com/auth/token"

# Retrieve technician names from environment variables
$Technician1Name = $env:EMP1              # Name of technician 1
$Technician2Name = $env:EMP2              # Name of technician 2
$Technician3Name = $env:EMP3              # Name of technician 3

# Manually defined technician user IDs (should match your internal IDs in HaloPSA)
$Technician1ID = 9
$Technician2ID = 11
$Technician3ID = 4

# Role ID for the target role being updated (from environment variable or hardcoded if needed)
$RoleID = $env:ROLEID                     # Example: 16

# Halo base URL
$base = "https://<your-halo-domain>.halo.com"

# Compose body for OAuth2 token request
$TokenBody = @{
    grant_type    = "client_credentials"  # Using client credentials grant
    client_id     = $ClientId
    client_secret = $ClientSecret
}

# Attempt to retrieve an OAuth2 access token
try {
    $TokenResponse = Invoke-RestMethod -Method Post -Uri $TokenUrl -Body $TokenBody -ContentType "application/x-www-form-urlencoded"
    $AccessToken = $TokenResponse.access_token
    Write-Output "Access token retrieved successfully."
}
catch {
    Write-Error "Token request failed: $($_.Exception.Message)"
    exit 1
}

# ================================
# Calculate Technician Rotation Based on Week Number
# ================================

$Today = Get-Date  # Get today's date
$Calendar = [System.Globalization.CultureInfo]::InvariantCulture.Calendar  # Use invariant culture calendar
$WeekNumber = $Calendar.GetWeekOfYear($Today, [System.Globalization.CalendarWeekRule]::FirstFourDayWeek, [System.DayOfWeek]::Monday)

# Use modulus to rotate through 3 technicians weekly
$Index = $WeekNumber % 3

# Assign technician based on calculated index
switch ($Index) {
    0 {
        $AssignedTechName = $Technician1Name
        $AssignedTechID = [int]$Technician1ID
    }
    1 {
        $AssignedTechName = $Technician2Name
        $AssignedTechID = [int]$Technician2ID
    }
    2 {
        $AssignedTechName = $Technician3Name
        $AssignedTechID = [int]$Technician3ID
    }
}

Write-Output "Assigned Tech: '$AssignedTechName' with ID: '$AssignedTechID'"

# ================================
# Construct JSON Payload for Role Update
# ================================

# Create nested agent object for payload
$agent = @{
    id = [int]$AssignedTechID          # Technician's Halo ID
    use = "agent"                      # Designation in role context
    namewithinactive = $AssignedTechName  # Display name of technician
}

# Main payload object including role and access settings
$data = @{
    id_int = [int]$RoleID              # Role ID being updated
    agents = @($agent)                 # Array of assigned agents (one for rotation)
    access_control_level = 3           # Access control level to apply
    id = "<role-guid-here>"            # Optional: GUID of the role (required in some setups)
}

# Convert PowerShell object to JSON string and wrap in array
$json = "[" + ($data | ConvertTo-Json -Depth 3 -Compress) + "]"

# ================================
# Send API Request to Update Role
# ================================

# Define endpoint for roles update in Halo
$UpdateUrl = "$base/api/Roles?access_control_level=2&isconfig=true"

# First attempt to update the role (redundant call removed for simplicity)
try {
    $UpdateResponse = Invoke-RestMethod -Method Post -Uri $UpdateUrl `
        -Headers @{ Authorization = "Bearer $AccessToken" } `
        -Body $json `
        -ContentType "application/json"

    Write-Output "Role updated successfully."
    $UpdateResponse
}
catch {
    # Output error status code and message if the request fails
    Write-Error "Failed to update role: $($_.Exception.Response.StatusCode) - $($_.Exception.Message)"
}
