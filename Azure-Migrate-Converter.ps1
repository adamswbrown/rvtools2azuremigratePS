function Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "DEBUG", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "HH:mm:ss"
    switch ($Level) {
        "INFO" {
            Write-Host "[$timestamp] INFO     $Message" -ForegroundColor Yellow
        }
        "DEBUG" {
            Write-Host "[$timestamp] DEBUG    $Message" -ForegroundColor DarkYellow
        }
        "ERROR" {
            Write-Host "[$timestamp] ERROR    $Message" -ForegroundColor Red
        }
    }
}

function Read-RVToolsData {
    param (
        [Parameter(Mandatory=$true)]
        [string]$InputFile,

        [switch]$ExcludePoweredOff,
        [switch]$ExcludeTemplates,
        [switch]$ExcludeSRM,
        [switch]$Anonymized,
        [switch]$EnhancedDiskInfo
    )

    # Constants
    $VINFO_SHEET_NAME = "vInfo"
    $VDISK_SHEET_NAME = "vDisk"
    $VM_COLUMN_NAME = "VM"
    $POWERSTATE_COLUMN_NAME = "Powerstate"
    $CPU_COLUMN_NAME = "CPUs"
    $OS_VMTOOLS_COLUMN_NAME = "OS according to the VMware Tools"
    $OS_CONFIG_COLUMN_NAME = "OS according to the configuration file"
    $STORAGE_COLUMN_NAME = "Provisioned MiB"
    $PRIMARY_IP_COLUMN_NAME = "Primary IP Address"
    $DNS_NAME_COLUMN_NAME = "DNS Name"
    $FIRMWARE_COLUMN_NAME = "Firmware"
    $MIB_TO_MB_CONVERSION_FACTOR = 1.04858
    $DEFAULT_OS_NAME = "Windows Server 2019 Datacenter"

    # Logging the initial information
    Log "Input file: $InputFile" -Level DEBUG
    Log "Anonymized: $($Anonymized.IsPresent)" -Level DEBUG
    Log "Filter powered-off VMs: $($ExcludePoweredOff.IsPresent)" -Level DEBUG
    Log "Filter templates: $($ExcludeTemplates.IsPresent)" -Level DEBUG
    Log "Filter SRM: $($ExcludeSRM.IsPresent)" -Level DEBUG
    Log "Enhanced Disk Info: $($EnhancedDiskInfo.IsPresent)" -Level DEBUG

    # Import the data from the Excel file
    $rvtools_data = Import-Excel -Path $InputFile -WorksheetName $VINFO_SHEET_NAME
    if ($EnhancedDiskInfo.IsPresent) {
        $disk_data = Import-Excel -Path $InputFile -WorksheetName $VDISK_SHEET_NAME
    }

    # Logging the total number of VMs processed
    Log "We have processed $counter VMs out of $($rvtools_data.Count) found in the file $InputFile" -Level INFO

    # Process each row and create a custom PS object
    $counter = 0
    $output = $rvtools_data | ForEach-Object {
        $counter++

        $osValue = if ($_.($OS_VMTOOLS_COLUMN_NAME)) {
            $_.($OS_VMTOOLS_COLUMN_NAME)
        } elseif ($_.($OS_CONFIG_COLUMN_NAME)) {
            $_.($OS_CONFIG_COLUMN_NAME)
        } else {
            $DEFAULT_OS_NAME
        }

        if ($osValue -like "*64-bit*") {
            $architecture = "x64"
        } elseif ($osValue -like "*32-bit*") {
            $architecture = "x86"
        } else {
            Write-Warning "Architecture not found for VM $($_.$VM_COLUMN_NAME)"
            $architecture = ""
        }

        $vmName = if ($Anonymized.IsPresent) { $_."VM UUID" } else { $_.$VM_COLUMN_NAME -replace " ", "_" }

        $storage_capacity = $_.$STORAGE_COLUMN_NAME
        $is_mib = $storage_capacity -eq $_.$STORAGE_COLUMN_NAME

        if ($is_mib) {
            $storage_capacity = [math]::Round($storage_capacity / $MIB_TO_MB_CONVERSION_FACTOR, 2)
        }
        $storage_capacity_gb = [math]::Round($storage_capacity / 1024, 2)

        if ($EnhancedDiskInfo.IsPresent) {
            # Extract disk-related data for the current VM from the vDisk tab
            $vm_disks = $disk_data | Where-Object { $_.$VM_COLUMN_NAME -eq $vmName }

            $disk_details_array = $vm_disks | ForEach-Object {
                # Using 'Capacity MiB' for provisioned size
                Log "Provisioned MiB for $($_.Disk): $($_.'Capacity MiB')" -Level DEBUG

                "$($_.Disk): Provisioned: $($_.'Capacity MiB') MiB, In Use: N/A MiB"
            }
            $disk_details = $disk_details_array -join "; "
        } else {
            # Use simpler values from vInfo tab
            $disk_details = "Provisioned: $($_.'Provisioned MiB') MiB, In Use: N/A MiB"
        }

        [PSCustomObject]@{
            name              = $vmName
            power_state       = $_.$POWERSTATE_COLUMN_NAME
            cores             = $_.$CPU_COLUMN_NAME
            memory            = $_.Memory
            os_config         = $osValue
            architecture      = $architecture
            storage_capacity  = $storage_capacity_gb
            primary_ip        = $_.$PRIMARY_IP_COLUMN_NAME
            dns_name          = $_.$DNS_NAME_COLUMN_NAME
            uuid              = $_."VM UUID"
            is_template       = $_.Template
            is_srm            = $_."SRM Placeholder"
            is_anonymized     = $Anonymized.IsPresent
            is_mib            = $is_mib
            firmware          = $_.$FIRMWARE_COLUMN_NAME
            number_of_disks   = $_.Disks
            disk_details      = $disk_details
        }

        # Logging each VM processed
        Log "Processed VM $vmName -> $($_.$POWERSTATE_COLUMN_NAME) ($counter/$($rvtools_data.Count))" -Level DEBUG

    } | Where-Object {
        (-not $ExcludePoweredOff -or $_.power_state -ne "poweredOff") -and
        (-not $ExcludeTemplates -or $_.is_template -ne "True") -and
        (-not $ExcludeSRM -or $_.is_srm -ne "True")
    }

    # Return the processed data
    return $output
}



function ConvertTo-AzMigrateCSV {
    param (
        [Parameter(Mandatory=$true)]
        [PSObject[]]$RVToolsData,

        [Parameter(Mandatory=$true)]
        [string]$OutputFile,

        [Parameter(Mandatory=$false)]
        [ValidateScript({
            if ($_ -in @(50, 90, 95) -or ($_ -ge 0 -and $_ -le 100)) {
                $true
            } else {
                throw "Invalid value for CPUUtilizationPercentage. Allowed values are 50, 90, 95, or any integer between 0 and 100."
            }
        })]
        [int]$CPUUtilizationPercentage = 50,
        
        [Parameter(Mandatory=$false)]
        [ValidateScript({
            if ($_ -in @(50, 90, 95) -or ($_ -ge 0 -and $_ -le 100)) {
                $true
            } else {
                throw "Invalid value for MemoryUtilizationPercentage. Allowed values are 50, 90, 95, or any integer between 0 and 100."
            }
        })]
        [int]$MemoryUtilizationPercentage = 50
    )

    # Prompt for custom percentages if "Custom" is selected
    if ($CPUUtilizationPercentage -eq "Custom") {
        $CPUUtilizationPercentage = Read-Host "Enter custom CPU utilization percentage"
    }

    if ($MemoryUtilizationPercentage -eq "Custom") {
        $MemoryUtilizationPercentage = Read-Host "Enter custom memory utilization percentage"
    }

    # Convert RVTools data to Azure Migrate CSV format
    $csvData = $RVToolsData | ForEach-Object {
        @{
            "*Server Name"                             = $_.name
            "IP addresses"                             = if ($_.primary_ip) { $_.primary_ip } else { "" }
            "*Cores"                                   = $_.cores
            "*Memory (In MB)"                          = $_.memory
            "*OS name"                                 = $_.os_config
            "OS version"                               = ""
            "OS architecture"                          = $_.architecture
            "Server type"                              = "Virtual"
            "Hypervisor"                               = "Vmware"
            "CPU utilization percentage"               = $CPUUtilizationPercentage
            "Memory utilization percentage"            = $MemoryUtilizationPercentage
            "Network adapters"                         = ""
            "Network In throughput"                    = ""
            "Network Out throughput"                   = ""
            "Boot type"                                = if ($_.firmware -eq "bios") { "BIOS" } else { "UEFI" }
            "Number of disks"                          = $_.number_of_disks
            "Storage in use (In GB)"                   = $_.storage_capacity
            "Disk 1 size (In GB)"                      = $_.storage_capacity
            "Disk 1 read throughput (MB per second)"   = ""
            "Disk 1 write throughput (MB per second)"  = ""
            "Disk 1 read ops (operations per second)"  = ""
            "Disk 1 write ops (operations per second)" = ""
            "Disk 2 size (In GB)"                      = ""
            "Disk 2 read throughput (MB per second)"   = ""
            "Disk 2 write throughput (MB per second)"  = ""
            "Disk 2 read ops (operations per second)"  = ""
            "Disk 2 write ops (operations per second)" = ""
        }
    }

    # Export the data to a CSV file
    try {
        $csvData | Export-Csv -Path $OutputFile -NoTypeInformation
        Write-Host "CSV file saved to $OutputFile"
    } catch {
        Write-Error $_.Exception.Message
    }
}


