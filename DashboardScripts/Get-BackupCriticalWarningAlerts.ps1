Param
(
    [Parameter(Mandatory=$true)]
    [DateTime]$StartDate,

    [Parameter(Mandatory=$true)]
    [String]$DPMDatabaseName,

    [Parameter(Mandatory=$true)]
    [String]$SQLServerInstancename
)

# Example usage from PS command prompt:
# .\Get-BackupSummaryCW.ps1 -StartDate "6-jan-2016 06:00:00 am" -DPMDatabaseName "DPMDB" -SQLServerInstancename "ABS\MSDPMINSTANCE" -Verbose

Function Run-SQL($SqlText, $Database, $Server)
{
    $Connection = new-object System.Data.SqlClient.SQLConnection("Data Source=$Server;Integrated Security=SSPI;Initial Catalog=$Database");
    $Cmd = new-object System.Data.SqlClient.SqlCommand($SqlText, $Connection);

    Try
    {
        $Connection.Open();

        $Reader = $Cmd.ExecuteReader() 

        $Results = @()
        While ($Reader.Read())
        {
            $Row = @{}
            for ($i = 0; $i -lt $Reader.FieldCount; $i++)
            {
                $Row[$Reader.GetName($i)] = $Reader.GetValue($i)
            }
            $Results += New-Object PSObject -Property $Row            
        }
        $Connection.Close();
    } 
    Catch 
    {
        $Row = @{}
        $Row["Error"] = $Error[0].Exception.InnerException.Message
        $Results = New-Object PSObject -Property $Row
    }

    $Results 
}


$SQLQuery = @"
DECLARE @Num INTEGER
DECLARE @Num1 INTEGER
SELECT  @Num = count(*) 
 from vw_DPM_Alerts
where datepart("dy", OccuredSince) >= datepart("dy", '$($StartDate.ToString("dd-MMM-yyyy HH:mm:ss tt"))')
AND Severity = 1
AND (Resolution = 0 OR Resolution = 1)
SELECT  @Num1 = count(*) 
 from vw_DPM_Alerts
where  OccuredSince >=  '$($StartDate.ToString("dd-MMM-yyyy HH:mm:ss tt"))'
AND Severity = 0
AND (Resolution = 0 OR Resolution = 1)
SELECT @Num AS WarningAlerts,@Num1 AS ErrorAlerts
"@ 

Run-SQL -SqlText $SQLQuery -Database $DPMDatabaseName -Server $SQLServerInstancename
