# RVTools to Azure Migrate Converter

This tool is designed to process the output from RVTools and convert it into a format suitable for import into Azure Migrate. This allows for a streamlined process of assessing VMware workloads for migration to Azure.

Requirements

PowerShell: This tool is written in PowerShell and requires a recent version to be installed.
Modules:
ImportExcel: This module is used to read the RVTools Excel output. You can install it using Install-Module -Name ImportExcel -Scope CurrentUser.
Usage

1. Process RVTools Output
To process the data from an RVTools output file:

powershell
Copy code
$convertedData = Read-RVToolsData -InputFile "path_to_RVTools_output.xlsx"
Options:

-ExcludePoweredOff: Exclude VMs that are powered off.
-ExcludeTemplates: Exclude VM templates.
-ExcludeSRM: Exclude SRM placeholders.
-Anonymized: Anonymize VM names using their UUIDs.
-EnhancedDiskInfo: (In Development - Do Not Use) Provides detailed disk information.
2. Generate Azure Migrate CSV
To generate a CSV file in the Azure Migrate import format:

powershell
Copy code
ConvertTo-AzMigrateCSV -RVToolsData $convertedData -OutputFile "AzureMigrate.csv"
Options:

-CPUUtilizationPercentage: Specify the CPU utilization percentage. Default is 50%.
-MemoryUtilizationPercentage: Specify the Memory utilization percentage. Default is 50%.
Examples:

Using Default Utilization Values:

powershell
Copy code
ConvertTo-AzMigrateCSV -RVToolsData $convertedData -OutputFile "AzureMigrate.csv"
Specifying Custom Utilization Values:

powershell
Copy code
ConvertTo-AzMigrateCSV -RVToolsData $convertedData -OutputFile "AzureMigrate.csv" -CPUUtilizationPercentage "90" -MemoryUtilizationPercentage "75"
Notes

The EnhancedDiskInfo switch is currently in development and should not be used as it may not provide accurate results.
It's recommended to adjust CPU and Memory utilization values based on actual monitoring data if available. The default value is 50%, but you can adjust this to better reflect your environment.
