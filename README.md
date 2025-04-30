# sqlpaygo.ps1

## Overview

`sqlpaygo.ps1` is a PowerShell script designed to automate the process of updating the license type of all Arc-enabled SQL Server instances in your Azure subscription to Pay-As-You-Go (PAYG). The script ensures that only eligible SQL Server editions (Standard or Enterprise) are updated, and provides interactive or automatic approval options.

## Features
- Checks for Azure CLI and required 'arcdata' extension
- Authenticates with Azure if not already logged in
- Enumerates all Arc-enabled SQL Server instances across all resource groups
- Filters for Standard and Enterprise editions
- Prompts for confirmation before updating (unless auto-approve is enabled)
- Updates the license type to PAYG
- Provides clear status messages for each operation

## Prerequisites
- Windows PowerShell or PowerShell Core
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and available in your PATH
- Azure CLI 'arcdata' extension (the script will prompt to install if missing)
- Sufficient permissions to list and update Azure Arc-enabled SQL Server resources

## Usage

### Interactive Mode
By default, the script will prompt for confirmation before updating each eligible SQL Server instance:

```powershell
./sqlpaygo.ps1
```

### Automatic Approval
To automatically approve all updates without prompting, use the `-AutoApprove` switch:

```powershell
./sqlpaygo.ps1 -AutoApprove
```

## What the Script Does
1. Verifies that the Azure CLI is installed.
2. Ensures you are logged in to Azure.
3. Checks for the 'arcdata' extension and installs it if needed.
4. Lists all Arc-enabled SQL Server instances in your subscription.
5. For each instance:
    - Checks if the edition is Standard or Enterprise.
    - Prompts for confirmation (unless `-AutoApprove` is used).
    - Updates the license type to PAYG.
    - Reports success or failure for each update.

## Example Output
```
Fetching Arc-enabled SQL Server instances...
Found: sqlserver1 in resource group rg-demo (Edition: Enterprise)
Change license type to PAYG for sqlserver1 in rg-demo (Edition: Enterprise)? (y/n) y
Updating license type to PAYG for sqlserver1 in rg-demo...
Successfully updated sqlserver1.
Done.
```

## Notes
- The script will skip any SQL Server instances that are not Standard or Enterprise edition.
- If no eligible Arc-enabled SQL Server instances are found, the script will exit gracefully.

## License
This script is provided as-is, without warranty. Use at your own risk.
