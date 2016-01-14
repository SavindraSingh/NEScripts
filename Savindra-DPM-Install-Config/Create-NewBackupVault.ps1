[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
    [String]$ResourceGroupName,

    [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
    [String]$VaultName,

    [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
    [String]$SubscriptionID,

    [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
    [String]$AzureLoginUserAccount,

    [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
    [String]$AzureLoginUserPassword,

    [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
    [String]$Location
)

Begin
{
    Function Check-SciptRequirements
    {
        [CmdletBinding()]
        Param()

        Write-Verbose "BEGIN FUNCTION: Check-ScriptPrerequisites"
        Try 
        {
            Write-Verbose "Checking availability of Azure PowerShell."
            $APSTest = Get-AzureSubscription -ErrorAction Stop
            Write-Verbose "Availability of Azure Powershell - AVAILABLE"
            Return $True
        }
        Catch
        {
            If($Error[0].CategoryInfo.Reason -eq "CommandNotFoundException")
            {
                Write-Warning "Azure PowerShell is not installed/available on this comuter.`nAttempting download and install."
                #region BEGIN - Download and install Azure PowerShell
                        ######################[ Begin: Download Azure PowerShell ]########################
                        Write-Verbose "Checking if download directory exists"
                        $DownloadDirectory = If(Get-ChildItem -Path 'C:\Downloads' -ErrorAction SilentlyContinue)
                                             {
                                                "C:\Downloads"
                                             }
                                             Else
                                             {
                                                Try { (Mkdir -Path "C:\Downloads" -Force -ErrorAction Stop).FullName }
                                                Catch
                                                {
                                                    Return "Unable to create folder to store Downloads at C:\Downloads.`nYou can try again after creating the directory manually.`n$($Error[0].Exception.Message)"
                                                }
                                             }

                        $APSDownloadURL = "http://aka.ms/azure-powershellget"
                        $APSOutFile = "$DownloadDirectory\azure-powershell.1.0.2.msi"
                        $APSParams = "/passive"

                        If(Get-ChildItem -Path $APSOutFile -ErrorAction SilentlyContinue)
                        {
                            Write-Verbose "$APSOutFile File already exists. Skipping file download."
                        }
                        Else
                        {
                            Write-Verbose "$APSOutFile File does not exist. Downloading from Microsoft."
                            Try
                            {
                                Invoke-WebRequest -URI $APSDownloadURL -OutFile $APSOutFile -ErrorAction Stop
                            }
                            Catch
                            {
                                Write-Warning "Error downloading Azure PowerShell"
                                Write-Host "`n$($Error[0].Exception.Message)" -ForegroundColor Red
                                Return $false
                            }
                        }
                        ######################[ END: Download Azure PowerShell ]##########################

                        ######################[ Begin: Installation of Azure PowerShell ]##########################
                            Write-Verbose "Attempting to install Microsoft Azure PowerShell on this computer."
                            Write-Host "Installing Azure PowerShell: " -NoNewline
                            $APSInstaller = Start-Process -FilePath $APSOutFile -ArgumentList $APSParams -PassThru 
                            Do
                            {
                                Write-Host "$([char]9616)" -NoNewline -ForegroundColor Green
                                Start-Sleep -Seconds 5
                            } While(-not($APSInstaller.HasExited))
                            Write-Host "`nAzure PowerShell installation completed! Pending verification." -ForegroundColor Yellow

                            # Verify if installation was successful
                            Write-Verbose "Verifying Azure PowerShell installation."

                            Try
                            {
                                Get-AzureSubscription -ErrorAction Stop | Out-Null
                                Write-Host "Azure PowerShell installation verified successfully." -ForegroundColor Green
                            }
                            Catch
                            {
                                Write-Verbose "Azure PowerShell installation failed for unknown reason. Please try to install manually and try again."
                                Return "Unable to install Azure PowerShell successfully. Please try to install manually and try again."
                                EXIT
                            }
                        ######################[ END: Installation of Azure PowerShell ]##########################
                #endregion END - Download and install Azure PowerShell
            }
        }
    }

    Function Create-NewBackupVault
    {
        Param(
            [Parameter(Mandatory=$true)]
            [String]$ResourceGroupName,
            [Parameter(Mandatory=$true)]
            [String]$VaultName,
            [Parameter(Mandatory=$true)]
            [String]$SubscriptionID,
            [Parameter(Mandatory=$true)]
            [String]$Location,
            [Parameter(Mandatory=$true)]
            [String]$AzureLoginUserAccount, # Example (must be an Enterprise ID, Microsoft Live/Hotmail/Outlook accounts not supported): savindrasingh@prakashnimmalanetenrich.onmicrosoft.com
            [Parameter(Mandatory=$true)]
            [String]$AzureLoginUserPassword
            )
    
        Write-Verbose "BEGIN FUNCTION: Create-NewBackupVault"
        $Error.Clear()

        # Check if already logged-in to Azure account
        Try
        {
            Write-Verbose "Checking if ARM Resource Group $ResourceGroupName already exists."
            $ResourceGroupName = (Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction Stop).ResourceGroupName
        }
        Catch
        {
            If($Error[0].Exception.InnerException.Source -eq "Microsoft.Azure.Common.Authentication")
            {
                Write-Host "Session is invalid due to expiration or recent password change. Attempting to login again using Login-AzureRmAccount."
                Try
                {
                    $LoginPassword = ConvertTo-SecureString -String $AzureLoginUserPassword -AsPlainText -Force
                    $LoginCredentials = New-Object System.Management.Automation.PSCredential -ArgumentList @($AzureLoginUserAccount,$LoginPassword)
                    Login-AzureRmAccount -SubscriptionId $SubscriptionID -Credential $LoginCredentials -ErrorAction Stop
                    Select-AzureSubscription -SubscriptionId $SubscriptionID
                }
                Catch
                {
                    Return "Error logging in to ARM account.`n$($Error[0].Exception.Message)"
                    EXIT
                }
            }
            ElseIf($Error[0].Exception.Message -eq "Run Login-AzureRmAccount to login.")
            {
                Try
                {
                    $LoginPassword = ConvertTo-SecureString -String $AzureLoginUserPassword -AsPlainText -Force
                    $LoginCredentials = New-Object System.Management.Automation.PSCredential -ArgumentList @($AzureLoginUserAccount,$LoginPassword)
                    Login-AzureRmAccount -SubscriptionId $SubscriptionID -Credential $LoginCredentials -ErrorAction Stop
                    Select-AzureSubscription -SubscriptionId $SubscriptionID
                }
                Catch
                {
                    Return "Error logging in to ARM account.`n$($Error[0].Exception.Message)"
                    EXIT
                }
            }
            Else
            {
                Write-Verbose "ARM Resource Group $ResourceGroupName not found."
                Try
                {
                    Write-Verbose "Creating ARM Resource Group $ResourceGroupName"
                    New-AzureRMResourceGroup –Name $ResourceGroupName -Location $Location -ErrorAction Stop
                }
                Catch
                {
                    Write-Verbose "Error creating ARM Resource Group $ResourceGroupName"
                    Return $Error[0].Exception.Message
                    EXIT
                }
            }
        }

        $Error.Clear()
        Try
        {
            Write-Verbose "Creating backup vault $VaultName"
            $backupvault = New-AzureRMBackupVault –ResourceGroupName $ResourceGroupName –Name $VaultName –Region $Location -ErrorAction Stop
            If($backupvault.Name -eq $VaultName)
            {
                Write-Verbose "Backup vault $VaultName created successfully"
                Write-Host "Backup vault $VaultName created successfully" -ForegroundColor Green
            }
        }
        Catch
        {
            Write-Verbose "Error creating Backup vault $VaultName."
            Return $Error[0].Exception.Message
            EXIT
        }
        Write-Verbose "END FUNCTION: Create-NewBackupVault"
    }
}

Process
{
    #region BEGIN - Step 1: Validate all the parameters and combinations
    
    If(Check-SciptRequirements)
    {
        Write-Host "All requirements for executing the script are met" -ForegroundColor Green
    }
    Else
    {
        Write-Host "System does not meet all requirements for executing the script.`nTry installing Azure PowerShell Tools manually and try again." -ForegroundColor Red
        Exit
    }
    #endregion END - Step 1: Validate all the parameters and combinations

    #region BEGIN - Step 2: Create New Azure Backup Vault

    Create-NewBackupVault -ResourceGroupName $ResourceGroupName -VaultName $VaultName -SubscriptionID $SubscriptionID -Location $Location -AzureLoginUserAccount $AzureLoginUserAccount -AzureLoginUserPassword $AzureLoginUserPassword

    #endregion END - Step 2: Create New Azure Backup Vault

}

End {}