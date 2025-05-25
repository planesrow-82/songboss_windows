# Silent Installer Script for FFmpeg, VLC, and SongBoss
# Version: 1.0
# Usage: iwr -useb "https://raw.githubusercontent.com/planesrow-82/songboss_windows/main/install_songboss.ps1" | iex

param(
    [switch]$SkipPause
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to write section headers
function Write-SectionHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Yellow
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host ""
}

# Function to download file with progress
function Download-FileWithProgress {
    param(
        [string]$Url,
        [string]$OutputPath,
        [string]$Description
    )
    
    try {
        Write-ColorOutput "Downloading $Description..." "Yellow"
        Write-ColorOutput "URL: $Url" "Gray"
        Write-ColorOutput "Destination: $OutputPath" "Gray"
        
        # Use Invoke-WebRequest with progress tracking
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutputPath)
        $webClient.Dispose()
        
        # Verify file was downloaded
        if (Test-Path $OutputPath) {
            $fileSize = (Get-Item $OutputPath).Length / 1MB
            Write-ColorOutput "Download completed successfully! Size: $([math]::Round($fileSize, 2)) MB" "Green"
            return $true
        } else {
            throw "File not found after download"
        }
    }
    catch {
        Write-ColorOutput "Download failed: $($_.Exception.Message)" "Red"
        return $false
    }
}

# Function to run installer
function Install-Application {
    param(
        [string]$InstallerPath,
        [string]$Arguments,
        [string]$AppName
    )
    
    try {
        Write-ColorOutput "Installing $AppName..." "Yellow"
        Write-ColorOutput "Running: $InstallerPath $Arguments" "Gray"
        
        $process = Start-Process -FilePath $InstallerPath -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-ColorOutput "$AppName installed successfully!" "Green"
            return $true
        } else {
            Write-ColorOutput "$AppName installation failed with exit code: $($process.ExitCode)" "Red"
            return $false
        }
    }
    catch {
        Write-ColorOutput "Error installing $AppName`: $($_.Exception.Message)" "Red"
        return $false
    }
}

# Main script execution
try {
    # Script header
    Clear-Host
    Write-SectionHeader "SILENT INSTALLER SCRIPT"
    Write-ColorOutput "This script will install:" "Cyan"
    Write-ColorOutput "FFmpeg (Full version)" "White"
    Write-ColorOutput "VLC Media Player" "White"
    Write-ColorOutput "SongBoss v0.9.7.2" "White"
    Write-Host ""
    
    # Check admin status
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        Write-ColorOutput "Running as Administrator - Windows Defender exclusions will be added" "Green"
    } else {
        Write-ColorOutput "Not running as Administrator - some features may be limited" "Yellow"
        Write-ColorOutput "For best results, run PowerShell as Administrator" "Yellow"
    }
    
    Write-Host ""
    Write-ColorOutput "Starting installation process..." "Green"

    # Create temp directory
    $tempDir = Join-Path $env:TEMP "SilentInstaller_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-ColorOutput "Created temporary directory: $tempDir" "Gray"

    # Installation results tracking
    $results = @{
        FFmpeg = $false
        VLC = $false
        SongBoss = $false
    }

    # Install FFmpeg
    Write-SectionHeader "INSTALLING FFMPEG"
    try {
        # Download FFmpeg (using a reliable source - you may need to adjust URL)
        $ffmpegUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
        $ffmpegZip = Join-Path $tempDir "ffmpeg.zip"
        $ffmpegExtracted = Join-Path $tempDir "ffmpeg"
        
        if (Download-FileWithProgress -Url $ffmpegUrl -OutputPath $ffmpegZip -Description "FFmpeg") {
            Write-ColorOutput "Extracting FFmpeg..." "Yellow"
            Expand-Archive -Path $ffmpegZip -DestinationPath $ffmpegExtracted -Force
            
            # Find the extracted ffmpeg folder and copy to Program Files
            $ffmpegBinFolder = Get-ChildItem -Path $ffmpegExtracted -Directory | Select-Object -First 1
            $destinationPath = "C:\Program Files\FFmpeg"
            
            if (Test-Path $destinationPath) {
                Remove-Item $destinationPath -Recurse -Force
            }
            
            Copy-Item -Path $ffmpegBinFolder.FullName -Destination $destinationPath -Recurse -Force
            
            # Add to PATH if not already present
            $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            $ffmpegBinPath = Join-Path $destinationPath "bin"
            
            if ($currentPath -notlike "*$ffmpegBinPath*") {
                Write-ColorOutput "Adding FFmpeg to system PATH..." "Yellow"
                [Environment]::SetEnvironmentVariable("Path", "$currentPath;$ffmpegBinPath", "Machine")
            }
            
            Write-ColorOutput "FFmpeg installed successfully!" "Green"
            $results.FFmpeg = $true
        }
    }
    catch {
        Write-ColorOutput "FFmpeg installation failed: $($_.Exception.Message)" "Red"
    }

    # Install VLC
    Write-SectionHeader "INSTALLING VLC MEDIA PLAYER"
    try {
        # VLC download URL (64-bit)
        $vlcUrl = "https://download.videolan.org/pub/videolan/vlc/last/win64/vlc-3.0.20-win64.exe"
        $vlcInstaller = Join-Path $tempDir "vlc-installer.exe"
        
        if (Download-FileWithProgress -Url $vlcUrl -OutputPath $vlcInstaller -Description "VLC Media Player") {
            $results.VLC = Install-Application -InstallerPath $vlcInstaller -Arguments "/S" -AppName "VLC Media Player"
        }
    }
    catch {
        Write-ColorOutput "VLC installation failed: $($_.Exception.Message)" "Red"
    }

    # Install SongBoss
    Write-SectionHeader "INSTALLING SONGBOSS"
    try {
        $songBossUrl = "https://sourceforge.net/projects/songboss/files/Windows_11/SongBoss_0.9.7.2_Win11.exe/download"
        $songBossInstaller = Join-Path $tempDir "SongBoss_installer.exe"
        
        if (Download-FileWithProgress -Url $songBossUrl -OutputPath $songBossInstaller -Description "SongBoss v0.9.7.2") {
            
            # Add Windows Defender exclusion for SongBoss installer
            Write-ColorOutput "Adding Windows Defender exclusion for SongBoss installer..." "Yellow"
            try {
                # Check if running as administrator
                $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                
                if ($isAdmin) {
                    # Add exclusion for the installer file
                    Add-MpPreference -ExclusionPath $songBossInstaller -ErrorAction SilentlyContinue
                    
                    # Add exclusion for common SongBoss installation directories
                    $programFilesPath = "${env:ProgramFiles}\SongBoss"
                    $programFilesX86Path = "${env:ProgramFiles(x86)}\SongBoss"
                    $localAppDataPath = "${env:LOCALAPPDATA}\SongBoss"
                    
                    Add-MpPreference -ExclusionPath $programFilesPath -ErrorAction SilentlyContinue
                    Add-MpPreference -ExclusionPath $programFilesX86Path -ErrorAction SilentlyContinue
                    Add-MpPreference -ExclusionPath $localAppDataPath -ErrorAction SilentlyContinue
                    
                    Write-ColorOutput "Windows Defender exclusions added successfully" "Green"
                } else {
                    Write-ColorOutput "Warning: Not running as administrator - cannot add Windows Defender exclusions" "Yellow"
                    Write-ColorOutput "The installation may still work, but if it fails, try running PowerShell as Administrator" "Yellow"
                }
            }
            catch {
                Write-ColorOutput "Warning: Could not add Windows Defender exclusions: $($_.Exception.Message)" "Yellow"
                Write-ColorOutput "Proceeding with installation anyway..." "Yellow"
            }
            
            # Brief pause to allow Defender exclusions to take effect
            Start-Sleep -Seconds 2
            
            $results.SongBoss = Install-Application -InstallerPath $songBossInstaller -Arguments "/S" -AppName "SongBoss"
        }
    }
    catch {
        Write-ColorOutput "SongBoss installation failed: $($_.Exception.Message)" "Red"
    }

    # Cleanup
    Write-SectionHeader "CLEANUP"
    try {
        Write-ColorOutput "Cleaning up temporary files..." "Yellow"
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-ColorOutput "Cleanup completed" "Green"
    }
    catch {
        Write-ColorOutput "Warning: Could not clean up temporary files at $tempDir" "Yellow"
    }

    # Final results
    Write-SectionHeader "INSTALLATION SUMMARY"
    
    $successCount = 0
    foreach ($app in $results.Keys) {
        if ($results[$app]) {
            Write-ColorOutput "✓ $app - SUCCESS" "Green"
            $successCount++
        } else {
            Write-ColorOutput "✗ $app - FAILED" "Red"
        }
    }
    
    Write-Host ""
    if ($successCount -eq $results.Count) {
        Write-ColorOutput "All applications installed successfully! ($successCount/$($results.Count))" "Green"
    } elseif ($successCount -gt 0) {
        Write-ColorOutput "Partial success: $successCount out of $($results.Count) applications installed" "Yellow"
    } else {
        Write-ColorOutput "Installation failed for all applications" "Red"
    }
    
    Write-Host ""
    Write-ColorOutput "Note: You may need to restart your command prompt or system for PATH changes to take effect." "Cyan"

}
catch {
    Write-ColorOutput "Script execution failed: $($_.Exception.Message)" "Red"
}
finally {
    # Pause for user acknowledgment unless skipped
    if (-not $SkipPause) {
        Write-Host ""
        Write-ColorOutput "Press any key to exit..." "Gray"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}
