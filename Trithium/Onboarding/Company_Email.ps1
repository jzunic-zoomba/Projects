param (
    [string]$birthDate,           # Employee's birth date
    [SecureString]$password,      # Employee's secure password
    [string]$email,               # Employee's email address
    [string]$firstName,           # Employee's first name
    [string]$lastName             # Employee's last name
)

# Simulate progress for visual feedback
Write-Host "Finalizing details" -NoNewline -ForegroundColor Yellow 
Start-Sleep -Seconds 3
Write-Host "." -NoNewline -ForegroundColor Yellow
Start-Sleep -Seconds 3
Write-Host "." -NoNewline -ForegroundColor Yellow
Start-Sleep -Seconds 3
Write-Host "." -ForegroundColor Yellow
Start-Sleep -Seconds 1

# Output email section header
Write-Host "/---------------------Email-------------------\" -ForegroundColor Cyan

# Prompt for the manager's email address (recipient of onboarding notice)
$managerEmail = Read-Host "Enter Manager Email"

# Define configurable settings (replace these values in a production environment)
$smtpServer = "smtp.yourdomain.com"               # <-- Replace with your actual SMTP server
$from = "support@yourdomain.com"                  # <-- Replace with your sender address
$to = $managerEmail                               # Email recipient
$subject = "Onboarding Process has begun"         # Subject line

# Compose the email body using a here-string
$body = @"
Hello $firstName $lastName,

Thank you for submitting your onboarding request.

Your new employee, $firstName $lastName, has been added to Active Directory. Required licenses should sync within the next 24 hours.
If you experience any issues, please contact the IT support team at [Support Phone] or [Support Email].

User's password: $password

Best regards,  
[Your Company Name] Support Team
"@

# Send the onboarding email
Send-MailMessage -From $from -To $to -Subject $subject -Body $body -SmtpServer $smtpServer

# Final output to confirm email was sent
Write-Host "Email sent, onboarding completed" -ForegroundColor Green
Write-Host "\---------------------------------------------/" -ForegroundColor Cyan
