[cmdletbinding()]
param(
    [parameter(mandatory = $true)]
    [string]$domain,
    [parameter(mandatory = $true)]       
    [string]$username,
    [parameter(mandatory = $true)] 
    [string]$password,

    [parameter(mandatory = $true)]
    [string]$nodeNamingPrefix,
    [parameter(mandatory = $true)]       
    [int]$numNodes,

    [parameter(mandatory = $true)]       
    [string]$storageAccountName,
    [parameter(mandatory = $true)] 
    [string]$storageAccountAccessKey,

    [Parameter(ValueFromRemainingArguments = $true)]
    $extraParameters
    )

    function log
    {
        param([string]$message)

        "`n`n$(get-date -f o)  $message" 
    }

    log "script running..."

    whoami

    if ($extraParameters) 
    {
        log "any extra parameters:"
        $extraParameters
    }


	$nodes = 0..$($numNodes - 1) | % { "$nodeNamingPrefix$_.$domain" }
	log "list of new servers:";  $nodes | % { "    $($_.tolower())" }

	install-windowsfeature rsat-clustering-powerShell 

	#  1. Create cluster
	#
	if (-not (get-cluster))
	{
		$clusterName = get-date -f yyyyMMdd-HHmmss
		new-cluster -Name $clusterName -Node $nodes -NoStorage  #-StaticAddress [new address within your addr space]
	}

	#  2. Configure cloud witness
	#
	#Set-ClusterQuorum –CloudWitness –AccountName $storageAccountName -AccessKey $storageAccountAccessKey

	
	#  3. Enable Storage Spaces Direct
	#
	Enable-ClusterS2D -CacheMode Disabled -AutoConfig:0 -SkipEligibilityChecks


	#  4. Create storage pool
	#
	$disks =  Get-PhysicalDisk | ? CanPool -eq $true
	New-StoragePool -StorageSubSystemFriendlyName *Cluster* -FriendlyName S2D -ProvisioningTypeDefault Fixed -ResiliencySettingNameDefault Mirror -PhysicalDisk $disks


	#  5. Create virtual disk
	#
	New-Volume -StoragePoolFriendlyName S2D* -FriendlyName VDisk01 -FileSystem CSVFS_REFS -Size 120GB


	#  6. Create new SMB share
	#
	New-Item -Path C:\ClusterStorage\Volume1\Data -ItemType Directory
	New-SmbShare -Name UpdStorage -Path C:\ClusterStorage\Volume1\Data


    log "done. success."
