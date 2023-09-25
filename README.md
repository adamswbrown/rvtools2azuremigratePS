# RVTools to Azure Migrate Converter

This tool is designed to process the output from RVTools and convert it into a format suitable for import into Azure Migrate. This allows for a streamlined process of assessing VMware workloads for migration to Azure.

## Requirements

- **PowerShell**: This tool is written in PowerShell and requires a recent version to be installed.
  
- **Modules**:
  - `ImportExcel`: This module is used to read the RVTools Excel output. You can install it using `Install-Module -Name ImportExcel -Scope CurrentUser`.

## Usage

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

## 2. Generate Azure Migrate CSV
To generate a CSV file in the Azure Migrate import format:

```powershell
ConvertTo-AzMigrateCSV -RVToolsData $convertedData -OutputFile "AzureMigrate.csv"
```

### Options:
- `-CPUUtilizationPercentage`: Specify the CPU utilization percentage. Default is 50%, Use 'Custom' to specify your own values
- `-MemoryUtilizationPercentage`: Specify the Memory utilization percentage. Default is 50%. Use 'Custom' to specify your own values

## CPU and Memory Utilization

Azure Migrate requires CPU and Memory utilization percentages for a more accurate assessment. This tool provides flexibility in specifying these values to better match your environment's actual utilization or to simulate different scenarios.

### Default Values
If you do not specify a value for CPU or Memory utilization, the tool will default to 50%. This is a general average and may not reflect the actual utilization of your environment. It's recommended to adjust these values based on monitoring data if available.

### Specifying Utilization
You can specify the CPU and Memory utilization percentages using the `-CPUUtilizationPercentage` and `-MemoryUtilizationPercentage` switches respectively when generating the Azure Migrate CSV.

For example:

```powershell
ConvertTo-AzMigrateCSV -RVToolsData $convertedData -OutputFile "AzureMigrate.csv" -CPUUtilizationPercentage "90" -MemoryUtilizationPercentage "75"
```
In the above command, the CPU utilization is set to 90% and Memory utilization is set to 75%.

### Recommendations
- **50%**: This is the default value and represents a general average. Use this if you do not have specific monitoring data.
- **90%**: Represents a high-utilization scenario. This might be suitable for production environments with consistent high loads.
- **95%**: Represents a very high-utilization scenario, nearing capacity. Use this to simulate scenarios where the environment is running close to its limits.

If you have monitoring tools in place, it's best to use the average utilization values from those tools for a more accurate assessment.



### Examples:

#### Using Default Utilization Values:
```powershell
# Example usage:
#Read RVTools 
$convertedData = Read-RVToolsData -InputFile "Path/to/rvtools/output.xlsx"
#Make Azure Migrate
ConvertTo-AzMigrateCSV -RVToolsData $convertedData -OutputFile AzureMigrate.csv -CPUUtilization 50 -MemoryUtilization 50
```
#### Using Custom Utilization Values:
```powershell
# Example usage:
#Read RVTools 
$convertedData = Read-RVToolsData -InputFile "Path/to/rvtools/output.xlsx"
#Make Azure Migrate
ConvertTo-AzMigrateCSV -RVToolsData $convertedData -OutputFile AzureMigrate.csv -CPUUtilization Custom -MemoryUtilizationPercentage Custom
```
