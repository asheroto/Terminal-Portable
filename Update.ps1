param (
    [Parameter(Mandatory = $true)]
    [string]$WtpFolderPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath('UserProfile'), 'Downloads')
)

# ============================================================================ #
# Variables
# ============================================================================ #

# Path to WinRAR executable
$winRARPath = "C:\Program Files\WinRAR\WinRAR.exe"

# Debug mode - disables deletion of extracted folder and zip file
$debugMode = $false

# ============================================================================ #
# Functions
# ============================================================================ #

Function Get-GitHubRelease {
    <#
        .SYNOPSIS
        Fetches the latest release information of a GitHub repository.

        .DESCRIPTION
        This function uses the GitHub API to get information about the latest release of a specified repository, including its version and the date it was published.

        .PARAMETER Owner
        The GitHub username of the repository owner.

        .PARAMETER Repo
        The name of the repository.

        .EXAMPLE
        Get-GitHubRelease -Owner "microsoft" -Repo "terminal"
        This command retrieves the latest release version and the x64 download URL of the terminal repository owned by microsoft.
    #>
    [CmdletBinding()]
    param (
        [string]$Owner,
        [string]$Repo
    )
    try {
        $url = "https://api.github.com/repos/$Owner/$Repo/releases/latest"
        $response = Invoke-RestMethod -Uri $url -ErrorAction Stop

        $latestVersion = $response.tag_name
        $publishedAt = $response.published_at
        $x64Asset = $response.assets | Where-Object { $_.name -match "x64.zip" } | Select-Object -First 1

        if ($null -eq $x64Asset) {
            Write-Error "No x64 asset found for the latest release."
            exit 1
        }

        # Convert UTC time string to local time
        $UtcDateTime = [DateTime]::Parse($publishedAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
        $PublishedLocalDateTime = $UtcDateTime.ToLocalTime()

        [PSCustomObject]@{
            LatestVersion     = $latestVersion
            PublishedDateTime = $PublishedLocalDateTime
            DownloadUrl       = $x64Asset.browser_download_url
        }
    } catch {
        Write-Error "Unable to check for updates.`nError: $_"
        exit 1
    }
}

# Function to create .portable file
Function Create-PortableFile($terminalPath) {
    $portableFilePath = [System.IO.Path]::Combine($terminalPath, ".portable")
    New-Item -Path $portableFilePath -ItemType File -Force | Out-Null
}

# Function to update SFX archive
Function Update-SFXArchive($sfxPath, $terminalPath) {
    $Global:winRARPath

    Write-Debug "sfxPath: $sfxPath"
    Write-Debug "terminalPath: $terminalPath"

    # Change to the parent directory of Terminal
    Push-Location -Path (Split-Path -Path $terminalPath -Parent)

    # Add the new "Terminal" folder to the SFX archive
    Write-Output "Adding new Terminal folder to the archive..."
    & $winRARPath a -r "$sfxPath" "Terminal\*" > $null

    # Return to the original directory
    Pop-Location
}

# ============================================================================ #
# Main code
# ============================================================================ #

# Validate and resolve WtpFolderPath
try {
    $resolvedWtpFolderPath = Resolve-Path -Path $WtpFolderPath -ErrorAction Stop
    if (!(Test-Path -Path $resolvedWtpFolderPath -PathType Container)) {
        Write-Output "The specified folder path for wtp.exe and wtp_user.exe does not exist or is not a directory."
        exit
    }
} catch {
    Write-Output "The specified folder path for wtp.exe and wtp_user.exe does not exist."
    exit
}

# Set the repository owner and name
$Owner = "microsoft"
$Repo = "terminal"

# Get the latest release information of the specified repository
$releaseInfo = Get-GitHubRelease -Owner $Owner -Repo $Repo
Write-Output "Latest version: $($releaseInfo.LatestVersion)"
Write-Output "Published at: $($releaseInfo.PublishedDateTime)"
Write-Output "Download URL: $($releaseInfo.DownloadUrl)"

# Download the zip file
$zipFilePath = [System.IO.Path]::Combine($resolvedWtpFolderPath.Path, "Microsoft.WindowsTerminal_$($releaseInfo.LatestVersion)_x64.zip")
Write-Output "Downloading zip file..."
Invoke-WebRequest -Uri $releaseInfo.DownloadUrl -OutFile $zipFilePath
Write-Debug "zipFilePath: $zipFilePath"

# Look for Microsoft.WindowsTerminal_*_x64.zip in the specified folder
$zipFile = Get-ChildItem -Path $resolvedWtpFolderPath.Path -Filter "Microsoft.WindowsTerminal_*_x64.zip" | Select-Object -First 1

if (-not $zipFile) {
    Write-Warning "No zip file matching 'Microsoft.WindowsTerminal_*_x64.zip' found in the specified folder."
    exit
} else {
    Write-Output "Found zip file."
    Write-Debug "zipFile: $($zipFile.FullName)"
}

# Paths to wtp.exe and wtp_user.exe
$wtpExePath = [System.IO.Path]::Combine($resolvedWtpFolderPath.Path, "wtp.exe")
$wtpUserExePath = [System.IO.Path]::Combine($resolvedWtpFolderPath.Path, "wtp_user.exe")

# Check if paths exist
if (!(Test-Path $wtpExePath)) {
    Write-Warning "The path to wtp.exe does not exist: $wtpExePath"
    exit
}

if (!(Test-Path $wtpUserExePath)) {
    Write-Warning "The path to wtp_user.exe does not exist: $wtpUserExePath"
    exit
}

# Create extraction directory if it doesn't exist
$extractedPath = ".\Extracted"
if (-not (Test-Path -Path $extractedPath)) {
    $extractedPath = New-Item -Path $extractedPath -ItemType Directory -Force
} else {
    $extractedPath = Get-Item -Path $extractedPath
}

# Extract the zip file
Write-Output "Extracting zip file..."
Expand-Archive -Path $zipFile.FullName -DestinationPath $extractedPath.FullName -Force

# Remove existing "Terminal" directory if it exists
$existingTerminalPath = [System.IO.Path]::Combine($extractedPath.FullName, "Terminal")
if (Test-Path -Path $existingTerminalPath) {
    Remove-Item -Path $existingTerminalPath -Recurse -Force
}

# Rename terminal-* folder to "Terminal"
$terminalFolder = Get-ChildItem -Path $extractedPath.FullName -Filter "terminal-*" | Select-Object -First 1
if ($terminalFolder) {
    Rename-Item -Path $terminalFolder.FullName -NewName "Terminal"
} else {
    Write-Warning "Terminal folder not found."
    exit
}

# Path for the extracted terminal folder
$terminalPath = [System.IO.Path]::Combine($extractedPath.FullName, "Terminal")

# Create .portable file in the Terminal folder
Create-PortableFile $terminalPath

# Update the wtp.exe and wtp_user.exe SFX archives
Update-SFXArchive $wtpExePath $terminalPath
Update-SFXArchive $wtpUserExePath $terminalPath

try {
    # Delete the extracted folder
    if (-not $debugMode) {
        Write-Output "Deleting extracted folder..."
        Start-Sleep -Seconds 2
        Remove-Item -Path $extractedPath.FullName -Recurse -Force
    } else {
        Write-Debug "Debug mode is on. Skipping deletion of extracted folder."
    }
} catch {
    Write-Error "Failed to delete the extracted folder."
    throw $_
}

# Delete the zip file
if (-not $debugMode) {
    Write-Output "Deleting zip file..."
    Remove-Item -Path $zipFile.FullName -Force
} else {
    Write-Debug "Debug mode is on. Skipping deletion of zip file."
}

Write-Output "Operation completed successfully."