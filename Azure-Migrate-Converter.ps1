function Read-RVToolsData {
    param (
        [Parameter(Mandatory=$true)]
        [string]$InputFile,

        [switch]$ExcludePoweredOff,
        [switch]$ExcludeTemplates,
        [switch]$ExcludeSRM,
        [switch]$EnhancedDiskInfo = $false,

        [ValidateSet("TotalDiskCapacity", "Provisioned", "InUse")]
        [string]$StorageType = "Provisioned",

        [switch]$AnonymizedVM,   # Switch for anonymizing VM names
        [switch]$AnonymizedDNS,  # Switch for anonymizing DNS names
        [switch]$AnonymizedIP    # Switch for anonymizing IP addresses
    )

    # Constants
    $VINFO_SHEET_NAME = "vInfo"
    $VDISK_SHEET_NAME = "vDisk"
    $VM_COLUMN_NAME = "VM"
    $VM_UUID_COLUMN_NAME = "VM UUID"
    $POWERSTATE_COLUMN_NAME = "Powerstate"
    $CPU_COLUMN_NAME = "CPUs"
    $OS_VMTOOLS_COLUMN_NAME = "OS according to the VMware Tools"
    $OS_CONFIG_COLUMN_NAME = "OS according to the configuration file"
    $PRIMARY_IP_COLUMN_NAME = "Primary IP Address"
    $DNS_NAME_COLUMN_NAME = "DNS Name"
    $FIRMWARE_COLUMN_NAME = "Firmware"
    $MIB_TO_MB_CONVERSION_FACTOR = 1.04858
    $DEFAULT_OS_NAME = "Windows Server 2019 Datacenter"

    # Logging the initial information using native cmdlets
    Write-Information "Input file: $InputFile"
    Write-Information "Anonymized VM: $AnonymizedVM"
    Write-Information "Anonymized DNS: $AnonymizedDNS"
    Write-Information "Anonymized IP: $AnonymizedIP"
    Write-Warning "Filter powered-off VMs: $($ExcludePoweredOff.IsPresent)"
    Write-Warning "Filter templates: $($ExcludeTemplates.IsPresent)"
    Write-Warning "Filter SRM: $($ExcludeSRM.IsPresent)"
    Write-Warning "Enhanced Disk Info: $($EnhancedDiskInfo.IsPresent)"
    Write-Warning "Using storage type: $StorageType"

    # Import the data from the Excel file
    $rvtools_data = Import-Excel -Path $InputFile -WorksheetName $VINFO_SHEET_NAME

    # If EnhancedDiskInfo is selected, import disk data
    $disk_data = @{}
    if ($EnhancedDiskInfo) {
        $disk_data = Import-Excel -Path $InputFile -WorksheetName $VDISK_SHEET_NAME | Group-Object -Property VM
    }

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

        $vmName = if ($AnonymizedVM) { $_.$VM_UUID_COLUMN_NAME } else { $_.$VM_COLUMN_NAME -replace " ", "_" }
        $ipAddress = if ($AnonymizedIP) { $_.$PRIMARY_IP_COLUMN_NAME -replace '\d+$', '0' } else { $_.$PRIMARY_IP_COLUMN_NAME }
        $dnsName = if ($AnonymizedDNS) { "anonymous.local" } else { $_.$DNS_NAME_COLUMN_NAME }

        # Determine storage value based on the StorageType
        switch ($StorageType) {
            "TotalDiskCapacity" { $storageValueColumn = "Total disk capacity MiB" }
            "Provisioned"       { $storageValueColumn = "Provisioned MiB" }
            "InUse"             { $storageValueColumn = "In use MiB" }
        }
        $storage_capacity = $_.$storageValueColumn
        $is_mib = $storage_capacity -eq $_.$storageValueColumn

        if ($is_mib) {
            $storage_capacity = [math]::Round($storage_capacity / $MIB_TO_MB_CONVERSION_FACTOR, 2)
        }
        $storage_capacity_gb = [math]::Round($storage_capacity / 1024, 2)

        $nics = if ($null -ne $_.NICs -and $_.NICs -ne "") { $_.NICs } else { 0 }

        if ($EnhancedDiskInfo) {
            $disk_details = ($disk_data[$_.VM] | ForEach-Object {
                "Hard disk $($_.Disk): Provisioned: $($_.'Capacity MiB') MiB, In Use: $($_.'In Use MiB') MiB"
            }) -join ";"
        } else {
            $disk_details = ""
        }

        [PSCustomObject]@{
            name              = $vmName
            power_state       = $_.$POWERSTATE_COLUMN_NAME
            cores             = $_.$CPU_COLUMN_NAME
            memory            = $_.Memory
            os_config         = $osValue
            architecture      = $architecture
            storage_capacity  = $storage_capacity_gb
            primary_ip        = $ipAddress
            dns_name          = $dnsName
            uuid              = $_.$VM_UUID_COLUMN_NAME
            is_template       = $_.Template
            is_srm            = $_."SRM Placeholder"
            is_anonymized     = $AnonymizedVM -or $AnonymizedDNS -or $AnonymizedIP
            is_mib            = $is_mib
            firmware          = $_.$FIRMWARE_COLUMN_NAME
            number_of_disks   = $_.Disks
            disk_details      = $disk_details
            nics              = $nics
        }
        # Logging each VM processed
        Write-Verbose "Processed VM $vmName -> $($_.$POWERSTATE_COLUMN_NAME) ($counter/$($rvtools_data.Count))"
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

    # Logging the initial information using native cmdlets
    Write-Information "CPU Utilization Percentage: $CPUUtilizationPercentage"
    Write-Information "Memory Utilization Percentage: $MemoryUtilizationPercentage"
    Write-Information "Output file path: $OutputFile"

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
            "Network adapters"                         = if ($_.NICs) { $_.NICs } else { 0 }
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
        Write-Information "CSV file saved to $OutputFile"
    } catch {
        Write-Error $_.Exception.Message
    }
}


