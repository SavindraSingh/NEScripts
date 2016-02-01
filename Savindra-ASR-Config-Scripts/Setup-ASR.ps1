<#########################################################
Script for configuring ASR in Hyper-V environment
<#########################################################>

# Step 1: Setup Azure Login
$UserName = "savindrasingh@prakashnimmalanetenrich.onmicrosoft.com"
$Password = "password"
$AzureSubscriptionID = "755d84e8-b6f1-4b1a-abc9-734f25d70340"

$SecurePassword = ConvertTo-SecureString -AsPlainText $Password -Force
$Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $securePassword
Add-AzureAccount -Credential $Cred;
$AzureSubscription = Select-AzureSubscription -SubscriptionID $AzureSubscriptionID

# Step 2: Create a Site Recovery Vault
$VaultName = "testvault123" 
$VaultGeo  = "Southeast Asia"
$OutputPathForSettingsFile = "c:\Temp"

New-AzureSiteRecoveryVault -Location $VaultGeo -Name $VaultName;
$vault = Get-AzureSiteRecoveryVault -Name $VaultName;

# Step 3: Generate a vault registration key
#      3.1. Get the vault setting file and set the context:

$VaultSetingsFile = Get-AzureSiteRecoveryVaultSettingsFile -Location $VaultGeo -Name $VaultName -Path $OutputPathForSettingsFile

#      3.2. Set the vault context by running the following commands:
$VaultSettingFilePath = $vaultSetingsFile.FilePath 
$VaultContext = Import-AzureSiteRecoveryVaultSettingsFile -Path $VaultSettingFilePath -ErrorAction Stop

# Step 4: Install the Azure Site Recovery Provider
# Download URL: http://aka.ms/downloaddra
$ASRPInstallationPath = "C:\Downloads\ASR"

#region BEGIN - Download and Install the Azure Site Recovery Provider
######################[ Begin: Download Azure Site Recovery Provider ]########################
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
                                EXIT
                            }
                        }

$ASRPDownloadURL = "http://aka.ms/downloaddra"
$ASRPOutFile = "$DownloadDirectory\AzureSiteRecoveryProvider.exe"
$ASRPParams = "/x:$ASRPInstallationPath /q"

If(Get-ChildItem -Path $ASRPOutFile -ErrorAction SilentlyContinue)
{
    Write-Verbose "$ASRPOutFile File already exists. Skipping file download."
}
Else
{
    Write-Verbose "$ASRPOutFile File does not exist. Downloading from Microsoft."
    Try
    {
        Invoke-WebRequest -URI $ASRPDownloadURL -OutFile $ASRPOutFile -ErrorAction Stop
    }
    Catch
    {
        Write-Warning "Error downloading Azure Site Recovery Provider"
        Write-Host "`n$($Error[0].Exception.Message)" -ForegroundColor Red
        Return $false
    }
}
#endregion #####################[ END: Download Azure Site Recovery Provider ]##########################

# 4.1.Extract the files using the downloaded provider by running the following command
try
{
    Start-Process -FilePath $ASRPOutFile -ArgumentList $ASRPParams
}
catch
{
    Write-Host "Error extracting installation files to $ASRPInstallationPath.`n$($Error[0].Exception.Message)"
    EXIT
}

# 4.2.Install the provider using the following commands:
$ASRPInstallationExePath = "$ASRPInstallationPath\SetupDR.exe"
$ASRPInstallationOption = "/q"

try
{
    Start-Process -FilePath $ASRPInstallationExePath -ArgumentList $ASRPInstallationOption
}
catch
{
    Write-Host "Error installing Azure Site Recovery Provider.`n$($Error[0].Exception.Message)"
    EXIT
}

$installationRegPath = "hklm:\software\Microsoft\Microsoft System Center Virtual Machine Manager Server\DRAdapter"
$isNotInstalled = $true;
do
{
    if(Test-Path $installationRegPath)
    {
        $isNotInstalled = $false;
    }
}While($isNotInstalled)

# 4.3 Register the server in the vault using the following command:
$BinPath = $env:SystemDrive+"\Program Files\Microsoft System Center 2012 R2\Virtual Machine Manager\bin"
Push-Location $BinPath
$encryptionFilePath = "C:\temp\"
& ".\DRConfigurator.exe /r /Credentials $VaultSettingFilePath /vmmfriendlyname $env:COMPUTERNAME /dataencryptionenabled $encryptionFilePath /startvmmservice"


