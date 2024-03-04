# RVTools to Azure Migrate Converter

This tool is designed to process the output from RVTools and convert it into a format suitable for import into Azure Migrate. This allows for a streamlined process of assessing VMware workloads for migration to Azure.

## Requirements

- **PowerShell**: This tool is written in PowerShell and requires a recent version to be installed.
  
- **Modules**:
  - `ImportExcel`: This module is used to read the RVTools Excel output. You can install it using `Install-Module -Name ImportExcel -Scope CurrentUser`.
 
## Data Collection using RVTools

To ensure the highest fidelity of data for the migration process, it's essential to gather comprehensive information from your VMware environment. One of the best tools for this purpose is RVTools.

### Downloading RVTools

You can download RVTools from its official website: [RVTools - Download](https://www.robware.net/rvtools/)

### Exporting Data from RVTools

Once you have RVTools installed, you can connect to a vCenter and export all the necessary data. Here's a sample command to achieve this:


```powershell
RVTools.exe -s vcsa.corp.contoso.com -passthrough -c ExportAll2xlsx
```

This command connects to the specified vCenter (`vcsa.corp.contoso.com` in this case) using pass-through authentication. It then exports data from all tabs to an Excel file in the current directory with the default filename.

Ensure you have the necessary permissions and network access to connect to the vCenter and retrieve the data.


# Usage

### 1. Process RVTools Output

To process the data from an RVTools output file:

```powershell
$convertedData = Read-RVToolsData -InputFile "path_to_RVTools_output.xlsx"
```
### Options:

- `-ExcludePoweredOff`: Exclude VMs that are powered off.
- `-ExcludeTemplates`: Exclude VM templates.
- `-ExcludeSRM`: Exclude SRM placeholders.
- `-Anonymized`: Anonymize VM names using their UUIDs.
- `-EnhancedDiskInfo`: (In Development - Do Not Use) Provides detailed disk information.
- `-StorageType` to provide more flexibility in selecting the storage data you want to use from the RVTools output. (Defaults to Provisioned MiB)


## 2. Generate Azure Migrate CSV
To generate a CSV file in the Azure Migrate import format:

```powershell
ConvertTo-AzMigrateCSV -RVToolsData $convertedData -OutputFile "AzureMigrate.csv"
```

### Options:
- `-CPUUtilizationPercentage`: Specify the CPU utilization percentage. Default is 50%, Allowed values are 50, 90, 95, or any integer between 0 and 100.
- `-MemoryUtilizationPercentage`: Specify the Memory utilization percentage. Default is 50%. Allowed values are 50, 90, 95, or any integer between 0 and 100.
- `-StorageType`: Determines which storage column from the RVTools output to use. 
    - **TotalDiskCapacity**: Uses the "Total Disk capacity MiB" column.
    - **Provisioned**: Uses the "Provisioned MiB" column (default).
    - **InUse**: Uses the "In use MiB" column.

Allowed values are 50, 90, 95, or any integer between 0 and 100.


### Why provide option?
This enhancement provides users with the flexibility to choose the storage metric that best fits their migration or analysis needs. Whether you want to consider the total provisioned storage, the actual storage in use, or the total disk capacity, you now have the option to do so with ease

## 3. Upload file to Azure Migrate

The resulting file can then be used to uplaod to Azure Migrate (https://learn.microsoft.com/en-us/azure/migrate/tutorial-discover-import)

# Usage Notes

## Storage Calculation (RV Tools Input)
- **TotalDiskCapacity%**: Uses the "Total Disk capacity MiB" column.
This option uses the Total Disk Capacity in MiB value from RV Tools Input
The sum of all "Capacity MiB" columns in the tab page vDisk for this VM.
- **Provisioned%**: Uses the "Provisioned MiB" column (default).
This option uses the TProvisioned MiB value from RV Tools Input
Total storage space, in MiB, committed to this virtual machine across all datastores.
Essentially an aggregate of the property commited across all datastores that this virtual machine is located on.
- **InUse%**: Uses the "In use MiB" column value from RV Tools Input
Storage in use, space in MiBs, used by this virtual machine on all datastores.


## CPU and Memory Utilization (Azure Migrate Output)

Azure Migrate requires CPU and Memory utilization percentages for a more accurate assessment. This tool provides flexibility in specifying these values to better match your environment's actual utilization or to simulate different scenarios.

The resulting output file can then be used to generate assessment and business cases in Azure Migrate (more info here: https://learn.microsoft.com/en-us/azure/migrate/tutorial-discover-import)


# Default Values
If you do not specify a value for CPU or Memory utilization, the tool will default to 50%. This is a general average and may not reflect the actual utilization of your environment. It's recommended to adjust these values based on monitoring data if available.
If you do not specify a value for the Storage Calculation, it will default to Provisioned. This value uses Total storage space, in MiB, committed to this virtual machine across all datastores.
Essentially an aggregate of the property commited across all datastores that this virtual machine is located on.


# Specifying Utilization
You can specify the CPU and Memory utilization percentages using the `-CPUUtilizationPercentage` and `-MemoryUtilizationPercentage` switches respectively when generating the Azure Migrate CSV. 
Allowed values are 50, 90, 95, or any integer between 0 and 100.


# Examples of Using the Tool

The tool is designed to be intuitive and flexible, catering to various scenarios. Below are some examples to help you get started:

## Basic Usage
To simply convert RVTools data to Azure Migrate CSV format with default settings:

```powershell
$convertedData = Read-RVToolsData -InputFile "path_to_file.xlsx"
ConvertTo-AzMigrateCSV -RVToolsData $convertedData -OutputFile "AzureMigrate.csv"
```

## Excluding Specific VMs
If you want to exclude powered-off VMs, templates, and SRM placeholders:

### Powered Off 

```powershell
$convertedData = Read-RVToolsData -InputFile "path_to_file.xlsx" -ExcludePoweredOff
ConvertTo-AzMigrateCSV -RVToolsData $convertedData -OutputFile "AzureMigrate.csv"
```
### SRM

```powershell
$convertedData = Read-RVToolsData -InputFile "path_to_file.xlsx"
ConvertTo-AzMigrateCSV -RVToolsData $convertedData -OutputFile "AzureMigrate.csv"
```

### Template Objects 

```powershell
$convertedData = Read-RVToolsData -InputFile "path_to_file.xlsx" -ExcludeTemplates
ConvertTo-AzMigrateCSV -RVToolsData $convertedData -OutputFile "AzureMigrate.csv"
```


## Using Different Storage Metrics

```powershell
$convertedData = Read-RVToolsData -InputFile "Path/to/rvtools/output.xlsx"  -StorageType [TotalDiskCapacity/Provisioned/InUse] 
ConvertTo-AzMigrateCSV -RVToolsData $convertedData -OutputFile "AzureMigrate.csv"
```

## Values Explained
- **TotalDiskCapacity%**: Uses the "Total Disk capacity MiB" column.
This option uses the Total Disk Capacity in MiB value from RV Tools Input
The sum of all "Capacity MiB" columns in the tab page vDisk for this VM.
- **Provisioned%**: Uses the "Provisioned MiB" column (default).
This option uses the TProvisioned MiB value from RV Tools Input
Total storage space, in MiB, committed to this virtual machine across all datastores.
Essentially an aggregate of the property commited across all datastores that this virtual machine is located on.
- **InUse%**: Uses the "In use MiB" column value from RV Tools Input
Storage in use, space in MiBs, used by this virtual machine on all datastores.



## Custom CPU and Memory Utilization
To specify custom CPU and memory utilization percentages:
```powershell
$convertedData = Read-RVToolsData -InputFile "path_to_file.xlsx"
ConvertTo-AzMigrateCSV -RVToolsData $convertedData -OutputFile "AzureMigrate.csv" -CPUUtilization 60 -MemoryUtilization 70
```

## Recommendations
- **50%**: This is the default value and represents a general average. Use this if you do not have specific monitoring data.
- **90%**: Represents a high-utilization scenario. This might be suitable for production environments with consistent high loads.
- **95%**: Represents a very high-utilization scenario, nearing capacity. Use this to simulate scenarios where the environment is running close to its limits.

If you have monitoring tools in place, it's best to use the average utilization values from those tools for a more accurate assessment.

## Anonymizing Data
If you want to anonymize the VM names:

```powershell
$convertedData = Read-RVToolsData -InputFile "path_to_file.xlsx" -Anonymized
ConvertTo-AzMigrateCSV -RVToolsData $convertedData -OutputFile "AzureMigrate.csv"
```
## Tips:

Always review the output CSV to ensure the data looks correct before using it for migration.
Regularly update the tool to benefit from new features and improvements.


