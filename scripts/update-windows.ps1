[CmdletBinding()]
param(
    [switch]$SkipWindowsUpdate,
    [switch]$SkipPackages
)

$ErrorActionPreference = 'Continue'

function Invoke-UpdateStep {
    param(
        [Parameter(Mandatory)] [string]$Title,
        [Parameter(Mandatory)] [scriptblock]$Action
    )

    Write-Host "`n==> $Title" -ForegroundColor Cyan
    try {
        & $Action
        if (-not $?) { Write-Warning "$Title failed (continuing)." }
    }
    catch {
        Write-Warning "$Title failed: $($_.Exception.Message)"
    }
}

Write-Host 'Updating Windows, installed apps, and available developer tools.'
Write-Host 'Save your work before running this. Some updates may ask for a restart.'

if (-not $SkipWindowsUpdate) {
    Invoke-UpdateStep 'Windows Update' {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $result = $searcher.Search("IsInstalled=0 and IsHidden=0 and Type='Software'")

        if ($result.Updates.Count -eq 0) {
            Write-Host 'No applicable Windows software updates found.'
            return
        }

        $updates = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($update in $result.Updates) {
            if (-not $update.EulaAccepted) { $update.AcceptEula() }
            [void]$updates.Add($update)
            Write-Host "  $($update.Title)"
        }

        $downloader = $session.CreateUpdateDownloader()
        $downloader.Updates = $updates
        $download = $downloader.Download()
        if ($download.ResultCode -notin 2, 3) { throw "Download returned result code $($download.ResultCode)." }

        $installer = $session.CreateUpdateInstaller()
        $installer.Updates = $updates
        $install = $installer.Install()
        if ($install.ResultCode -notin 2, 3) { throw "Install returned result code $($install.ResultCode)." }

        if ($install.RebootRequired) { Write-Warning 'Windows Update requires a restart.' }
        else { Write-Host 'Windows Update installation completed.' }
    }
}

if (-not $SkipPackages) {
    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        Invoke-UpdateStep 'WSL Linux distributions' {
            $distros = @(wsl --list --quiet 2>$null | ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ })
            foreach ($distro in $distros) {
                Write-Host "  Updating $distro"
                wsl -d $distro -- sh -lc 'if command -v apt-get >/dev/null 2>&1; then sudo -n apt-get update && sudo -n apt-get upgrade -y && sudo -n apt-get autoremove -y; elif command -v dnf >/dev/null 2>&1; then sudo -n dnf upgrade --refresh -y && sudo -n dnf autoremove -y; elif command -v pacman >/dev/null 2>&1; then sudo -n pacman -Syu --noconfirm; elif command -v zypper >/dev/null 2>&1; then sudo -n zypper refresh && sudo -n zypper update -y; else echo "No supported package manager found."; exit 1; fi'
                if ($LASTEXITCODE -ne 0) { Write-Warning "WSL update failed for $distro (continuing)." }
            }
            if ($distros.Count -eq 0) { Write-Host 'No WSL distributions found.' }
        }
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Invoke-UpdateStep 'Winget packages' {
            winget upgrade --all --accept-source-agreements --accept-package-agreements
        }
    }

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Invoke-UpdateStep 'Chocolatey packages' { choco upgrade all -y }
    }

    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Invoke-UpdateStep 'Scoop apps' { scoop update; scoop update * }
    }

    if (Get-Command rustup -ErrorAction SilentlyContinue) {
        Invoke-UpdateStep 'Rust toolchains' { rustup update }
    }

    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Invoke-UpdateStep 'Global npm packages' { npm update -g }
    }

    if (Get-Command pnpm -ErrorAction SilentlyContinue) {
        Invoke-UpdateStep 'Global pnpm packages' { pnpm update -g }
    }

    if (Get-Command bun -ErrorAction SilentlyContinue) {
        Invoke-UpdateStep 'Bun runtime' { bun upgrade }
    }

    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Invoke-UpdateStep 'uv runtime' { uv self update }
        Invoke-UpdateStep 'uv tools' { uv tool upgrade --all }
    }

    if (Get-Command pipx -ErrorAction SilentlyContinue) {
        Invoke-UpdateStep 'pipx tools' { pipx upgrade-all }
    }

    if (Get-Command flutter -ErrorAction SilentlyContinue) {
        Invoke-UpdateStep 'Flutter SDK' { flutter upgrade --force }
    }

    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Invoke-UpdateStep 'Docker images' { docker image prune --force }
    }
}

Write-Host "`nUpdate check complete. Restart Windows if an update requested it."
