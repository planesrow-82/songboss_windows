# Silent Installer Script for FFmpeg, VLC, and SongBoss
# Version: 1.1
# Usage: iwr -useb "https://raw.githubusercontent.com/yourusername/yourrepo/main/install.ps1" | iex

param(
    [switch]$SkipPause
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Global variables
$script:tempDir = ""
$script:isAdmin = $false
$script:defenderExclusions = @()

#region Utility Functions

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-SectionHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Yellow
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host ""
}

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
        
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutputPath)
        $webClient.Dispose()
        
        if (Test-Path $OutputPath) {
            $fileSize = (Get-Item $OutputPath).Length / 1MB
            Write-ColorOutput "[SUCCESS] Download completed successfully! Size: $([math]::Round($fileSize, 2)) MB" "Green"
            return $true
        } else {
            throw "File not found after download"
        }
    }
    catch {
        Write-ColorOutput "[ERROR] Download failed: $($_.Exception.Message)" "Red"
        return $false
    }
}

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
            Write-ColorOutput "[SUCCESS] $AppName installed successfully!" "Green"
            return $true
        } else {
            Write-ColorOutput "[ERROR] $AppName installation failed with exit code: $($process.ExitCode)" "Red"
            return $false
        }
    }
    catch {
        Write-ColorOutput "[ERROR] Error installing $AppName`: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Add-DefenderExclusion {
    param([string]$Path)
    
    if ($script:isAdmin) {
        try {
            Add-MpPreference -ExclusionPath $Path -ErrorAction Stop
            $script:defenderExclusions += $Path
            Write-ColorOutput "Added Windows Defender exclusion: $Path" "Green"
            return $true
        }
        catch {
            Write-ColorOutput "Warning: Could not add exclusion for $Path`: $($_.Exception.Message)" "Yellow"
            return $false
        }
    } else {
        Write-ColorOutput "Warning: Not running as administrator - cannot add exclusion for $Path" "Yellow"
        return $false
    }
}

function Remove-DefenderExclusions {
    if ($script:defenderExclusions.Count -gt 0 -and $script:isAdmin) {
        Write-SectionHeader "REMOVING WINDOWS DEFENDER EXCLUSIONS"
        Write-ColorOutput "Removing temporary Windows Defender exclusions..." "Yellow"
        
        foreach ($path in $script:defenderExclusions) {
            try {
                Remove-MpPreference -ExclusionPath $path -ErrorAction Stop
                Write-ColorOutput "Removed exclusion: $path" "Gray"
            }
            catch {
                Write-ColorOutput "Warning: Could not remove exclusion for $path`: $($_.Exception.Message)" "Yellow"
            }
        }
        
        Write-ColorOutput "[SUCCESS] Windows Defender exclusions cleanup completed" "Green"
        $script:defenderExclusions = @()
    }
}

#endregion

#region Installation Functions

function Install-FFmpeg {
    Write-SectionHeader "INSTALLING FFMPEG"
    
    try {
        $ffmpegUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
        $ffmpegZip = Join-Path $script:tempDir "ffmpeg.zip"
        $ffmpegExtracted = Join-Path $script:tempDir "ffmpeg"
        
        if (Download-FileWithProgress -Url $ffmpegUrl -OutputPath $ffmpegZip -Description "FFmpeg") {
            Write-ColorOutput "Extracting FFmpeg..." "Yellow"
            Expand-Archive -Path $ffmpegZip -DestinationPath $ffmpegExtracted -Force
            
            # Find the extracted ffmpeg folder
            $ffmpegBinFolder = Get-ChildItem -Path $ffmpegExtracted -Directory | Select-Object -First 1
            $destinationPath = "C:\Program Files\FFmpeg"
            
            # Remove existing installation if present
            if (Test-Path $destinationPath) {
                Write-ColorOutput "Removing existing FFmpeg installation..." "Yellow"
                Remove-Item $destinationPath -Recurse -Force
            }
            
            # Copy to Program Files
            Write-ColorOutput "Installing FFmpeg to $destinationPath..." "Yellow"
            Copy-Item -Path $ffmpegBinFolder.FullName -Destination $destinationPath -Recurse -Force
            
            # Add to system PATH
            $ffmpegBinPath = Join-Path $destinationPath "bin"
            $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            
            if ($currentPath -notlike "*$ffmpegBinPath*") {
                Write-ColorOutput "Adding FFmpeg to system PATH..." "Yellow"
                $newPath = "$currentPath;$ffmpegBinPath"
                [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
                
                # Update current session PATH
                $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
                
                Write-ColorOutput "FFmpeg added to system PATH" "Green"
            } else {
                Write-ColorOutput "FFmpeg already in system PATH" "Gray"
            }
            
            # Verify installation
            if (Test-Path (Join-Path $ffmpegBinPath "ffmpeg.exe")) {
                Write-ColorOutput "[SUCCESS] FFmpeg installed successfully!" "Green"
                return $true
            } else {
                throw "FFmpeg executable not found after installation"
            }
        }
        
        return $false
    }
    catch {
        Write-ColorOutput "[ERROR] FFmpeg installation failed: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Install-VLC {
    Write-SectionHeader "INSTALLING VLC MEDIA PLAYER"
    
    try {
        $vlcUrl = "https://download.videolan.org/pub/videolan/vlc/last/win64/vlc-3.0.20-win64.exe"
        $vlcInstaller = Join-Path $script:tempDir "vlc-installer.exe"
        
        if (Download-FileWithProgress -Url $vlcUrl -OutputPath $vlcInstaller -Description "VLC Media Player") {
            return (Install-Application -InstallerPath $vlcInstaller -Arguments "/S" -AppName "VLC Media Player")
        }
        
        return $false
    }
    catch {
        Write-ColorOutput "[ERROR] VLC installation failed: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Install-SongBoss {
    Write-SectionHeader "INSTALLING SONGBOSS"
    
    try {
        $songBossUrl = "https://sourceforge.net/projects/songboss/files/Windows_11/SongBoss_0.9.7.2_Win11.exe/download"
        $songBossInstaller = Join-Path $script:tempDir "SongBoss_installer.exe"
        
        if (Download-FileWithProgress -Url $songBossUrl -OutputPath $songBossInstaller -Description "SongBoss v0.9.7.2") {
            
            # Add Windows Defender exclusions
            Write-ColorOutput "Adding Windows Defender exclusions for SongBoss..." "Yellow"
            
            # Add exclusion for installer
            Add-DefenderExclusion -Path $songBossInstaller
            
            # Add exclusions for potential installation directories
            $exclusionPaths = @(
                "${env:ProgramFiles}\SongBoss",
                "${env:ProgramFiles(x86)}\SongBoss",
                "${env:LOCALAPPDATA}\SongBoss",
                "${env:APPDATA}\SongBoss"
            )
            
            foreach ($path in $exclusionPaths) {
                Add-DefenderExclusion -Path $path
            }
            
            # Brief pause to allow exclusions to take effect
            Start-Sleep -Seconds 3
            
            # Run the installer and capture the result
            $installResult = Install-Application -InstallerPath $songBossInstaller -Arguments "/S" -AppName "SongBoss"
            
            # Additional verification - check if SongBoss was actually installed
            if ($installResult) {
                $commonPaths = @(
                    "${env:ProgramFiles}\SongBoss",
                    "${env:ProgramFiles(x86)}\SongBoss",
                    "${env:LOCALAPPDATA}\SongBoss",
                    "${env:APPDATA}\SongBoss"
                )
                
                $found = $false
                foreach ($path in $commonPaths) {
                    if (Test-Path $path) {
                        Write-ColorOutput "SongBoss installation verified at: $path" "Green"
                        $found = $true
                        break
                    }
                }
                
                if (-not $found) {
                    Write-ColorOutput "Warning: SongBoss installer reported success but installation directory not found" "Yellow"
                    Write-ColorOutput "This may be normal if SongBoss installs to a non-standard location" "Yellow"
                }
            }
            
            return $installResult
        } else {
            Write-ColorOutput "[ERROR] Failed to download SongBoss installer" "Red"
            return $false
        }
    }
    catch {
        Write-ColorOutput "[ERROR] SongBoss installation failed: $($_.Exception.Message)" "Red"
        return $false
    }
}

#endregion

#region Main Script

function Initialize-Script {
    # Script header
    Clear-Host
    Write-SectionHeader "SILENT INSTALLER SCRIPT"
    Write-ColorOutput "This script will install:" "Cyan"
    Write-ColorOutput "FFmpeg (Full version)" "White"
    Write-ColorOutput "VLC Media Player" "White"
    Write-ColorOutput "SongBoss v0.9.7.2" "White"
    Write-Host ""
    
    # Check admin status
    $script:isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($script:isAdmin) {
        Write-ColorOutput "[ADMIN] Running as Administrator - Windows Defender exclusions will be added" "Green"
    } else {
        Write-ColorOutput "[WARNING] Not running as Administrator - some features may be limited" "Yellow"
        Write-ColorOutput "For best results, run PowerShell as Administrator" "Yellow"
    }
    
    Write-Host ""
    Write-ColorOutput "Starting installation process..." "Green"

    # Create temp directory
    $script:tempDir = Join-Path $env:TEMP "SilentInstaller_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
    Write-ColorOutput "Created temporary directory: $script:tempDir" "Gray"
}

function Cleanup-Resources {
    Write-SectionHeader "CLEANUP"
    
    # Remove Windows Defender exclusions first
    Remove-DefenderExclusions
    
    # Clean up temporary files
    try {
        Write-ColorOutput "Cleaning up temporary files..." "Yellow"
        if (Test-Path $script:tempDir) {
            Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction Stop
            Write-ColorOutput "[SUCCESS] Temporary files cleaned up" "Green"
        }
    }
    catch {
        Write-ColorOutput "[WARNING] Could not clean up temporary files at $script:tempDir" "Yellow"
        Write-ColorOutput "You may need to manually delete this folder later." "Yellow"
    }
}

# Main execution
try {
    Initialize-Script
    
    # Installation results tracking
    $results = @{
        FFmpeg = $false
        VLC = $false
        SongBoss = $false
    }

    # Run installations
    $results.FFmpeg = Install-FFmpeg
    $results.VLC = Install-VLC
    $results.SongBoss = Install-SongBoss

} catch {
    Write-ColorOutput "[ERROR] Script execution failed: $($_.Exception.Message)" "Red"
    Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" "Gray"
}
finally {
    # Always cleanup resources
    try {
        Cleanup-Resources
    }
    catch {
        Write-ColorOutput "[WARNING] Cleanup failed: $($_.Exception.Message)" "Yellow"
    }
    
    # Pause for user acknowledgment unless skipped
    if (-not $SkipPause) {
        Write-Host ""
        Write-ColorOutput "Press any key to exit..." "Gray"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

#endregion
