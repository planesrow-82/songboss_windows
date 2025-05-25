$LogFile = "$env:TEMP\install_log.txt"
Remove-Item -Path $LogFile -ErrorAction SilentlyContinue

function Write-ColorOutput {
    param (
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $Message
}

function Download-FileWithProgress {
    param (
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter()][string]$Description = "Downloading file",
        [int]$MaxRetries = 3
    )

    $attempt = 0
    do {
        try {
            $attempt++
            Write-ColorOutput "$Description (Attempt $attempt): $Url" "Cyan"
            Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
            Write-ColorOutput "[SUCCESS] Downloaded to $OutputPath" "Green"
            return $true
        } catch {
            Write-ColorOutput "[ERROR] Attempt $attempt failed: $_" "Red"
        }
    } while ($attempt -lt $MaxRetries)

    Write-ColorOutput "[ERROR] All $MaxRetries download attempts failed." "Red"
    return $false
}

function Install-Application {
    param (
        [Parameter(Mandatory = $true)][string]$InstallerPath,
        [Parameter()][string]$Arguments = "/S",
        [Parameter()][string]$AppName = "Application"
    )

    try {
        Write-ColorOutput "Installing $AppName from $InstallerPath..." "Cyan"
        $process = Start-Process -FilePath $InstallerPath -ArgumentList $Arguments -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-ColorOutput "[SUCCESS] $AppName installed successfully!" "Green"
            return $true
        } else {
            Write-ColorOutput "[ERROR] $AppName installer exited with code $($process.ExitCode)" "Red"
            return $false
        }
    } catch {
        Write-ColorOutput "[ERROR] Failed to install $AppName : $_" "Red"
        return $false
    }
}

function Add-ToPath {
    param (
        [Parameter(Mandatory = $true)][string]$NewPath
    )

    $envPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($envPath -notlike "*$NewPath*") {
        try {
            [Environment]::SetEnvironmentVariable("Path", "$envPath;$NewPath", "Machine")
            Write-ColorOutput "[SUCCESS] Added '$NewPath' to system PATH. You may need to restart for changes to take effect." "Yellow"
            return $true
        } catch {
            Write-ColorOutput "[ERROR] Failed to update PATH: $_" "Red"
            return $false
        }
    } else {
        Write-ColorOutput "[INFO] '$NewPath' is already in PATH." "Gray"
        return $true
    }
}

function Install-FFmpeg {
    $ffmpegUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
    $zipPath = "$env:TEMP\ffmpeg.zip"
    $extractPath = "$env:TEMP\ffmpeg"
    $destinationPath = "C:\Program Files\FFmpeg"
    $ffmpegBinPath = Join-Path $destinationPath "bin"

    if (-not (Download-FileWithProgress -Url $ffmpegUrl -OutputPath $zipPath -Description "Downloading FFmpeg")) {
        return $false
    }

    try {
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        $innerFolder = Get-ChildItem $extractPath | Where-Object { $_.PSIsContainer } | Select-Object -First 1
        if (-not $innerFolder) {
            Write-ColorOutput "[ERROR] FFmpeg archive structure is unexpected." "Red"
            return $false
        }

        Copy-Item -Path $innerFolder.FullName -Destination $destinationPath -Recurse -Force

        if (-not (Test-Path (Join-Path $ffmpegBinPath "ffmpeg.exe"))) {
            Write-ColorOutput "[ERROR] FFmpeg binary not found after installation." "Red"
            return $false
        }

        Add-ToPath -NewPath $ffmpegBinPath

        Write-ColorOutput "[SUCCESS] FFmpeg installed successfully!" "Green"
        return $true
    } catch {
        Write-ColorOutput "[ERROR] Failed to install FFmpeg: $_" "Red"
        return $false
    }
}

function Install-VLC {
    $vlcUrl = "https://get.videolan.org/vlc/3.0.20/win64/vlc-3.0.20-win64.exe"
    $installerPath = "$env:TEMP\vlc_installer.exe"
    if (-not (Download-FileWithProgress -Url $vlcUrl -OutputPath $installerPath -Description "Downloading VLC Media Player")) {
        return $false
    }

    return Install-Application -InstallerPath $installerPath -Arguments "/S" -AppName "VLC Media Player"
}

function Install-SongBoss {
    $songBossUrl = "https://www.dropbox.com/scl/fi/8duuqfnixot41plvg6xn7/SongBossSetup.exe?rlkey=23dkyoy3rcc9ry1c2jhdfnk7x&dl=1"
    $installerPath = "$env:TEMP\SongBossSetup.exe"
    if (-not (Download-FileWithProgress -Url $songBossUrl -OutputPath $installerPath -Description "Downloading SongBoss")) {
        return $false
    }

    $installResult = Install-Application -InstallerPath $installerPath -Arguments "/S" -AppName "SongBoss"

    # Verify installation
    $possiblePaths = @(
        "C:\Program Files\SongBoss",
        "C:\Program Files (x86)\SongBoss"
    )
    $found = $false
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $found = $true
            break
        }
    }

    if ($installResult -and $found) {
        Write-ColorOutput "[SUCCESS] SongBoss installed successfully!" "Green"
        return $true
    } else {
        Write-ColorOutput "[ERROR] SongBoss installation verification failed" "Red"
        return $false
    }
}

# ---------- Main Execution ----------

$results = @{
    FFmpeg = $false
    VLC = $false
    SongBoss = $false
}

try { $results.FFmpeg = Install-FFmpeg } catch { $results.FFmpeg = $false }
try { $results.VLC = Install-VLC } catch { $results.VLC = $false }
try { $results.SongBoss = Install-SongBoss } catch { $results.SongBoss = $false }

Write-ColorOutput "`n========== INSTALLATION SUMMARY ==========" "Cyan"
foreach ($app in $results.Keys) {
    if ($results[$app]) {
        Write-ColorOutput "$app Installed Successfully" "Green"
    } else {
        Write-ColorOutput "$app Installation Failed" "Red"
    }
}

Write-ColorOutput "`nInstallation log saved to: $LogFile" "Gray"
