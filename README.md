
# Update-ArcSqlLicenseType.ps1

## Overview

`Update-ArcSqlLicenseType.ps1` is a PowerShell script designed to automate the process of updating the license type for **all SQL Server resources in Azure**. This includes:

- Arc-enabled SQL Server instances
- SQL Server on Azure VMs (IaaS)
- Azure SQL Database (PaaS: single, elastic pool, and managed instance)

The script supports all license type configurations: Pay-As-You-Go (PAYG), License with Software Assurance, and License Only. It ensures that only eligible SQL Server editions are updated, and provides interactive or automatic approval options. After running in PAYG mode, the script also reports any SQL resources that still have Software Assurance enabled.

## Features

- Checks for Azure CLI and required 'arcdata' extension
- Authenticates with Azure if not already logged in
- Enumerates all Arc-enabled SQL Server instances, SQL Server on Azure VMs, and Azure SQL Databases (single, pool, managed instance)
- Prompts for the license type you want to apply (PAYG, License with Software Assurance, or License Only)
- Filters for eligible editions based on the selected license type:
  - PAYG and License with Software Assurance: Standard or Enterprise (where applicable)
  - License Only: Evaluation, Developer, or Express (where applicable)
- Prompts for confirmation before updating (unless auto-approve is enabled)
- Updates the license type for each eligible instance, VM, or database
- Provides clear status messages for each operation
- **After running in PAYG mode, generates a report confirming that Software Assurance is OFF for all SQL resources, and warns if any are still enabled**

## Prerequisites

- Windows PowerShell or PowerShell Core
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and available in your PATH
- Azure CLI 'arcdata' extension (the script will prompt to install if missing)
- **Azure permissions:**
  - To list and update Azure Arc-enabled SQL Server resources, you need the following Azure RBAC roles:
    - You have a [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor) role in at least one of the Azure subscriptions that your organization created.
    - You have a [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor) role for the resource group in which the SQL Server instance will be registered. For details, see [Managed Azure resource groups](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal).
  - For more details, see the official documentation on [Azure built-in roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles) and [Azure Arc-enabled SQL Server permissions](https://learn.microsoft.com/en-us/sql/sql-server/azure-arc/manage-configuration?view=sql-server-ver16&tabs=azure#prerequisites)

## Usage

### Interactive Mode

By default, the script will prompt you to select the license type and for confirmation before updating each eligible SQL Server resource:

```powershell
./Update-ArcSqlLicenseType.ps1
```

### Automatic Approval

To automatically approve all updates without prompting for each instance, use the `-AutoApprove` switch:

```powershell
./Update-ArcSqlLicenseType.ps1 -AutoApprove
```

## What the Script Does

1. Prompts you to select the license type to apply (PAYG, License with Software Assurance, or License Only).
2. Verifies that the Azure CLI is installed.
3. Ensures you are logged in to Azure.
4. Checks for the 'arcdata' extension and installs it if needed.
5. Lists all Arc-enabled SQL Server instances, SQL Server on Azure VMs, and Azure SQL Databases (single, pool, managed instance) in your subscription.
6. For each resource:
    - Checks if the edition is eligible for the selected license type.
    - Prompts for confirmation (unless `-AutoApprove` is used).
    - Updates the license type.
    - Reports success or failure for each update.
7. **If PAYG is selected, runs a post-update report to confirm that Software Assurance is OFF for all SQL resources, and warns if any are still enabled.**

## Example Output

```text
Select the license type to apply:
1. PAYG
2. License with Software Assurance
3. License Only
Fetching Arc-enabled SQL Server instances...
[Arc] Found: sqlserver1 in resource group rg-demo (Edition: Enterprise)
[Arc] Change license type to PAYG for sqlserver1 in rg-demo (Edition: Enterprise)? (y/n) y
[Arc] Updating license type to PAYG for sqlserver1 in rg-demo...
[Arc] Successfully updated sqlserver1.
Fetching SQL Server on Azure VMs...
[VM] Found: sqlvm1 in resource group rg-demo (Edition: Standard)
[VM] Updating license type to PAYG for sqlvm1 in rg-demo...
[VM] Successfully updated sqlvm1.
Fetching Azure SQL Databases (PaaS)...
[PaaS-DB] Found: sqldb1 on server sqlserver1 (Edition: Standard)
[PaaS-DB] Updating license type to LicenseIncluded for sqldb1 on sqlserver1...
[PaaS-DB] Successfully updated sqldb1.
Fetching Azure SQL Managed Instances...
[PaaS-MI] Found: sqlmi1 (Edition: GeneralPurpose)
[PaaS-MI] Updating license type to LicenseIncluded for sqlmi1...
[PaaS-MI] Successfully updated sqlmi1.
--- Post-Update Report: Confirming Software Assurance (SA) is OFF for all SQL resources ---
All SQL resources are confirmed to have Software Assurance OFF (no LicenseWithSA/BasePrice detected).
Done.
```

## Notes

- The script will skip any SQL Server resources that are not eligible for the selected license type.
- If no eligible SQL Server resources are found, the script will exit gracefully.
- When running in PAYG mode, a post-update report will confirm that Software Assurance is OFF for all SQL resources, and warn if any are still enabled.

## License
This script is provided as-is, without warranty. Use at your own risk.
