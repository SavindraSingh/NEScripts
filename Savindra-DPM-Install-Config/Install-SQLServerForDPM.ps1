[CmdletBinding()]
Param
(
    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [String]$WindowsSourceFilesPath,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [String]$SQLAdminAccountName,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [String]$SQLAdminAccountPassword,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [String]$SQLInstanceName,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [ValidateSet('Yes','No')]
    [String]$UseExistingSQLServer,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [String]$SQLInstallationSourcePath
)

Begin
{
    Function Check-SQLAndDPMPrerequisites
    {
        Param
        (
            [Parameter(Mandatory=$true)]
            [String]$WindowsSourceFilesPath
        )

        [Bool]$DotNetAvailable = $false
        [Bool]$IsInDomain = $false
        [Bool]$MeetsPrerequisites = $false

        # Checking .Net Framework 3.5 availability
        Write-Verbose "BEGIN FUNCTION: Check-SQLAndDPMPrerequisites"
        Write-Verbose "Checking prerequisites for .Net and DPM installation"
        Write-Verbose "Checking .Net 3.5 availability"
        If((Get-WindowsFeature -Name NET-Framework-Core).Installed)
        {
            Write-Verbose ".Net Framework 3.5 status - Installed"
            Write-Host ".Net Framework 3.5 status - Installed (OK)" -ForegroundColor Green
            $DotNetAvailable = $true
        }
        Else
        {
            Write-Verbose ".Net Framework 3.5 status - Not Available"
            Write-Host ".Net Framework 3.5 status - Not Available (FAILED)" -ForegroundColor Red
            $DotNetAvailable = $false
            <# Skipping Installation of .Net Framework
            Write-Verbose "Attempting to install .Net Framework 3.5"
            Write-Host "Installing .Net Framework 3.5" -ForegroundColor Yellow

            Try
            {
                If(Test-Path -Path $WindowsSourceFilesPath -ErrorAction SilentlyContinue)
                {
                    Install-WindowsFeature -Name NET-Framework-Core -Source $WindowsSourceFilesPath -ErrorAction Stop
                    If((Get-WindowsFeature -Name NET-Framework-Core).Installed)
                    {
                        Write-Verbose ".Net Framework 3.5 status - Installed"
                        Write-Host ".Net Framework 3.5 status - Installed (OK)" -ForegroundColor Green
                        $DotNetAvailable = $true
                    }
                    Else
                    {
                        Write-Verbose ".Net Framework 3.5 status - Installation Failed"
                        Write-Host ".Net Framework 3.5 status - Installation Failed" -ForegroundColor Red
                        $DotNetAvailable = $false
                    }
                }
                Else
                {
                    Write-Host "Unable to find source files at $WindowsSourceFilesPath. Invalid path.`nTry to install it manually and try again." -ForegroundColor Red
                    $DotNetAvailable = $false
                }
            }
            Catch
            {
                Write-Host "Error while installing .Net Framework 3.5.`n$($Error[0].Exception.Message)" -ForegroundColor Red
                $DotNetAvailable = $false
            }
            #>
        }

        # Checking Domain membership availability
        Write-Verbose "Checking domain membership"
        Try
        {
            $ComputerProperties = (Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop)
            If($ComputerProperties.DomainRole -eq 3)
            {
                Write-Verbose "$DPMServername is part of $($ComputerProperties.Domain) as - MemberServer"
                Write-Host "Domain membership status - MemberServer (OK)" -ForegroundColor Green
                $IsInDomain = $true
            }
            Else
            {
                Write-Verbose "$DPMServername is part of $($ComputerProperties.Domain) as - StandaloneServer"
                Write-Host "Domain membership status - StandaloneServer (FAILED)" -ForegroundColor Red
                $IsInDomain = $false
            }
        }
        Catch
        {
            Write-Host "Unable to check domain membership status.`n$($Error[0].Exception.Message)" -ForegroundColor Red
            $IsInDomain = $false
        }

        If($DotNetAvailable -and $IsInDomain)
        {
            Write-Verbose "END FUNCTION: Check-SQLAndDPMPrerequisites"
            Return $true
        }
        Else
        {
            Write-Verbose "END FUNCTION: Check-SQLAndDPMPrerequisites"
            Return $false
        }
    }

    Function Install-SqlServer
    {
        Param
        (
        [Parameter(Mandatory=$true)]
        [String]$WindowsSourceFilesPath,

        [Parameter(Mandatory=$true)]
        [String]$SQLInstanceName,

        [Parameter(Mandatory=$true)]
        [String]$SQLAdminAccountName,

        [Parameter(Mandatory=$true)]
        [String]$SQLAdminAccountPassword,

        [Parameter(Mandatory=$true)]
        [String]$SQLInstallationSourcePath
    )

        # BEGIN - Create Configuration file for Silent Installation
        Write-Verbose "BEGIN FUNCTION: Install-SqlServer"

        $SQLSetupLogFile = "C:\Program Files\Microsoft SQL Server\110\Setup Bootstrap\Log\Summary.txt"
        $SQLConfigFilePath = "C:\SQLSetup\SQLConfig.ini"
$ConfigurationFileContents = @"
[OPTIONS]
IACCEPTSQLSERVERLICENSETERMS="True"
ACTION="Install"
ENU="True"
QUIET="False"
QUIETSIMPLE="True"
UpdateEnabled="False"
FEATURES=SQLENGINE,FULLTEXT,RS,SSMS,ADV_SSMS
UpdateSource="MU"
HELP="False"
INDICATEPROGRESS="False"
X86="False"
INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server"
INSTALLSHAREDWOWDIR="C:\Program Files (x86)\Microsoft SQL Server"
INSTANCENAME="$SQLInstanceName"
INSTANCEID="$SQLInstanceName"
SQMREPORTING="False"
RSINSTALLMODE="DefaultNativeMode"
ERRORREPORTING="False"
INSTANCEDIR="C:\Program Files\Microsoft SQL Server"
AGTSVCACCOUNT="$SQLAdminAccountName"
AGTSVCPASSWORD="$SQLAdminAccountPassword"
AGTSVCSTARTUPTYPE="Automatic"
COMMFABRICPORT="0"
COMMFABRICNETWORKLEVEL="0"
COMMFABRICENCRYPTION="0"
MATRIXCMBRICKCOMMPORT="0"
SQLSVCSTARTUPTYPE="Automatic"
FILESTREAMLEVEL="0"
ENABLERANU="False"
SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS"
SQLSVCACCOUNT="$SQLAdminAccountName"
SQLSVCPASSWORD="$SQLAdminAccountPassword"
SQLSYSADMINACCOUNTS="$SQLAdminAccountName"
TCPENABLED="1"
NPENABLED="0"
BROWSERSVCSTARTUPTYPE="Disabled"
RSSVCACCOUNT="$SQLAdminAccountName"
RSSVCPASSWORD="$SQLAdminAccountPassword"
RSSVCSTARTUPTYPE="Automatic"
FTSVCACCOUNT="NT Service\MSSQLFDLauncher"
"@
    
        If(Test-Path -Path "C:\SQLSetup")
        {
            Try
            {
                Out-File -FilePath $SQLConfigFilePath -Force -InputObject $ConfigurationFileContents -ErrorAction Stop
            }
            Catch
            { Return "Error creating SQL Configuration file for installation.`n$($Error[0].Exception.Message)"; EXIT }
        }
        Else
        {
            Try
            {
                New-Item -Path "C:\SQLSetup" -ItemType "Directory" -Force | Out-Null
                Out-File -FilePath $SQLConfigFilePath -Force -InputObject $ConfigurationFileContents -ErrorAction Stop
            }
            Catch
            { Return "Error creating SQL Configuration file for installation.`n$($Error[0].Exception.Message)"; EXIT }
        }
        # END - Create Configuration file for silent installation

        Write-Verbose "Cheking prerequisites for SQL."
        If(Check-SQLAndDPMPrerequisites -WindowsSourceFilesPath $WindowsSourceFilesPath)
        {
            Write-Verbose "All prerequisites met for installing SQL for DPM. Starting SQL installation."
            If(Test-Path -Path $SQLInstallationSourcePath)
            {
                $ExecutablePath = If($SQLInstallationSourcePath.EndsWith("\")){"$($SQLInstallationSourcePath)Setup.exe"}
                Else { "$($SQLInstallationSourcePath)\Setup.exe" }
            
                $SetupArguments = "/ConfigurationFile=$SQLConfigFilePath"

                Write-Verbose "Starting SQL Server installation from $ExecutablePath with argument $SetupArguments"
                Write-Host "Installing SQL Server. Please wait:" -ForegroundColor Cyan
                Try # To install SQL Server
                {
                    $InstallationProcess = Start-Process -FilePath $ExecutablePath -ArgumentList $SetupArguments -PassThru
                    Do
                    {
                        Write-Host "$([char]9616)" -NoNewline -ForegroundColor Green
                        Start-Sleep -Seconds 10
                    }While(-not($InstallationProcess.HasExited))
                    Write-Host " - Completed`nCheck setup log file for details: $SQLSetupLogFile" -ForegroundColor Yellow

                    Write-Verbose "Verifying SQL Setup if installed correctly"

                    $Roles = (Get-WmiObject -Query "SELECT Roles FROM Win32_ComputerSystem").Roles

                    If(-not($Roles -like "SQLServer").Length -eq 0)
                    {
                         Write-Verbose "SQL Server verification succesful"
                         Write-Host "SQL Servr was installed Successfuly" -ForegroundColor Green
                    }
                    Else
                    {
                         Write-Verbose "Verifying SQL Setup if installed correctly"
                    }
                }
                Catch
                {
                    Write-Host "An error occured while installing SQL Server 2012.`n$($Error[0].Exception.Message)" -ForegroundColor Red
                    Return "Error while installing SQL Server"
                    EXIT
                }
            }
        }
        Else
        {
            Write-Host "Target computer does not meet the prerequisites for installing SQL" -ForegroundColor Red
        }
        Write-Verbose "END FUNCTION: Install-SqlServer"
    }
}

Process
{
    #region BEGIN - Step 1: Install SQL Server
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
                Install-SqlServer -WindowsSourceFilesPath $WindowsSourceFilesPath -SQLInstanceName $SQLInstanceName -SQLAdminAccountName $SQLAdminAccountName -SQLAdminAccountPassword $SQLAdminAccountPassword -SQLInstallationSourcePath $SQLInstallationSourcePath
            }
        }
        Catch
        {
            Return "Error occured while verifying the SQL installation.`n$($Error[0].Exception.Message)"
        }
    }
    #endregion END - Step 1: Install SQL Server
}

End {}