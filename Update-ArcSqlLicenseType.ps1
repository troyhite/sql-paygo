param(
    [switch]$AutoApprove,
    [string]$LicenseType
)

# Always prompt for license type, ignore parameter
$licenseTypePrompt = "Select the license type to apply:`n1. PAYG`n2. License with Software Assurance`n3. License Only"
$licenseTypeSelection = Read-Host $licenseTypePrompt
switch ($licenseTypeSelection) {
    '1' { $selectedLicenseType = 'PAYG' }
    '2' { $selectedLicenseType = 'LicenseWithSA' }
    '3' { $selectedLicenseType = 'LicenseOnly' }
    default {
        Write-Error 'Invalid selection. Exiting.'
        exit 1
    }
}

# Ensure Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error 'Azure CLI (az) is not installed. Please install it first.'
    exit 1
}

# Login if not already logged in
az account show 1>$null 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Please sign in to Azure...'
    az login
}

# Ensure Azure CLI 'arcdata' extension is installed
$arcdataExt = az extension list --query "[?name=='arcdata']" -o json | ConvertFrom-Json
if (-not $arcdataExt) {
    $install = Read-Host "The Azure CLI 'arcdata' extension is required but not installed. Install it now? (y/n)"
    if ($install -eq 'y') {
        Write-Host "Installing 'arcdata' extension..."
        az extension add --name arcdata
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to install 'arcdata' extension. Exiting."
            exit 1
        }
    } else {
        Write-Error "'arcdata' extension is required. Exiting."
        exit 1
    }
}

# Get all Arc-enabled SQL Server instances in all resource groups
Write-Host 'Fetching Arc-enabled SQL Server instances...'
$servers = az resource list --resource-type "Microsoft.AzureArcData/sqlServerInstances" --query "[].{name:name, rg:resourceGroup}" -o json | ConvertFrom-Json

if (-not $servers) {
    Write-Host 'No Arc-enabled SQL Server instances found.'
    exit 0
}

# Define edition sets for each license type
$paygoOrSAEditions = @('Standard', 'Enterprise')
$licenseOnlyEditions = @('Evaluation', 'Developer', 'Express')

foreach ($server in $servers) {
    $name = $server.name
    $rg = $server.rg
    # Get the full resource details to check the edition
    $resource = az resource show --name $name --resource-group $rg --resource-type Microsoft.AzureArcData/sqlServerInstances -o json | ConvertFrom-Json
    $edition = $resource.properties.edition
    Write-Host "Found: $name in resource group $rg (Edition: $edition)"

    $eligible = $false
    switch ($selectedLicenseType) {
        'PAYG' {
            if ($edition -in $paygoOrSAEditions) { $eligible = $true }
        }
        'LicenseWithSA' {
            if ($edition -in $paygoOrSAEditions) { $eligible = $true }
        }
        'LicenseOnly' {
            if ($edition -in $licenseOnlyEditions) { $eligible = $true }
        }
    }
    if (-not $eligible) {
        Write-Host "Skipping ${name}: Edition is not eligible for $selectedLicenseType."
        continue
    }
    if (-not $AutoApprove) {
        $confirm = Read-Host "Change license type to $selectedLicenseType for $name in $rg (Edition: $edition)? (y/n)"
        if ($confirm -ne 'y') {
            Write-Host "Skipping $name."
            continue
        }
    }
    Write-Host "Updating license type to $selectedLicenseType for $name in $rg..."
    az resource update --ids $(az resource show --name $name --resource-group $rg --resource-type Microsoft.AzureArcData/sqlServerInstances --query id -o tsv) --set properties.licenseType=$selectedLicenseType
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully updated $name."
    } else {
        Write-Host "Failed to update $name."
    }
}

Write-Host 'Done.'