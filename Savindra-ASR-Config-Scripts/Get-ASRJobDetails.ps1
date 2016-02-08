[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [String]$UserName,

    [Parameter(Mandatory=$true)]
    [String]$Password,

    [Parameter(Mandatory=$true)]
    [String]$AzureSubscriptionID,

    [Parameter(Mandatory=$true)]
    [String]$OutputPathForSettingsFile = "C:\ASR",

    [Parameter(Mandatory=$true)]
    [String]$VaultSetingsFilePath
)

$ObjOut = @{}

# Login to Azure account
Try
{
    # $UserName = "savindrasingh@prakashnimmalanetenrich.onmicrosoft.com"
    # $Password = 'Su$pense90'
    # $AzureSubscriptionID = "755d84e8-b6f1-4b1a-abc9-734f25d70340"

    $SecurePassword = ConvertTo-SecureString -AsPlainText $Password -Force
    $Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $securePassword
    (Add-AzureAccount -Credential $Cred) | Out-Null
    ($AzureSubscription = Select-AzureSubscription -SubscriptionID $AzureSubscriptionID) | Out-Null
}
Catch
{
    $ObjOut["Error"] = "Error logging in to Azure Account.`n$($Error[0].Exception.Message)"
    $OutputDetails = $ObjOut | ConvertTo-Json
    Return $OutputDetails
    EXIT
}

Try
{
    # Connect to vault
    ($ASRVault = Get-AzureSiteRecoveryVault -Name SavindraASRTestSRV) | Out-Null

    # Get vault settings file
    <#
    $VaultName = $ASRVault.Name
    $VaultGeo  = $ASRVault.Location
    $VaultSetingsFile = Get-AzureSiteRecoveryVaultSettingsFile -Location $VaultGeo -Name $VaultName -Path $OutputPathForSettingsFile
    #>

    # Import vault settings file and fetch details
    If($VaultSetingsFilePath -ne "" -or $VaultSetingsFilePath -ne $null)
    {
        ($ASRVSFile = Import-AzureSiteRecoveryVaultSettingsFile -Path $VaultSetingsFilePath) | Out-Null
        $OutputDetails = Get-AzureSiteRecoveryServer | Select Name,Connected,LastHeartbeat | ConvertTo-Json
    }
    Else
    {
        $ObjOut["Error"] = "Error loading vault credentials file from $VaultSetingsFilePath"
        $OutputDetails = $ObjOut | ConvertTo-Json
        Return $OutputDetails
        EXIT
    }
}
Catch
{
    $ObjOut["Error"] = "Error loading ASR Job details.`n$($Error[0].Exception.Message)"
    $OutputDetails = $ObjOut | ConvertTo-Json
    Return $OutputDetails
    EXIT
}
Return $OutputDetails