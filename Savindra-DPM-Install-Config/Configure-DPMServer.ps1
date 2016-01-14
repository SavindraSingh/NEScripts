[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
    [String]$ResourceGroupName,

    [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
    [String]$VaultName,

    [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
    [String]$DPMServerName,

    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$True)]
    [String]$AzureLoginUserAccount,

    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$True)]
    [String]$AzureLoginUserPassword,

    [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
    [String]$SubscriptionID,

    [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
    [String]$Location,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [ValidateSet('Yes','No')]
    [String]$CustomizeDPMSubscriptionSettings,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [ValidateSet('Yes','No')]
    [String]$SetEncryption,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [ValidateSet('Yes','No')]
    [String]$SetProxy,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [ValidateSet('Yes','No')]
    [String]$SetThrottling,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [String]$StagingAreaPath,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [String]$EncryptionPassPhrase,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [String]$ProxyServerAddress,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [int]$ProxyServerPort,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [int]$ThrottlingStartWorkHour,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [int]$ThrottlingEndWorkHour,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [long]$ThrottlingWorkHourBandwidth,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [long]$ThrottlingNonWorkHourBandwidth,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [System.DayOfWeek[]]$Workday
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
                                Write-Host "MARS Agent installation verified successfully." -ForegroundColor Green
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

    Function Configure-DPMServer
    {
        Param
        (
            [Parameter(Mandatory=$true)]
            [String]$SubscriptionID,
            [Parameter(Mandatory=$true)]
            [String]$AzureLoginUserAccount,
            [Parameter(Mandatory=$true)]
            [String]$AzureLoginUserPassword,
            [Parameter(Mandatory=$true)]
            [String]$ResourceGroupName,
            [Parameter(Mandatory=$true)]
            [String]$VaultName,
            [Parameter(Mandatory=$true)]
            [String]$DPMServerName,
            [Parameter(Mandatory=$true)]
            [String]$Location,
            [Parameter(ValueFromPipelineByPropertyName=$True)]
            [ValidateSet('Yes','No')]
            [String]$CustomizeDPMSubscriptionSettings,
            [String]$StagingAreaPath,
            [Parameter(ValueFromPipelineByPropertyName=$True)]
            [ValidateSet('Yes','No')]
            [String]$SetEncryption,
            [String]$EncryptionPassPhrase,
            [Parameter(ValueFromPipelineByPropertyName=$True)]
            [ValidateSet('Yes','No')]
            [String]$SetProxy,
            [String]$ProxyPassword,
            [Parameter(ValueFromPipelineByPropertyName=$True)]
            [ValidateSet('Yes','No')]
            [String]$SetThrottling,
            [Int32]$ThrottlingStartWorkHour,
            [Int32]$ThrottlingEndWorkHour,
            [Long]$ThrottlingWorkHourBandwidth,
            [Long]$ThrottlingNonWorkHourBandwidth,
            [System.DayOfWeek[]]$WorkDay
        )

        Write-Verbose "BEGIN FUNCTION: Configure-DPMServer"
        ######################[ Begin: Login to Azure Account ]########################
        Write-Verbose "Attempting login to Azure account"
        Try
        {
            Get-AzureSubscription -SubscriptionId $SubscriptionID -ErrorAction Stop
            Select-AzureSubscription -SubscriptionId $SubscriptionID -ErrorAction Stop
        }
        Catch
        {
            If($Error[0].Exception.InnerException.Source -eq "Microsoft.Azure.Common.Authentication" -or $Error[0].Exception.InnerException.Source -eq "Microsoft.IdentityModel.Clients.ActiveDirectory")
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
                Write-Verbose "Azure login failed."
                Try
                {
                    $LoginPassword = ConvertTo-SecureString -String $AzureLoginUserPassword -AsPlainText -Force
                    $LoginCredentials = New-Object System.Management.Automation.PSCredential -ArgumentList @($AzureLoginUserAccount,$LoginPassword)
                    Login-AzureRmAccount -SubscriptionId $SubscriptionID -Credential $LoginCredentials -ErrorAction Stop
                    Select-AzureSubscription -SubscriptionId $SubscriptionID
                }
                Catch
                {
                    Write-Verbose "Error loggin in to Azure account with subscription ID: $SubscriptionID"
                    Return $Error[0].Exception.Message
                    EXIT
                }
            }
        }
        ######################[ END: Login to Azure Account ]########################

        ######################[ Begin: Call to Backup Vault Creation Function ]########################

        Write-Verbose "Calling Create-NewBackupVault function with below parameters:`nResourceGroupName = $ResourceGroupName`nVaultName = $VaultName`nLocation = $Location`nSubscriptionID = $SubscriptionID"

        Create-NewBackupVault -ResourceGroupName $ResourceGroupName -VaultName $VaultName -Location $Location -SubscriptionID $SubscriptionID

        ######################[ END: Call to Backup Vault Creation Function ]########################

        ######################[ Begin: Download MARS Agent for DPM ]########################
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

        $DownloadURL = "http://aka.ms/azurebackup_agent"
        $OutFile = "$DownloadDirectory\MARSAgentInstaller.exe"
        $MARSParams = "/q /nu"

        If(Get-ChildItem -Path 'C:\Downloads\MARSAgentInstaller.exe' -ErrorAction SilentlyContinue)
        {
            Write-Verbose "C:\Downloads\MARSAgentInstaller.exe File already exists. Skipping file download."
        }
        Else
        {
            Write-Verbose "C:\Downloads\MARSAgentInstaller.exe File does not exist. Downloading from Microsoft."
            Try
            {
                Invoke-WebRequest -URI $DownloadURL -OutFile $OutFile -ErrorAction Stop
            }
            Catch
            {
                Write-Warning "Error downloading MARSAgentInstaller.exe"
                Return "`n$($Error[0].Exception.Message)"
            }
        }
        ######################[ END: Download MARS Agent for DPM ]##########################

        ######################[ Begin: Installation of MARS Agent for DPM ]##########################
        # Check if Agent is already installed before installation
        $InstalledAgent = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall -ErrorAction SilentlyContinue | Where {$_.GetValue("DisplayName") -eq "Microsoft Azure Recovery Services Agent" -and $_.Name.Contains("Windows Azure Backup") } 

        If($InstalledAgent -ne $null)
        {
            Write-Verbose "Microsoft Azure Recovery Services Agent is already Installed on this computer."
            Write-Warning "Skipping MARSAgent.exe Installation.`nMicrosoft Azure Recovery Services Agent is already Installed on this computer."
        }
        Else
        {
            Write-Verbose "Attempting to install Microsoft Azure Recovery Services Agent on this computer."
            Write-Host "Installing MARS Agent for DPM: " -NoNewline
            Start-Job -ScriptBlock {& $OutFile $MARSParams} | Out-Null
            Do
            {
                Write-Host "$([char]9616)" -NoNewline -ForegroundColor Green
                Start-Sleep -Milliseconds 1000
            } While(Get-Process -Name MARSAgentInstaller -ErrorAction SilentlyContinue)
            Write-Host "`nMARS Agent installation completed! Pending verification." -ForegroundColor Yellow

            # Verify if installation was successful
            Write-Verbose "Verifying MARS Agent installation."
            $InstalledAgent = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall -ErrorAction SilentlyContinue | Where {$_.GetValue("DisplayName") -eq "Microsoft Azure Recovery Services Agent" -and $_.Name.Contains("Windows Azure Backup") } 

            If($InstalledAgent -eq $null)
            {
                Write-Verbose "MARS Agent installation failed for unknown reason. Please try to install manually and try again."
                Return "Unable to install MARS Agent successfully. Please try to install manually and try again."
            }
            Else
            { Write-Host "MARS Agent installation verified successfully." -ForegroundColor Green}
        }
        ######################[ END: Installation of MARS Agent for DPM ]##########################

        ######################[ BEGIN: DPM Cloud registration process ]############################
        Try
        {
            Write-Verbose "Connecting to backup valut - $VaultName"
            $BackupVault = Get-AzureRmBackupVault -ResourceGroupName $ResourceGroupName -Name $VaultName -ErrorAction Stop
        }
        Catch
        {
            If($Error[0].Exception.Message -eq "The specified resource does not exist.")
            {
                Return "Error connecting to backup vault: $VaultName under resource group $ResourceGroupName.`nCheck if both of these resources exist on Azure."
            }
            Else
            {
                Return "Error connecting to backup vault:`n$($Error[0].Exception.Message)"
            }
        }

        # Obtaining Vault credentials file
        Write-Verbose "Retrieving Vault credentials to $DownloadDirectory for backup vault $VaultName"
        Try
        {
            $VaultCredentialsFilePath = (Get-AzureRmBackupVaultCredentials -TargetLocation $DownloadDirectory -Vault $BackupVault -ErrorAction Stop).ToString()
        }
        Catch
        {
            Return "Error retrieving Vault credentials for backup vault $($VaultName):`n$($Error[0].Exception.Message)"
        }

        # Actual registration process on Azure cloud
        Write-Verbose "Registering DPM Server $DPMServerName on Azure cloud."
        Try
        {
            Start-DPMCloudRegistration -DPMServerName $DPMServerName -VaultCredentialsFilePath "$DownloadDirectory\$VaultCredentialsFilePath" -ErrorAction Stop
            Write-Verbose "Successfully registered DPM Server $DPMServerName on Azure cloud."
        }
        Catch
        {
            Return "Error registering DPM Server $DPMServerName on Azure cloud.:`n$($Error[0].Exception.Message)"
        }
        ######################[ END: DPM Cloud registration process ]############################

        ######################[ BEGIN: Initial configuration settings ]############################
        Try
        {
            If($CustomizeDPMSubscriptionSettings -eq "Yes")
            {
                Write-Verbose "Customizing DPM Subscription settings."

                Write-Verbose "Retrieving DPM Subscription settings object."
                Try
                {
                    $SubsSettings = Get-DPMCloudSubscriptionSetting -DPMServerName $DPMServerName -ErrorAction Stop
                }
                Catch { Return "Error retrieving DPM Subscription settings object.`n$($Error[0].Exception.Message)" }

                # Setting Subscription settings as required
                $SubsSettings.StagingAreaPath = $StagingAreaPath
        
                If($SetEncryption -eq "Yes")
                {
                    # Encryption Settings
                    Write-Verbose "Customizing Encryption settings."
                    $PassPhrase = ConvertTo-SecureString $EncryptionPassPhrase -AsPlainText -Force
                    Set-DPMCloudSubscriptionSetting -DPMServerName $DPMServerName -SubscriptionSetting $SubsSettings -EncryptionPassphrase $PassPhrase
                }

                If($SetProxy -eq "Yes")
                {
                    # Proxy Settings
                    Write-Verbose "Customizing Proxy settings."
                    $PPassword = ConvertTo-SecureString $ProxyPassword -AsPlainText -Force
                    Set-DPMCloudSubscriptionSetting -DPMServerName $DPMServerName -SubscriptionSetting $SubsSettings `
                    -ProxyServer $ProxyServeraddress `
                    -ProxyPort $ProxyPortNumber `
                    -ProxyUsername $ProxyUserName `
                    -ProxyPassword $PPassword
                }
            
                If($SetThrottling -eq "Yes")
                {
                    # Throttling Setting
                    Write-Verbose "Customizing Throttling settings."
                    Set-DPMCloudSubscriptionSetting -DPMServerName $DPMServerName -SubscriptionSetting $SubsSettings `
                    -StartWorkHour $ThrottlingStartWorkHour `
                    -EndWorkHour $ThrottlingEndWorkHour `
                    -WorkHourBandwidth $ThrottlingWorkHourBandwidth `
                    -NonWorkHourBandwidth $ThrottlingNonWorkHourBandwidth `
                    -WorkDay $WorkDay
                }

                # Save settings and commit
                Set-DPMCloudSubscriptionSetting -DPMServerName $DPMServerName -SubscriptionSetting $SubsSettings -Commit
            }
        }
        Catch 
        {
            Return "Error updating DPM Subscription settings:'n$($Error[0].Exception.Message)"
        }
        ######################[ END: Initial configuration settings ]############################
        Write-Verbose "END FUNCTION: Configure-DPMServer"
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

    #region BEGIN - Step 2: Install SQL Server 2012
    Write-Verbose "Verifying availability of SQL server"
    If($UseExistingSQLServer -eq "Yes")
    {
        Try
        {
            # Verifying if this server already have SQL Server Role
            $Roles = (Get-WmiObject -Query "SELECT Roles FROM Win32_ComputerSystem").Roles

            If(-not($Roles -like "SQLServer").Length -eq 0)
            {
                # SQL Server Role is already available on this machine Skipping installation
                Write-Verbose "SQL Server already available on this computer"
                Write-Host "Skipping installation of SQL Server. Already available on local machine" -ForegroundColor Green
            }
        }
        Catch
        {
            Return "Error occured while verifying the SQL installation.`n$($Error[0].Exception.Message)"
        }
    }
    Else
    {
        Try
        {
            # Checking if this server already have SQL Server Role
            $Roles = (Get-WmiObject -Query "SELECT Roles FROM Win32_ComputerSystem").Roles

            If(-not($Roles -like "SQLServer").Length -eq 0)
            {
                # SQL Server Role is already available on this machine
                Write-Verbose "SQL Server already available on this computer"
                Write-Host "Skipping installation of SQL Server. Already available on local machine" -ForegroundColor Green
            }
            Else
            {
                Write-Verbose "NO SQL Server instance available on this computer"
                Write-Host "Starting installation of SQL Server" -ForegroundColor Green
                Install-SqlServer2012 -WindowsSourceFilesPath $WindowsSourceFilesPath -SQLInstanceName $SQLInstanceName -SQLAdminAccountName $SQLAdminAccountName -SQLAdminAccountPassword $SQLAdminAccountPassword -SQLInstallationSourcePath $SQLInstallationSourcePath
            }
        }
        Catch
        {
            Return "Error occured while verifying the SQL installation.`n$($Error[0].Exception.Message)"
        }
    }
    #endregion END - Step 2: Install SQL Server 2012

    #region BEGIN - Step 3: Install SC DPM 2012
    If(-not($UseExistingDPMServer -eq "Yes"))
    {
        Install-DPMServer -AdministratorUserName "$DPMServerName\Administrator" -CompanyNameForDPM $CompanyNameForDPM -DPMInstallationSourcePath $DPMInstallationSourcePath 
    }
    #endregion END - Step 3: Install SC DPM 2012

    #region BEGIN - Step 4: Create New Azure Backup Vault

    Create-NewBackupVault -ResourceGroupName $ResourceGroupName -VaultName $VaultName -SubscriptionID $SubscriptionID -Location $Location  

    #endregion END - Step 4: Create New Azure Backup Vault

    #region BEGIN - Step 5: Configure DPM to connect with Azure Backup Vault
    Configure-DPMServer -SubscriptionID $SubscriptionID -ResourceGroupName $ResourceGroupName -VaultName $VaultName -DPMServerName $DPMServerName -Location $Location
    #endregion END - Step 5: Configure DPM to connect with Azure Backup Vault
}

End {}