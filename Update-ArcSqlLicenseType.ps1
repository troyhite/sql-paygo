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


# Define edition sets for each license type
$paygoOrSAEditions = @('Standard', 'Enterprise')
$licenseOnlyEditions = @('Evaluation', 'Developer', 'Express')

# --- Arc-enabled SQL Server Instances ---
Write-Host 'Fetching Arc-enabled SQL Server instances...'
$arcServers = az resource list --resource-type "Microsoft.AzureArcData/sqlServerInstances" --query "[].{name:name, rg:resourceGroup}" -o json | ConvertFrom-Json
if ($arcServers) {
    foreach ($server in $arcServers) {
        $name = $server.name
        $rg = $server.rg
        $resource = az resource show --name $name --resource-group $rg --resource-type Microsoft.AzureArcData/sqlServerInstances -o json | ConvertFrom-Json
        $edition = $resource.properties.edition
        Write-Host "[Arc] Found: $name in resource group $rg (Edition: $edition)"
        $eligible = $false
        switch ($selectedLicenseType) {
            'PAYG' { if ($edition -in $paygoOrSAEditions) { $eligible = $true } }
            'LicenseWithSA' { if ($edition -in $paygoOrSAEditions) { $eligible = $true } }
            'LicenseOnly' { if ($edition -in $licenseOnlyEditions) { $eligible = $true } }
        }
        if (-not $eligible) {
            Write-Host "[Arc] Skipping ${name}: Edition is not eligible for $selectedLicenseType."
            continue
        }
        if (-not $AutoApprove) {
            $confirm = Read-Host "[Arc] Change license type to $selectedLicenseType for $name in $rg (Edition: $edition)? (y/n)"
            if ($confirm -ne 'y') {
                Write-Host "[Arc] Skipping $name."
                continue
            }
        }
        Write-Host "[Arc] Updating license type to $selectedLicenseType for $name in $rg..."
        az resource update --ids $(az resource show --name $name --resource-group $rg --resource-type Microsoft.AzureArcData/sqlServerInstances --query id -o tsv) --set properties.licenseType=$selectedLicenseType
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[Arc] Successfully updated $name."
        } else {
            Write-Host "[Arc] Failed to update $name."
        }
    }
} else {
    Write-Host '[Arc] No Arc-enabled SQL Server instances found.'
}

# --- SQL Server on Azure VMs (IaaS) ---
Write-Host 'Fetching SQL Server on Azure VMs...'
$sqlVms = az sql vm list -o json | ConvertFrom-Json
if ($sqlVms) {
    foreach ($vm in $sqlVms) {
        $name = $vm.name
        $rg = $vm.resourceGroup
        $edition = $vm.sqlImageSku  # Standard, Enterprise, Developer, Express, Web
        Write-Host "[VM] Found: $name in resource group $rg (Edition: $edition)"
        $eligible = $false
        switch ($selectedLicenseType) {
            'PAYG' { if ($edition -in $paygoOrSAEditions) { $eligible = $true } }
            'LicenseWithSA' { if ($edition -in $paygoOrSAEditions) { $eligible = $true } }
            'LicenseOnly' { if ($edition -in $licenseOnlyEditions) { $eligible = $true } }
        }
        if (-not $eligible) {
            Write-Host "[VM] Skipping ${name}: Edition is not eligible for $selectedLicenseType."
            continue
        }
        if (-not $AutoApprove) {
            $confirm = Read-Host "[VM] Change license type to $selectedLicenseType for $name in $rg (Edition: $edition)? (y/n)"
            if ($confirm -ne 'y') {
                Write-Host "[VM] Skipping $name."
                continue
            }
        }
        Write-Host "[VM] Updating license type to $selectedLicenseType for $name in $rg..."
        az sql vm update --name $name --resource-group $rg --license-type $selectedLicenseType
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[VM] Successfully updated $name."
        } else {
            Write-Host "[VM] Failed to update $name."
        }
    }
} else {
    Write-Host '[VM] No SQL Server VMs found.'
}

# --- Azure SQL Database (PaaS) ---
Write-Host 'Fetching Azure SQL Databases (PaaS)...'
# Single/Elastic Pool DBs
$sqlServers = az sql server list -o json | ConvertFrom-Json
if ($sqlServers) {
    foreach ($sqlServer in $sqlServers) {
        $serverName = $sqlServer.name
        $serverRg = $sqlServer.resourceGroup
        $dbs = az sql db list --server $serverName --resource-group $serverRg -o json | ConvertFrom-Json
        foreach ($db in $dbs) {
            $dbName = $db.name
            $edition = $db.sku.tier  # Basic, Standard, Premium, GeneralPurpose, BusinessCritical, Hyperscale
            Write-Host "[PaaS-DB] Found: $dbName on server $serverName (Edition: $edition)"
            # For PaaS, only LicenseIncluded and BasePrice are valid
            $eligible = $false
            $targetLicense = ''
            switch ($selectedLicenseType) {
                'PAYG' { $targetLicense = 'LicenseIncluded'; $eligible = $true }
                'LicenseWithSA' { $targetLicense = 'BasePrice'; $eligible = $true }
                'LicenseOnly' { $targetLicense = 'BasePrice'; $eligible = $true } # No direct mapping, treat as BasePrice
            }
            if (-not $eligible) {
                Write-Host ("[PaaS-DB] Skipping {0}: Not eligible for {1}." -f $dbName, $selectedLicenseType)
                continue
            }
            if (-not $AutoApprove) {
                $confirm = Read-Host "[PaaS-DB] Change license type to $targetLicense for $dbName on $serverName? (y/n)"
                if ($confirm -ne 'y') {
                    Write-Host "[PaaS-DB] Skipping $dbName."
                    continue
                }
            }
            Write-Host "[PaaS-DB] Updating license type to $targetLicense for $dbName on $serverName..."
            az sql db update --name $dbName --server $serverName --resource-group $serverRg --license-type $targetLicense
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[PaaS-DB] Successfully updated $dbName."
            } else {
                Write-Host "[PaaS-DB] Failed to update $dbName."
            }
        }
    }
} else {
    Write-Host '[PaaS-DB] No Azure SQL Servers found.'
}

# Managed Instances
Write-Host 'Fetching Azure SQL Managed Instances...'
$mis = az sql mi list -o json | ConvertFrom-Json
if ($mis) {
    foreach ($mi in $mis) {
        $miName = $mi.name
        $miRg = $mi.resourceGroup
        $edition = $mi.sku.tier
        Write-Host "[PaaS-MI] Found: $miName (Edition: $edition)"
        $eligible = $false
        $targetLicense = ''
        switch ($selectedLicenseType) {
            'PAYG' { $targetLicense = 'LicenseIncluded'; $eligible = $true }
            'LicenseWithSA' { $targetLicense = 'BasePrice'; $eligible = $true }
            'LicenseOnly' { $targetLicense = 'BasePrice'; $eligible = $true } # No direct mapping, treat as BasePrice
        }
        if (-not $eligible) {
            Write-Host ("[PaaS-MI] Skipping {0}: Not eligible for {1}." -f $miName, $selectedLicenseType)
            continue
        }
        if (-not $AutoApprove) {
            $confirm = Read-Host "[PaaS-MI] Change license type to $targetLicense for $miName? (y/n)"
            if ($confirm -ne 'y') {
                Write-Host "[PaaS-MI] Skipping $miName."
                continue
            }
        }
        Write-Host "[PaaS-MI] Updating license type to $targetLicense for $miName..."
        az sql mi update --name $miName --resource-group $miRg --license-type $targetLicense
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[PaaS-MI] Successfully updated $miName."
        } else {
            Write-Host "[PaaS-MI] Failed to update $miName."
        }
    }
} else {
    Write-Host '[PaaS-MI] No Azure SQL Managed Instances found.'
}


# --- Post-Update Report: Confirm SA is off for all SQL if PAYG selected ---
if ($selectedLicenseType -eq 'PAYG') {
    Write-Host '--- Post-Update Report: Confirming Software Assurance (SA) is OFF for all SQL resources ---'

    # Arc-enabled SQL Server
    $arcSaIssues = @()
    $arcServers = az resource list --resource-type "Microsoft.AzureArcData/sqlServerInstances" --query "[].{name:name, rg:resourceGroup}" -o json | ConvertFrom-Json
    if ($arcServers) {
        foreach ($server in $arcServers) {
            $name = $server.name
            $rg = $server.rg
            $resource = az resource show --name $name --resource-group $rg --resource-type Microsoft.AzureArcData/sqlServerInstances -o json | ConvertFrom-Json
            $licenseType = $resource.properties.licenseType
            if ($licenseType -eq 'LicenseWithSA') {
                $arcSaIssues += "[Arc] $name in $rg has Software Assurance enabled (licenseType=LicenseWithSA)"
            }
        }
    }

    # SQL Server on Azure VMs
    $vmSaIssues = @()
    $sqlVms = az sql vm list -o json | ConvertFrom-Json
    if ($sqlVms) {
        foreach ($vm in $sqlVms) {
            $name = $vm.name
            $rg = $vm.resourceGroup
            $licenseType = $vm.licenseType
            if ($licenseType -eq 'LicenseWithSA') {
                $vmSaIssues += "[VM] $name in $rg has Software Assurance enabled (licenseType=LicenseWithSA)"
            }
        }
    }

    # Azure SQL Database (PaaS)
    $paasSaIssues = @()
    $sqlServers = az sql server list -o json | ConvertFrom-Json
    if ($sqlServers) {
        foreach ($sqlServer in $sqlServers) {
            $serverName = $sqlServer.name
            $serverRg = $sqlServer.resourceGroup
            $dbs = az sql db list --server $serverName --resource-group $serverRg -o json | ConvertFrom-Json
            foreach ($db in $dbs) {
                $dbName = $db.name
                $licenseType = $db.licenseType
                if ($licenseType -eq 'BasePrice') {
                    $paasSaIssues += "[PaaS-DB] $dbName on $serverName has Software Assurance enabled (licenseType=BasePrice)"
                }
            }
        }
    }

    # Managed Instances
    $miSaIssues = @()
    $mis = az sql mi list -o json | ConvertFrom-Json
    if ($mis) {
        foreach ($mi in $mis) {
            $miName = $mi.name
            $miRg = $mi.resourceGroup
            $licenseType = $mi.licenseType
            if ($licenseType -eq 'BasePrice') {
                $miSaIssues += "[PaaS-MI] $miName has Software Assurance enabled (licenseType=BasePrice)"
            }
        }
    }

    if ($arcSaIssues.Count -eq 0 -and $vmSaIssues.Count -eq 0 -and $paasSaIssues.Count -eq 0 -and $miSaIssues.Count -eq 0) {
        Write-Host 'All SQL resources are confirmed to have Software Assurance OFF (no LicenseWithSA/BasePrice detected).'
    } else {
        Write-Host 'WARNING: The following SQL resources still have Software Assurance enabled:'
        $arcSaIssues + $vmSaIssues + $paasSaIssues + $miSaIssues | ForEach-Object { Write-Host $_ }
    }
}

Write-Host 'Done.'