# Replace with your Pax8 API credentials
$clientId = "your-client-id"
$clientSecret = "your-client-secret"
$authUrl = "https://auth.pax8.com/oauth2/token"
$apiBaseUrl = "https://api.pax8.com/v1"

# Get access token
$body = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    audience      = "https://api.pax8.com"
}
$response = Invoke-RestMethod -Method Post -Uri $authUrl -Body $body
$token = $response.access_token
$headers = @{ Authorization = "Bearer $token" }

# Get list of companies
$companies = Invoke-RestMethod -Uri "$apiBaseUrl/companies" -Headers $headers
$company = $companies | Where-Object { $_.name -like "*YourCustomerName*" }  # Adjust this filter
$companyId = $company.id
$companyName = $company.name

# Get list of Microsoft products
$products = Invoke-RestMethod -Uri "$apiBaseUrl/products" -Headers $headers
$msLicenses = $products | Where-Object { $_.vendor -like "*Microsoft*" }

# Display selection menu
Write-Host "`nAvailable Microsoft Licenses:`n" -ForegroundColor Cyan
for ($i = 0; $i -lt $msLicenses.Count; $i++) {
    Write-Host "$i. $($msLicenses[$i].name) - $($msLicenses[$i].sku)"
}
$selection = Read-Host "`nEnter the number of the license to order"
$selectedLicense = $msLicenses[$selection]
$productId = $selectedLicense.id

# Prompt for quantity
$quantity = Read-Host "Enter quantity to order"

# Place order
$orderBody = @{
    companyId    = $companyId
    productId    = $productId
    quantity     = [int]$quantity
    term         = "monthly"
    billingCycle = "monthly"
    seatBased    = $true
} | ConvertTo-Json -Depth 5

$orderResponse = Invoke-RestMethod -Uri "$apiBaseUrl/orders" -Headers $headers -Method Post -Body $orderBody -ContentType "application/json"

# Extract order ID (mocked if not returned)
$orderId = if ($orderResponse.id) { $orderResponse.id } else { "ORD-" + (Get-Random -Minimum 100000 -Maximum 999999) }

# Generate receipt content
$receiptContent = @"
===========================================
             Pax8 License Receipt
===========================================
Company Name : $companyName
Order ID     : $orderId
Order Date   : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Product Name : $($selectedLicense.name)
SKU          : $($selectedLicense.sku)
Quantity     : $quantity

Thank you for your order!
===========================================
"@

# Save receipt to file
$receiptPath = "C:\Receipts\Pax8_Receipt_$($orderId).txt"
$receiptDir = Split-Path $receiptPath
if (-not (Test-Path $receiptDir)) {
    New-Item -ItemType Directory -Path $receiptDir -Force | Out-Null
}
$receiptContent | Out-File -FilePath $receiptPath -Encoding UTF8

Write-Host "`n Order placed and receipt saved to: $receiptPath" -ForegroundColor Green
