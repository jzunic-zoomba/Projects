# Set global error preference to stop on all errors
$ErrorActionPreference = "Stop"

# Variables
$varDate = Get-Date -Format "yyyyMMdd_HHmmss"  # Get current timestamp for log file naming
$logDirectory = "C:\Temp"  # Directory where log file will be stored (change if needed)
$varLog = "$logDirectory\userlist_$($varDate).log"  # Log file path with timestamp
$csvPath = "C:\Path\To\Your\CSV\users.csv"  # Path to the CSV file (change as needed)

# Ensure log directory exists
if (-not (Test-Path -Path $logDirectory)) {
    New-Item -Path $logDirectory -ItemType Directory | Out-Null
}

# Create Log with header
"Email,Hire_Date,Birth_Date_(MM/DD),Status,Error" | Out-File $varLog
Write-Host "Log file created at: $varLog"

# Import CSV containing user information
$varCsv = Import-Csv $csvPath

# Loop through each user in the CSV file
foreach ($user in $varCsv) {
    try {
        # Extract values for each column in the CSV
        $email = $user.PSObject.Properties['Work_Email'].Value
        $hireDateRaw = $user.PSObject.Properties['Hire_Date'].Value
        $birthDateRaw = $user.PSObject.Properties['Birth_Date_(MM/DD)'].Value

        # If email is missing, throw an error
        if (-not $email) {
            throw "Missing Work_Email"
        }

        Write-Host "Processing: ${email}"

        # Validate that both Hire Date and Birth Date are provided
        if ([string]::IsNullOrWhiteSpace($hireDateRaw) -or [string]::IsNullOrWhiteSpace($birthDateRaw)) {
            throw "Missing or empty Hire_Date or Birth_Date"
        }

        # Try to format Hire Date to required format (Universal Time)
        try {
            $varUserHireDateFormatted = (Get-Date $hireDateRaw).ToUniversalTime().ToString("yyyyMMddHHmmss") + ".0Z"
        } catch {
            throw "Invalid Hire_Date format: '${hireDateRaw}'"
        }

        # Try to format Birth Date (MM/DD) to required format (MMDD)
        try {
            $varUserBirthDateFormatted = (Get-Date "$birthDateRaw/1900").ToString("MMdd")
        } catch {
            throw "Invalid Birth_Date format: '${birthDateRaw}'"
        }

        # Retrieve Active Directory user by their email address
        $varUser = Get-ADUser -Filter {mail -eq $email} -ErrorAction Stop

        # If user exists, update their attributes
        if ($varUser) {
            Write-Host "User found: $($varUser.SamAccountName)"

            # Update the user attributes with formatted Hire Date and Birth Date
            Set-ADUser $varUser.SamAccountName -Replace @{
                "msDS-cloudExtensionAttribute1" = $varUserHireDateFormatted
                "msDS-cloudExtensionAttribute3" = $varUserBirthDateFormatted
            } -ErrorAction Stop

            # Log the successful update
            "${email},${hireDateRaw},${birthDateRaw},Updated," | Out-File $varLog -Append
        } else {
            # If user not found, log as "Not Found"
            "${email},${hireDateRaw},${birthDateRaw},Not Found," | Out-File $varLog -Append
        }
    } catch {
        # In case of an error, log the error message
        $email = if ($user.PSObject.Properties['Work_Email']) { $user.PSObject.Properties['Work_Email'].Value } else { "UNKNOWN" }
        "${email},${hireDateRaw},${birthDateRaw},ERROR,$($_.Exception.Message)" | Out-File $varLog -Append
        Write-Host "Error processing ${email}: $($_.Exception.Message)"
    }
}

Write-Host "Script completed. Check log file at: $varLog"
