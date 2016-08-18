# Script to get storage utilization details by machine
$OutputData = @{}
Try { Import-Module -Name MSOnlineBackup -ErrorAction SilentlyContinue | Out-Null }
Catch
{
    $OutputData["Error"] = "Unable to import module MSOnlineBackup"
    $Result = New-Object -TypeName PSObject -Property $OutputData
    $Result | ConvertTo-Json
    Exit
}
Try
{
    $MachineName = $env:COMPUTERNAME
    $Result = Get-OBMachineUsage | Select @{n="MachineName";e={$MachineName}},@{n="StorageUsedByMachineInGB";e={[Math]::Round($_.StorageUsedByMachineInBytes/1GB,2)}},Time
    $Result | ConvertTo-Json
}
Catch
{
    $OutputData["Error"] = $Error[0].Exception.Message
    $Result = New-Object -TypeName PSObject -Property $OutputData
    $Result | ConvertTo-Json
    Exit
}