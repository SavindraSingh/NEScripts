[CmdletBinding()]
Param
(
    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [String]$SQLInstanceName,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [ValidateSet('Yes','No')]
    [String]$UseExistingDPMServer,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [String]$DPMInstallationSourcePath,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [String]$CompanyNameForDPM,

    [Parameter(ValueFromPipelineByPropertyName=$True)]
    [String]$AdministratorUserName
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

    Function Install-DPMServer
    {
        Param
        (
            [String]$AdministratorUserName,
            [String]$CompanyNameForDPM,
            [String]$DPMInstallationSourcePath
        )

        # BEGIN - Create Configuration file for silent installation
        Write-Verbose "BEGIN FUNCTION: Install-DPMServer"

        $DPMConfigFilePath = "C:\DPMSetup\DPMConfig.ini"
        $DPMSetupLogFile = "C:\DPMSetup\DPMLog.txt"
$DPMConfigFileContents = @"
[OPTIONS]
UserName = "$AdministratorUserName"
CompanyName = "$CompanyNameForDPM"
"@

        # Check DPM prerequisite feature
        Write-Verbose "Checking Windows featurs required for DPM installation"
        If(-not((Get-WindowsOptionalFeature -Online -FeatureName SIS-Limited).State -eq ""))
        {
        <# Skipping Installation of SIS-Limited as prerequisite
            Write-Verbose "Windows feature - Windows Single Instance Store (SIS) is not avaliable. Attempting install."
            Try
            {
                Enable-WindowsOptionalFeature -Online -FeatureName SIS-Limited -ErrorAction Stop -NoRestart
                Write-Verbose "Windows feature - Windows Single Instance Store (SIS) is installed."
                Write-Host "Windows feature - Windows Single Instance Store (SIS) required RESTART. Please restart the machine and try again." -ForegroundColor Red
            }
            Catch
            {
                Write-Host "Error installing Windows feature SIS-Limited.`nTry to install it manually and try again.`n$($Error[0].Exception.Message)"
                EXIT
            }
        #>
            Write-Host "Unable to find required prerequisite 'SIS-Limited'. Please install the same and try again."
            EXIT
        }

        If(Test-Path -Path "C:\DPMSetup")
        {
            Try
            {
                Out-File -FilePath $DPMConfigFilePath -Force -InputObject $DPMConfigFileContents -ErrorAction Stop
            }
            Catch
            { Return "Error creating DPM Configuration file for installation.`n$($Error[0].Exception.Message)"; EXIT }
        }
        Else
        {
            Try
            {
                New-Item -Path "C:\DPMSetup" -ItemType "Directory" -Force | Out-Null
                Out-File -FilePath $DPMConfigFilePath -Force -InputObject $DPMConfigFileContents -ErrorAction Stop
            }
            Catch
            { Return "Error creating DPM Configuration file for installation.`n$($Error[0].Exception.Message)"; EXIT }
        }
    # END - Create Configuration file for silent installation

        If(Test-Path -Path $DPMInstallationSourcePath)
        {
            $DPMExecutablePath = If($DPMInstallationSourcePath.EndsWith("\")){"$($DPMInstallationSourcePath)Setup.exe"}
            Else { "$($DPMInstallationSourcePath)\Setup.exe" }
            
            $DPMSetupArguments = "/I /F $DPMConfigFilePath /L $DPMSetupLogFile"

            Write-Verbose "Starting DPM 2012 installation from $DPMExecutablePath with argument $DPMSetupArguments"
            Write-Host "Installing DPM 2012. Please wait:" -ForegroundColor Cyan
            Try
            {
                $DPMInstallationProcess = Start-Process -FilePath $DPMExecutablePath -ArgumentList $DPMSetupArguments -PassThru
                Do
                {
                    Write-Host "$([char]9616)" -NoNewline -ForegroundColor Green
                    Start-Sleep -Seconds 10
                }While(-not($DPMInstallationProcess.HasExited))
                Write-Host "`nDPM Setup Finished" -ForegroundColor Yellow
            }
            Catch
            {
                Write-Host "An error occured while installing SQL Server 2012.`n$($Error[0].Exception.Message)" -ForegroundColor Red
                Return "Error while installing DPM Server"
                EXIT
            }
        }
        Write-Verbose "END FUNCTION: Install-DPMServer"
    }
}

Process
{
    #region BEGIN - Step 1: Install SC DPM 2012
    If(-not($UseExistingDPMServer -eq "Yes"))
    {
        Install-DPMServer -AdministratorUserName "$AdministratorUserName" -CompanyNameForDPM $CompanyNameForDPM -DPMInstallationSourcePath $DPMInstallationSourcePath 
    }
    #endregion END - Step 1: Install SC DPM 2012
}

End {}