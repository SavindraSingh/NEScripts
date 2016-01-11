# Script to get Online backup schedule

$OutputData = @{}
Try
{
    Try { Import-Module -Name MSOnlineBackup -ErrorAction SilentlyContinue | Out-Null }
    Catch
    {
        $OutputData["Error"] = "Unable to import module MSOnlineBackup"
        $Result = New-Object -TypeName PSObject -Property $OutputData
        $Result | ConvertTo-Json
        Exit
    }

    $ObPolicy = Get-OBPolicy
    
    If($ObPolicy -ne $null)
        {
        # Find next job run schedule
        $ObSchedule = Get-OBSchedule -Policy $ObPolicy
        $AllSchedules = $Obschedule.ScheduleRunTimesToString().ToString().Split(",").Trim()
        ForEach($Schedule In $AllSchedules)
        {
            [DateTime]$NextPossibleTime = $Schedule
            ForEach($UpcomingTime IN New-TimeSpan -Start (Get-Date) -End $NextPossibleTime)
            {
                If(-not($UpcomingTime.Hours -le 0 -and $UpcomingTime.Minutes -le 0))
                {
                    [DateTime]$NextJobSchedule= $NextPossibleTime
                }
            }
        }

        # Get File and folder details
        $OBFileDetails = Get-OBFileSpec -Policy $ObPolicy

        # Get Job status of previous job
        $OBJobStatus = Get-OBJob -Previous 1 -Status All
        $JobStatus = [Microsoft.Internal.CloudBackup.ObjectModel.OMCommon.CBJobState]::GetName([Microsoft.Internal.CloudBackup.ObjectModel.OMCommon.CBJobState],$OBJobStatus.JobStatus.JobState)

        # Get storage consumption details
        $MachineName = $env:COMPUTERNAME
        $OBStorageDetails = Get-OBMachineUsage | Select @{n="MachineName";e={$MachineName}},@{n="StorageUsedByMachineInGB";e={[Math]::Round($_.StorageUsedByMachineInBytes/1GB,3)}},Time

        $OutputData["ScheduleId"] = $ObSchedule.ScheduleId
        $OutputData["SchedulePolicyName"] = $ObSchedule.SchedulePolicyName
        $OutputData["ScheduleRunDays"] = $ObSchedule.ScheduleRunDaysToString()
        $OutputData["ScheduleRunTimes"] = $ObSchedule.ScheduleRunTimesToString()
        $OutputData["NextJobSchedule"] = $NextJobSchedule
        $OutputData["ScheduleWeeklyFrequency"] = $ObSchedule.ScheduleWeeklyFrequency
        $OutputData["State"] = $ObSchedule.State
        $OutputData["DataSources"] = $OBFileDetails
        $OutputData["PreviousJobID"] = $OBJobStatus.JobId.Guid
        $OutputData["PreviousJobStartTimeUTC"] = $OBJobStatus.JobStatus.StartTime
        $OutputData["PreviousJobEndTimeUTC"] = $OBJobStatus.JobStatus.EndTime
        $OutputData["PreviousJobState"] = $JobStatus
        $OutputData["MachineName"] = $OBStorageDetails.MachineName
        $OutputData["StorageUsedBymachineInGB"] = $OBStorageDetails.StorageUsedByMachineInGB
        $OutputData["StorageDetailsCollectionTime"] = $OBStorageDetails.Time

        $Result = New-Object -TypeName PSObject -Property $OutputData

        $Result | ConvertTo-Json
    }
    Else
    {
        $OutputData["Error"] = "Can't find Backup policy defined for this server $($env:COMPUTERNAME)"
        $Result = New-Object -TypeName PSObject -Property $OutputData
        $Result | ConvertTo-Json
        Exit
    }
}
Catch
{
    $OutputData["Error"] = $Error[0].Exception.Message.ToString().Trim()
    $Result = New-Object -TypeName PSObject -Property $OutputData
    $Result | ConvertTo-Json
    Exit
}
