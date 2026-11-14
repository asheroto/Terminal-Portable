[CmdletBinding()]
param (
    [string]$WtpFolderPath = $PSScriptRoot
)

# ============================================================================ #
# Variables
# ============================================================================ #

# Path to the WinRAR console executable (works without a GUI, so it also runs in GitHub Actions)
$winRARPath = "C:\Program Files\WinRAR\Rar.exe"

# Debug mode - disables deletion of extracted folder and zip file
$debugMode = $false

# Invoke-WebRequest is much slower in Windows PowerShell 5.1 while drawing its progress bar
$ProgressPreference = 'SilentlyContinue'

# ============================================================================ #
# Functions
# ============================================================================ #

Function Get-GitHubRelease {
    <#
        .SYNOPSIS
        Fetches the latest release information of a GitHub repository.

        .DESCRIPTION
        This function uses the GitHub API to get information about the latest release of a specified repository, including its version, publish date, x64 download URL, and SHA256 digest.

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
        # Authenticate when a token is available (GitHub Actions) to avoid the shared anonymous rate limit
        $headers = @{}
        if ($env:GH_TOKEN) { $headers.Authorization = "Bearer $env:GH_TOKEN" }
        $response = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop

        $latestVersion = $response.tag_name
        $publishedAt = $response.published_at
        $x64Asset = $response.assets | Where-Object { $_.name -like "*x64.zip" } | Select-Object -First 1

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
            Digest            = $x64Asset.digest
        }
    } catch {
        Write-Error "Unable to check for updates.`nError: $_"
        exit 1
    }
}

# Function to create .portable file
Function New-PortableFile($terminalPath) {
    $portableFilePath = [System.IO.Path]::Combine($terminalPath, ".portable")
    New-Item -Path $portableFilePath -ItemType File -Force | Out-Null
}

# Function to update SFX archive
Function Update-SFXArchive($sfxPath, $terminalPath) {
    Write-Debug "sfxPath: $sfxPath"
    Write-Debug "terminalPath: $terminalPath"

    # Change to the parent directory of Terminal
    Push-Location -Path (Split-Path -Path $terminalPath -Parent)

    # Replace the "Terminal" folder in the SFX archive. Deleting it first drops files that are
    # no longer in the new release, while files at the archive root (icon.ico) are kept.
    Write-Output "Updating $(Split-Path -Path $sfxPath -Leaf)..."
    & $winRARPath d -idq "$sfxPath" "Terminal\*" "Terminal"
    $deleteExitCode = $LASTEXITCODE
    & $winRARPath a -r -idq "$sfxPath" "Terminal"
    $addExitCode = $LASTEXITCODE

    # Return to the original directory
    Pop-Location

    # Exit code 10 on delete means there was no Terminal folder to remove
    if ($deleteExitCode -notin 0, 10 -or $addExitCode -ne 0) {
        Write-Error "WinRAR failed to update $sfxPath (delete exit code $deleteExitCode, add exit code $addExitCode)."
        exit 1
    }
}

# ============================================================================ #
# Main code
# ============================================================================ #

# Validate and resolve WtpFolderPath
try {
    $resolvedWtpFolderPath = Resolve-Path -Path $WtpFolderPath -ErrorAction Stop
    if (!(Test-Path -Path $resolvedWtpFolderPath -PathType Container)) {
        Write-Output "The specified folder path for wtp_admin.exe and wtp_user.exe does not exist or is not a directory."
        exit 1
    }
} catch {
    Write-Output "The specified folder path for wtp_admin.exe and wtp_user.exe does not exist."
    exit 1
}

# Check prerequisites before downloading anything
if (!(Test-Path $winRARPath)) {
    Write-Warning "WinRAR was not found at: $winRARPath"
    exit 1
}

$wtpExePath = [System.IO.Path]::Combine($resolvedWtpFolderPath.Path, "wtp_admin.exe")
$wtpUserExePath = [System.IO.Path]::Combine($resolvedWtpFolderPath.Path, "wtp_user.exe")

if (!(Test-Path $wtpExePath)) {
    Write-Warning "The path to wtp_admin.exe does not exist: $wtpExePath"
    exit 1
}

if (!(Test-Path $wtpUserExePath)) {
    Write-Warning "The path to wtp_user.exe does not exist: $wtpUserExePath"
    exit 1
}

# Get the latest release information
$releaseInfo = Get-GitHubRelease -Owner "microsoft" -Repo "terminal"
Write-Output "Latest version: $($releaseInfo.LatestVersion)"
Write-Output "Published at: $($releaseInfo.PublishedDateTime)"
Write-Output "Download URL: $($releaseInfo.DownloadUrl)"

# Download the zip file
$zipFilePath = [System.IO.Path]::Combine($resolvedWtpFolderPath.Path, "Microsoft.WindowsTerminal_$($releaseInfo.LatestVersion)_x64.zip")
Write-Output "Downloading zip file..."
Invoke-WebRequest -Uri $releaseInfo.DownloadUrl -OutFile $zipFilePath -ErrorAction Stop
Write-Debug "zipFilePath: $zipFilePath"

# Verify the download against the SHA256 digest GitHub publishes for the asset
if ($releaseInfo.Digest -match '^sha256:(?<hash>[0-9a-f]{64})$') {
    $actualHash = (Get-FileHash -Path $zipFilePath -Algorithm SHA256).Hash
    if ($actualHash -ne $Matches.hash) {
        Remove-Item -Path $zipFilePath -Force
        Write-Error "SHA256 mismatch for the downloaded zip. Expected $($Matches.hash), got $actualHash."
        exit 1
    }
    Write-Output "SHA256 verified."
} else {
    Write-Warning "GitHub did not provide a SHA256 digest for this asset. Skipping verification."
}

# Start from a clean extraction directory so folders from earlier runs are not picked up
$extractedPath = [System.IO.Path]::Combine($resolvedWtpFolderPath.Path, "Extracted-Terminal-Portable")
if (Test-Path -Path $extractedPath) {
    Remove-Item -Path $extractedPath -Recurse -Force
}
New-Item -Path $extractedPath -ItemType Directory -Force | Out-Null

# Extract the zip file
Write-Output "Extracting zip file..."
Expand-Archive -Path $zipFilePath -DestinationPath $extractedPath -Force

# Rename terminal-* folder to "Terminal"
$terminalFolder = Get-ChildItem -Path $extractedPath -Directory -Filter "terminal-*" | Select-Object -First 1
if ($terminalFolder) {
    Rename-Item -Path $terminalFolder.FullName -NewName "Terminal"
} else {
    Write-Warning "Terminal folder not found."
    exit 1
}

# Path for the extracted terminal folder
$terminalPath = [System.IO.Path]::Combine($extractedPath, "Terminal")

# Create .portable file in the Terminal folder
New-PortableFile $terminalPath

# Update the wtp_admin.exe and wtp_user.exe SFX archives
Update-SFXArchive $wtpExePath $terminalPath
Update-SFXArchive $wtpUserExePath $terminalPath

try {
    # Delete the extracted folder
    if (-not $debugMode) {
        Write-Output "Deleting extracted folder..."
        Start-Sleep -Seconds 2
        Remove-Item -Path $extractedPath -Recurse -Force
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
    Remove-Item -Path $zipFilePath -Force
} else {
    Write-Debug "Debug mode is on. Skipping deletion of zip file."
}

Write-Output "Operation completed successfully."
