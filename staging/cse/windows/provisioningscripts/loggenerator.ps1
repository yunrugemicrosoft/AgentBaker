<#
.DESCRIPTION
#>

# TBD: Add more logs. We do not log too many since we do not have log rotation.

$Global:ClusterConfiguration = ConvertFrom-Json ((Get-Content "c:\k\kubeclusterconfig.json" -ErrorAction Stop) | out-string)
$global:ContainerRuntime = $Global:ClusterConfiguration.Cri.Name
$aksLogFolder="C:\WindowsAzure\Logs\aks"
$LogPath = "c:\k\loggenerator.log"
$isInitialized=$False

filter Timestamp { "$(Get-Date -Format o): $_" }

function Write-Log ($message) {
    $message | Timestamp | Tee-Object -FilePath $LogPath -Append
}

function Create-SymbolLinkFile {
    Param(
        [Parameter(Mandatory = $true)][string]
        $SrcFile,
        [Parameter(Mandatory = $true)][string]
        $DestFile
    )
    if (Test-Path $SrcFile) {
        New-Item -ItemType SymbolicLink -Path $DestFile -Target $SrcFile
    }
}

function Collect-OldLogFiles {
    Param(
        [Parameter(Mandatory = $true)][string]
        $Folder,
        [Parameter(Mandatory = $true)][string]
        $LogFilePattern
    )

    $oldSymbolLinkFiles=Get-ChildItem (Join-Path $aksLogFolder $LogFilePattern)
    $oldSymbolLinkFiles | Foreach-Object {
        Remove-Item $_
    }
    
    $kubeproxyOldLogFiles=Get-ChildItem (Join-Path $Folder $LogFilePattern)
    $kubeproxyOldLogFiles | Foreach-Object {
        $fileName = [IO.Path]::GetFileName($_)
        Create-SymbolLinkFile -SrcFile $_ -DestFile (Join-Path $aksLogFolder $fileName)
    }
}

if (!(Test-Path $aksLogFolder)) {
    Write-Log "The folder $aksLogFolder does not exist"
    return
}

$dumpVfpPoliciesScript="C:\k\debug\dumpVfpPolicies.ps1"
if (Test-Path $dumpVfpPoliciesScript) {
    PowerShell -ExecutionPolicy Unrestricted -command "$dumpVfpPoliciesScript -switchName L2Bridge -outfile (Join-Path $aksLogFolder 'vfpOutput.txt')"
}

Collect-OldLogFiles -Folder "c:\k\" -LogFilePattern kubeproxy.err-*.*.log
Collect-OldLogFiles -Folder "c:\k\" -LogFilePattern kubelet.err-*.*.log
Collect-OldLogFiles -Folder "c:\k\" -LogFilePattern containerd.err-*.*.log
Collect-OldLogFiles -Folder "c:\k\" -LogFilePattern azure-vnet.log.*
Collect-OldLogFiles -Folder "c:\k\" -LogFilePattern azure-vnet-ipam.log.*

if (Test-Path "c:\CalicoWindows\logs\") {
    Collect-OldLogFiles -Folder "c:\CalicoWindows\logs\" -LogFilePattern calico-felix-*.*.log
    Collect-OldLogFiles -Folder "c:\CalicoWindows\logs\" -LogFilePattern calico-node-*.*.log
}

if ($global:ContainerRuntime -eq "containerd") {
    crictl.exe ps -a > (Join-Path $aksLogFolder "cri-containerd-containers.txt")
}

$diskUsageFile = Join-Path $aksLogFolder ("disk-usage.txt")
Get-CimInstance -Class CIM_LogicalDisk | Select-Object @{Name="Size(GB)";Expression={$_.size/1gb}}, @{Name="Free Space(GB)";Expression={$_.freespace/1gb}}, @{Name="Free (%)";Expression={"{0,6:P0}" -f(($_.freespace/1gb) / ($_.size/1gb))}}, DeviceID, DriveType | Where-Object DriveType -EQ '3' > $diskUsageFile

$availableMemoryFile = Join-Path $aksLogFolder ("available-memory.txt")
Get-Counter '\Memory\Available MBytes' > $availableMemoryFile
