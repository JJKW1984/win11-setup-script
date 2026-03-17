#Requires -Version 5.1
<#
.SYNOPSIS
    Windows 11 Developer Setup Script

.DESCRIPTION
    Sets up a Windows 11 machine for software development.
    Features include:
      - Windows debloat (removes bloatware, disables telemetry)
      - Windows optional features (WSL2, Hyper-V, Windows Sandbox, Developer Mode, OpenSSH)
      - Interactive menu for selecting software packs:
          * Common Developer Tools  (Git, Node.js, Python, Go, Rust, Docker ...)
          * IDEs & Code Editors    (VS Code, VS 2022, JetBrains suite, Neovim ...)
          * Automation & DevOps    (Terraform, kubectl, AWS/Azure/GCP CLI ...)
          * AI & ML Tools          (Ollama, LM Studio, CUDA ...)
          * Terminal & Shell       (Windows Terminal, Oh My Posh, Starship ...)
          * Productivity           (browsers, Postman, PowerToys, 7-Zip ...)

.NOTES
    Run as Administrator.
    Requires winget (App Installer) - shipped with Windows 11 by default.

.EXAMPLE
    # Run from an elevated PowerShell terminal:
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\Setup-Windows11Dev.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Colour helpers
# ---------------------------------------------------------------------------
function Write-Header {
    param([string]$Text)
    $line = '=' * 70
    Write-Host "`n$line" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "$line`n" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Text)
    Write-Host "  >> $Text" -ForegroundColor Yellow
}

function Write-OK {
    param([string]$Text)
    Write-Host "  [OK] $Text" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Text)
    Write-Host "  [!!] $Text" -ForegroundColor DarkYellow
}

function Write-Err {
    param([string]$Text)
    Write-Host "  [XX] $Text" -ForegroundColor Red
}

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
function Assert-Administrator {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Err 'This script must be run as Administrator.'
        Write-Host '  Right-click PowerShell -> "Run as administrator", then try again.' -ForegroundColor DarkYellow
        exit 1
    }
}

function Assert-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Err 'winget (App Installer) was not found.'
        Write-Host '  Install it from the Microsoft Store or visit:' -ForegroundColor DarkYellow
        Write-Host '  https://aka.ms/getwinget' -ForegroundColor DarkYellow
        exit 1
    }
    # Accept the source agreements non-interactively (first-run prompt)
    winget source update --disable-interactivity 2>$null | Out-Null
}

# ---------------------------------------------------------------------------
# winget install helper
# ---------------------------------------------------------------------------
function Install-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$Name = $Id
    )
    Write-Step "Installing $Name ..."
    $result = winget install --id $Id --silent --accept-package-agreements --accept-source-agreements 2>&1
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
        # Exit code -1978335189 (0x8A150021) = already installed
        Write-OK "$Name"
    } else {
        Write-Warn "Could not install $Name (winget exit code $LASTEXITCODE). Skipping."
    }
}

# ---------------------------------------------------------------------------
# Windows registry / policy helpers
# ---------------------------------------------------------------------------
function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = 'DWord'
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
}

# ---------------------------------------------------------------------------
# ===  DEBLOAT  ===
# ---------------------------------------------------------------------------
function Invoke-Debloat {
    Write-Header 'Windows 11 Debloat'

    # --- Remove built-in bloatware apps ---
    Write-Step 'Removing built-in bloatware apps ...'
    $bloatApps = @(
        'Microsoft.3DBuilder'
        'Microsoft.549981C3F5F10'         # Cortana standalone app
        'Microsoft.BingFinance'
        'Microsoft.BingFoodAndDrink'
        'Microsoft.BingHealthAndFitness'
        'Microsoft.BingNews'
        'Microsoft.BingSports'
        'Microsoft.BingTravel'
        'Microsoft.BingWeather'
        'Microsoft.Getstarted'
        'Microsoft.GetHelp'
        'Microsoft.Messaging'
        'Microsoft.Microsoft3DViewer'
        'Microsoft.MicrosoftOfficeHub'
        'Microsoft.MicrosoftSolitaireCollection'
        'Microsoft.MixedReality.Portal'
        'Microsoft.NetworkSpeedTest'
        'Microsoft.News'
        'Microsoft.Office.OneNote'
        'Microsoft.OneConnect'
        'Microsoft.People'
        'Microsoft.Print3D'
        'Microsoft.SkypeApp'
        'Microsoft.Todos'
        'Microsoft.WindowsAlarms'
        'Microsoft.WindowsFeedbackHub'
        'Microsoft.WindowsMaps'
        'Microsoft.WindowsSoundRecorder'
        'Microsoft.Xbox.TCUI'
        'Microsoft.XboxApp'
        'Microsoft.XboxGameOverlay'
        'Microsoft.XboxGamingOverlay'
        'Microsoft.XboxIdentityProvider'
        'Microsoft.XboxSpeechToTextOverlay'
        'Microsoft.YourPhone'
        'Microsoft.ZuneMusic'
        'Microsoft.ZuneVideo'
        'MicrosoftTeams'
        'Clipchamp.Clipchamp'
    )
    foreach ($app in $bloatApps) {
        $pkg = Get-AppxPackage -AllUsers -Name $app -ErrorAction SilentlyContinue
        if ($pkg) {
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop | Out-Null
                Write-OK "Removed $app"
            } catch {
                Write-Warn "Could not remove $app - $($_.Exception.Message)"
            }
        }
        # Also remove provisioned (pre-installed for new accounts)
        $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -eq $app }
        if ($prov) {
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction Stop | Out-Null
            } catch {
                # Silently skip provisioned removal errors
            }
        }
    }

    # --- Disable telemetry & data collection ---
    Write-Step 'Disabling telemetry & data collection ...'
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0
    Write-OK 'Telemetry disabled'

    # --- Disable advertising ID ---
    Write-Step 'Disabling advertising ID ...'
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 1
    Write-OK 'Advertising ID disabled'

    # --- Disable Cortana ---
    Write-Step 'Disabling Cortana ...'
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCortanaButton' 0
    Write-OK 'Cortana disabled'

    # --- Disable Start Menu web/Bing search ---
    Write-Step 'Disabling Start Menu web search ...'
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableWebSearch' 1
    Write-OK 'Web search in Start Menu disabled'

    # --- Disable Activity History / Timeline ---
    Write-Step 'Disabling Activity History ...'
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' 0
    Write-OK 'Activity History disabled'

    # --- Disable Location tracking ---
    Write-Step 'Disabling location tracking ...'
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value' 'Deny' -Type String
    Write-OK 'Location tracking disabled'

    # --- Disable Feedback notifications ---
    Write-Step 'Disabling Feedback notifications ...'
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications' 1
    Write-OK 'Feedback notifications disabled'

    # --- Disable unnecessary scheduled tasks ---
    Write-Step 'Disabling telemetry-related scheduled tasks ...'
    $tasks = @(
        '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser'
        '\Microsoft\Windows\Application Experience\ProgramDataUpdater'
        '\Microsoft\Windows\Autochk\Proxy'
        '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator'
        '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip'
        '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector'
        '\Microsoft\Windows\Feedback\Siuf\DmClient'
        '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload'
        '\Microsoft\Windows\Windows Error Reporting\QueueReporting'
    )
    foreach ($task in $tasks) {
        try {
            Disable-ScheduledTask -TaskName $task -ErrorAction Stop | Out-Null
            Write-OK "Disabled task: $task"
        } catch {
            Write-Warn "Task not found or already disabled: $task"
        }
    }

    # --- Disable unnecessary services ---
    Write-Step 'Disabling unnecessary services ...'
    $services = @(
        'DiagTrack'          # Connected User Experiences and Telemetry
        'dmwappushservice'   # WAP Push Message Routing Service
        'RetailDemo'         # Retail Demo Service
        'XblAuthManager'     # Xbox Live Auth Manager
        'XblGameSave'        # Xbox Live Game Save
        'XboxGipSvc'         # Xbox Accessory Management Service
        'XboxNetApiSvc'      # Xbox Live Networking Service
    )
    foreach ($svc in $services) {
        $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($s) {
            try {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Set-Service  -Name $svc -StartupType Disabled -ErrorAction Stop
                Write-OK "Disabled service: $svc"
            } catch {
                Write-Warn "Could not disable service: $svc"
            }
        }
    }

    # --- Show file extensions and hidden files in Explorer ---
    Write-Step 'Configuring Explorer: show extensions & hidden files ...'
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Hidden' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSuperHidden' 1
    Write-OK 'Explorer configured'

    # --- Disable Snap suggestions & widget panel ---
    Write-Step 'Disabling Widgets (News and Interests) ...'
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa' 0
    Write-OK 'Widgets disabled from taskbar'

    Write-Host "`n  Debloat complete!`n" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# ===  WINDOWS FEATURES  ===
# ---------------------------------------------------------------------------
function Invoke-WindowsFeatures {
    param([switch]$All)

    Write-Header 'Windows Optional Features'

    if ($All) {
        Enable-WSL2
        Enable-HyperV
        Enable-WindowsSandbox
        Enable-DeveloperMode
        Enable-OpenSSHClient
        return
    }

    $features = [ordered]@{
        '1' = @{ Name = 'WSL 2 (Windows Subsystem for Linux)';      Action = 'WSL2' }
        '2' = @{ Name = 'Hyper-V';                                   Action = 'HyperV' }
        '3' = @{ Name = 'Windows Sandbox';                           Action = 'Sandbox' }
        '4' = @{ Name = 'Developer Mode (sideloading / symlinks)';   Action = 'DevMode' }
        '5' = @{ Name = 'OpenSSH Client';                            Action = 'SSH' }
        '6' = @{ Name = 'Enable ALL of the above';                   Action = 'All' }
        '0' = @{ Name = 'Back to main menu';                         Action = 'Back' }
    }

    do {
        Write-Host ''
        Write-Host '  Select features to enable:' -ForegroundColor Cyan
        foreach ($key in $features.Keys) {
            Write-Host "    [$key] $($features[$key].Name)"
        }
        Write-Host ''
        $choice = Read-Host '  Enter choice'

        switch ($features[$choice].Action) {
            'WSL2'    { Enable-WSL2 }
            'HyperV'  { Enable-HyperV }
            'Sandbox'  { Enable-WindowsSandbox }
            'DevMode'  { Enable-DeveloperMode }
            'SSH'      { Enable-OpenSSHClient }
            'All' {
                Enable-WSL2
                Enable-HyperV
                Enable-WindowsSandbox
                Enable-DeveloperMode
                Enable-OpenSSHClient
            }
            'Back'    { return }
            default   { Write-Warn 'Invalid choice.' }
        }
    } while ($choice -ne '0')
}

function Enable-WSL2 {
    Write-Step 'Enabling WSL 2 ...'
    try {
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null
        Write-OK 'WSL 2 enabled (reboot required; then run: wsl --set-default-version 2)'
        # Install Ubuntu from winget as default distro
        Write-Step 'Installing Ubuntu via winget ...'
        winget install --id Canonical.Ubuntu.2404 --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        Write-OK 'Ubuntu 24.04 LTS queued for installation'
    } catch {
        Write-Warn "WSL2 setup encountered an error: $($_.Exception.Message)"
    }
}

function Enable-HyperV {
    Write-Step 'Enabling Hyper-V ...'
    try {
        dism.exe /online /enable-feature /featurename:Microsoft-Hyper-V-All /all /norestart | Out-Null
        Write-OK 'Hyper-V enabled (reboot required)'
    } catch {
        Write-Warn "Hyper-V setup encountered an error: $($_.Exception.Message)"
    }
}

function Enable-WindowsSandbox {
    Write-Step 'Enabling Windows Sandbox ...'
    try {
        dism.exe /online /enable-feature /featurename:Containers-DisposableClientVM /all /norestart | Out-Null
        Write-OK 'Windows Sandbox enabled (reboot required)'
    } catch {
        Write-Warn "Windows Sandbox setup encountered an error: $($_.Exception.Message)"
    }
}

function Enable-DeveloperMode {
    Write-Step 'Enabling Developer Mode ...'
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' 'AllowDevelopmentWithoutDevLicense' 1
    Write-OK 'Developer Mode enabled (allows sideloading & symlinks without elevation)'
}

function Enable-OpenSSHClient {
    Write-Step 'Enabling OpenSSH Client ...'
    try {
        Add-WindowsCapability -Online -Name 'OpenSSH.Client~~~~0.0.1.0' -ErrorAction Stop | Out-Null
        Write-OK 'OpenSSH Client enabled'
    } catch {
        Write-Warn "OpenSSH Client: $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# ===  SOFTWARE PACKS  ===
# ---------------------------------------------------------------------------

# --- Pack: Common Developer Tools ---
function Install-CommonDevTools {
    param([switch]$All)
    Write-Header 'Common Developer Tools'

    $packages = [ordered]@{
        '1'  = @{ Id = 'Git.Git';                    Name = 'Git' }
        '2'  = @{ Id = 'OpenJS.NodeJS.LTS';          Name = 'Node.js LTS' }
        '3'  = @{ Id = 'Python.Python.3.12';         Name = 'Python 3.12' }
        '4'  = @{ Id = 'GoLang.Go';                  Name = 'Go' }
        '5'  = @{ Id = 'Rustlang.Rustup';            Name = 'Rust (via rustup)' }
        '6'  = @{ Id = 'Oracle.JDK.21';              Name = 'Java JDK 21' }
        '7'  = @{ Id = 'Microsoft.DotNet.SDK.8';     Name = '.NET SDK 8' }
        '8'  = @{ Id = 'Docker.DockerDesktop';        Name = 'Docker Desktop' }
        '9'  = @{ Id = 'Microsoft.PowerShell';       Name = 'PowerShell 7' }
        '10' = @{ Id = 'junegunn.fzf';               Name = 'fzf (fuzzy finder)' }
        '11' = @{ Id = 'sharkdp.bat';                Name = 'bat (better cat)' }
        '12' = @{ Id = 'BurntSushi.ripgrep.MSVC';    Name = 'ripgrep' }
        '13' = @{ Id = 'eza-community.eza';           Name = 'eza (better ls)' }
        '14' = @{ Id = 'jqlang.jq';                  Name = 'jq (JSON processor)' }
        '15' = @{ Id = 'cURL.cURL';                  Name = 'curl' }
        '16' = @{ Id = 'GnuWin32.Make';              Name = 'make' }
        '17' = @{ Id = 'Kitware.CMake';              Name = 'CMake' }
        '18' = @{ Id = 'LLVM.LLVM';                  Name = 'LLVM / clang' }
        '19' = @{ Id = 'Schniz.fnm';                 Name = 'fnm (Node version manager)' }
        '20' = @{ Id = 'astral-sh.uv';               Name = 'uv (fast Python package manager)' }
        'A'  = @{ Id = '__ALL__';                    Name = 'Install ALL of the above' }
        '0'  = @{ Id = '__BACK__';                   Name = 'Back to main menu' }
    }

    Show-PackMenu $packages -InstallAll:$All
}

# --- Pack: IDEs & Code Editors ---
function Install-IDEs {
    param([switch]$All)
    Write-Header 'IDEs & Code Editors'

    $packages = [ordered]@{
        '1'  = @{ Id = 'Microsoft.VisualStudioCode';               Name = 'Visual Studio Code' }
        '2'  = @{ Id = 'Microsoft.VisualStudio.2022.Community';    Name = 'Visual Studio 2022 Community' }
        '3'  = @{ Id = 'JetBrains.IntelliJIDEA.Community';         Name = 'IntelliJ IDEA Community' }
        '4'  = @{ Id = 'JetBrains.PyCharm.Community';              Name = 'PyCharm Community' }
        '5'  = @{ Id = 'JetBrains.WebStorm';                       Name = 'WebStorm' }
        '6'  = @{ Id = 'JetBrains.GoLand';                         Name = 'GoLand' }
        '7'  = @{ Id = 'JetBrains.Rider';                          Name = 'Rider (.NET IDE)' }
        '8'  = @{ Id = 'JetBrains.DataGrip';                       Name = 'DataGrip' }
        '9'  = @{ Id = 'Eclipse.Adoptium.21';                      Name = 'Eclipse Temurin JDK 21 (Eclipse JDK)' }
        '10' = @{ Id = 'Neovim.Neovim';                            Name = 'Neovim' }
        '11' = @{ Id = 'vim.vim';                                   Name = 'Vim' }
        '12' = @{ Id = 'GNU.Emacs';                                 Name = 'Emacs' }
        '13' = @{ Id = 'Sublime HQ.Sublime Text 4';                Name = 'Sublime Text 4' }
        '14' = @{ Id = 'Notepad++.Notepad++';                      Name = 'Notepad++' }
        '15' = @{ Id = 'Cursor.Cursor';                            Name = 'Cursor (AI code editor)' }
        'A'  = @{ Id = '__ALL__';                                   Name = 'Install ALL of the above' }
        '0'  = @{ Id = '__BACK__';                                  Name = 'Back to main menu' }
    }

    Show-PackMenu $packages -InstallAll:$All
}

# --- Pack: Automation & DevOps Tools ---
function Install-AutomationTools {
    param([switch]$All)
    Write-Header 'Automation & DevOps Tools'

    $packages = [ordered]@{
        '1'  = @{ Id = 'Hashicorp.Terraform';                Name = 'Terraform' }
        '2'  = @{ Id = 'Hashicorp.Packer';                   Name = 'Packer' }
        '3'  = @{ Id = 'Hashicorp.Vault';                    Name = 'HashiCorp Vault' }
        '4'  = @{ Id = 'Kubernetes.kubectl';                  Name = 'kubectl' }
        '5'  = @{ Id = 'Helm.Helm';                          Name = 'Helm' }
        '6'  = @{ Id = 'mikefarah.yq';                       Name = 'yq (YAML processor)' }
        '7'  = @{ Id = 'RedHat.ansible-lint';                Name = 'Ansible Lint' }
        '8'  = @{ Id = 'Amazon.AWSCLI';                      Name = 'AWS CLI' }
        '9'  = @{ Id = 'Microsoft.AzureCLI';                 Name = 'Azure CLI' }
        '10' = @{ Id = 'Google.CloudSDK';                    Name = 'Google Cloud SDK' }
        '11' = @{ Id = 'Pulumi.Pulumi';                      Name = 'Pulumi' }
        '12' = @{ Id = 'argoproj.argocd';                    Name = 'ArgoCD CLI' }
        '13' = @{ Id = 'Derailed.k9s';                       Name = 'k9s (Kubernetes TUI)' }
        '14' = @{ Id = 'ahmetb.kubectx';                     Name = 'kubectx / kubens' }
        '15' = @{ Id = 'GitHubCLI.cli';                      Name = 'GitHub CLI (gh)' }
        '16' = @{ Id = 'GitLab.glab';                        Name = 'GitLab CLI (glab)' }
        '17' = @{ Id = 'JFrog.JFrog-CLI';                    Name = 'JFrog CLI' }
        '18' = @{ Id = 'Vagrant.Vagrant';                    Name = 'Vagrant' }
        '19' = @{ Id = 'Chocolatey.Chocolatey';              Name = 'Chocolatey package manager' }
        'A'  = @{ Id = '__ALL__';                            Name = 'Install ALL of the above' }
        '0'  = @{ Id = '__BACK__';                           Name = 'Back to main menu' }
    }

    Show-PackMenu $packages -InstallAll:$All
}

# --- Pack: AI & Machine Learning Tools ---
function Install-AITools {
    param([switch]$All)
    Write-Header 'AI & Machine Learning Tools'

    $packages = [ordered]@{
        '1'  = @{ Id = 'Ollama.Ollama';                      Name = 'Ollama (local LLM runner)' }
        '2'  = @{ Id = 'lmstudio.lmstudio';                  Name = 'LM Studio' }
        '3'  = @{ Id = 'Janhq.jan';                          Name = 'Jan (open-source ChatGPT alternative)' }
        '4'  = @{ Id = 'AnthropicAI.Claude';                 Name = 'Claude Desktop' }
        '5'  = @{ Id = 'Cursor.Cursor';                      Name = 'Cursor (AI code editor)' }
        '6'  = @{ Id = 'astral-sh.uv';                       Name = 'uv (Python package manager for ML workloads)' }
        '7'  = @{ Id = 'Python.Python.3.12';                 Name = 'Python 3.12 (required for most AI/ML tools)' }
        '8'  = @{ Id = 'Hugging Face.huggingface-cli';       Name = 'Hugging Face CLI' }
        '9'  = @{ Id = 'NVIDIA.CUDA';                        Name = 'NVIDIA CUDA Toolkit (GPU acceleration)' }
        '10' = @{ Id = 'OpenJS.NodeJS.LTS';                  Name = 'Node.js LTS (required for many AI dev tools)' }
        'A'  = @{ Id = '__ALL__';                            Name = 'Install ALL of the above' }
        '0'  = @{ Id = '__BACK__';                           Name = 'Back to main menu' }
    }

    Show-PackMenu $packages -InstallAll:$All
}

# --- Pack: Terminal & Shell Enhancements ---
function Install-TerminalTools {
    param([switch]$All)
    Write-Header 'Terminal & Shell Enhancements'

    $packages = [ordered]@{
        '1'  = @{ Id = 'Microsoft.WindowsTerminal';          Name = 'Windows Terminal' }
        '2'  = @{ Id = 'JanDeDobbeleer.OhMyPosh';           Name = 'Oh My Posh (prompt theme engine)' }
        '3'  = @{ Id = 'Starship.Starship';                  Name = 'Starship (cross-shell prompt)' }
        '4'  = @{ Id = 'wez.wezterm';                        Name = 'WezTerm (GPU-accelerated terminal)' }
        '5'  = @{ Id = 'Alacritty.Alacritty';               Name = 'Alacritty (fast terminal)' }
        '6'  = @{ Id = 'Hyper.Hyper';                        Name = 'Hyper terminal' }
        '7'  = @{ Id = 'GnuPG.Gpg4win';                     Name = 'Gpg4win (GPG for Windows)' }
        '8'  = @{ Id = 'twpayne.chezmoi';                    Name = 'chezmoi (dotfiles manager)' }
        '9'  = @{ Id = 'aristocratos.btop4win';              Name = 'btop (system monitor)' }
        '10' = @{ Id = 'Neovim.Neovim';                     Name = 'Neovim' }
        'A'  = @{ Id = '__ALL__';                            Name = 'Install ALL of the above' }
        '0'  = @{ Id = '__BACK__';                           Name = 'Back to main menu' }
    }

    Show-PackMenu $packages -InstallAll:$All
}

# --- Pack: Productivity & Utilities ---
function Install-ProductivityTools {
    param([switch]$All)
    Write-Header 'Productivity & Utilities'

    $packages = [ordered]@{
        '1'  = @{ Id = 'Mozilla.Firefox';                   Name = 'Firefox' }
        '2'  = @{ Id = 'Google.Chrome';                     Name = 'Google Chrome' }
        '3'  = @{ Id = 'Brave.Brave';                       Name = 'Brave Browser' }
        '4'  = @{ Id = 'Postman.Postman';                   Name = 'Postman (API testing)' }
        '5'  = @{ Id = 'Insomnia.Insomnia';                 Name = 'Insomnia (REST/GraphQL client)' }
        '6'  = @{ Id = 'Telerik.Fiddler.Classic';           Name = 'Fiddler Classic (HTTP debugger)' }
        '7'  = @{ Id = 'WiresharkFoundation.Wireshark';     Name = 'Wireshark' }
        '8'  = @{ Id = 'Microsoft.PowerToys';               Name = 'PowerToys' }
        '9'  = @{ Id = '7zip.7zip';                         Name = '7-Zip' }
        '10' = @{ Id = 'Notion.Notion';                     Name = 'Notion' }
        '11' = @{ Id = 'SlackTechnologies.Slack';           Name = 'Slack' }
        '12' = @{ Id = 'Discord.Discord';                   Name = 'Discord' }
        '13' = @{ Id = 'Zoom.Zoom';                         Name = 'Zoom' }
        '14' = @{ Id = 'DBeaver.DBeaver';                   Name = 'DBeaver (universal DB client)' }
        '15' = @{ Id = 'TablePlus.TablePlus';               Name = 'TablePlus (DB GUI)' }
        '16' = @{ Id = 'Figma.Figma';                       Name = 'Figma' }
        '17' = @{ Id = 'VideoLAN.VLC';                      Name = 'VLC Media Player' }
        'A'  = @{ Id = '__ALL__';                           Name = 'Install ALL of the above' }
        '0'  = @{ Id = '__BACK__';                          Name = 'Back to main menu' }
    }

    Show-PackMenu $packages -InstallAll:$All
}

# ---------------------------------------------------------------------------
# Generic multi-select pack menu
# ---------------------------------------------------------------------------
function Show-PackMenu {
    param(
        [System.Collections.Specialized.OrderedDictionary]$Packages,
        [switch]$InstallAll
    )

    if ($InstallAll) {
        foreach ($key in $Packages.Keys) {
            if ($key -ne 'A' -and $key -ne '0') {
                Install-WingetPackage -Id $Packages[$key].Id -Name $Packages[$key].Name
            }
        }
        return
    }

    do {
        Write-Host ''
        Write-Host '  Select packages to install (comma-separated for multiple, e.g. 1,3,5):' -ForegroundColor Cyan
        foreach ($key in $Packages.Keys) {
            if ($key -eq 'A' -or $key -eq '0') {
                Write-Host "    [$key] $($Packages[$key].Name)" -ForegroundColor DarkCyan
            } else {
                Write-Host "    [$key] $($Packages[$key].Name)"
            }
        }
        Write-Host ''
        $raw = Read-Host '  Enter choice(s)'

        if ($raw.Trim() -eq '0') { return }

        $selections = $raw.Split(',') | ForEach-Object { $_.Trim().ToUpper() }

        if ($selections -contains 'A') {
            # Install everything except ALL and BACK
            foreach ($key in $Packages.Keys) {
                if ($key -ne 'A' -and $key -ne '0') {
                    Install-WingetPackage -Id $Packages[$key].Id -Name $Packages[$key].Name
                }
            }
        } else {
            foreach ($sel in $selections) {
                if ($Packages.Contains($sel)) {
                    $pkg = $Packages[$sel]
                    Install-WingetPackage -Id $pkg.Id -Name $pkg.Name
                } else {
                    Write-Warn "Unknown option: $sel"
                }
            }
        }

        Write-Host ''
        $again = Read-Host '  Install more from this menu? [y/N]'
    } while ($again -match '^[Yy]')
}

# ---------------------------------------------------------------------------
# ===  MAIN MENU  ===
# ---------------------------------------------------------------------------
function Show-MainMenu {
    $banner = @'

  ██╗    ██╗██╗███╗   ██╗ ██╗ ██╗    ██████╗ ███████╗██╗   ██╗    ███████╗███████╗████████╗██╗   ██╗██████╗
  ██║    ██║██║████╗  ██║███║███║    ██╔══██╗██╔════╝██║   ██║    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗
  ██║ █╗ ██║██║██╔██╗ ██║╚██║╚██║    ██║  ██║█████╗  ██║   ██║    ███████╗█████╗     ██║   ██║   ██║██████╔╝
  ██║███╗██║██║██║╚██╗██║ ██║ ██║    ██║  ██║██╔══╝  ╚██╗ ██╔╝    ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝
  ╚███╔███╔╝██║██║ ╚████║ ██║ ██║    ██████╔╝███████╗ ╚████╔╝     ███████║███████╗   ██║   ╚██████╔╝██║
   ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝ ╚═╝ ╚═╝    ╚═════╝ ╚══════╝  ╚═══╝      ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝

  Windows 11 Developer Setup Script  |  github.com/JJKW1984/win11-setup-script
'@

    $menu = [ordered]@{
        '1' = 'Debloat Windows 11 (remove bloatware, disable telemetry)'
        '2' = 'Windows Features  (WSL2, Hyper-V, Sandbox, Developer Mode)'
        '3' = 'Common Developer Tools  (Git, Node, Python, Go, Rust, Docker ...)'
        '4' = 'IDEs & Code Editors  (VS Code, VS 2022, JetBrains, Neovim ...)'
        '5' = 'Automation & DevOps Tools  (Terraform, kubectl, AWS/Azure CLI ...)'
        '6' = 'AI & Machine Learning Tools  (Ollama, LM Studio, CUDA ...)'
        '7' = 'Terminal & Shell Enhancements  (Windows Terminal, Oh My Posh ...)'
        '8' = 'Productivity & Utilities  (browsers, Postman, PowerToys, 7-Zip ...)'
        '9' = 'Run EVERYTHING (full developer machine setup)'
        '0' = 'Exit'
    }

    do {
        Clear-Host
        Write-Host $banner -ForegroundColor Blue
        Write-Host ''
        Write-Host '  Main Menu' -ForegroundColor Cyan
        Write-Host '  ---------' -ForegroundColor Cyan
        foreach ($key in $menu.Keys) {
            if ($key -eq '9') {
                Write-Host "  [$key] $($menu[$key])" -ForegroundColor Magenta
            } elseif ($key -eq '0') {
                Write-Host "  [$key] $($menu[$key])" -ForegroundColor DarkGray
            } else {
                Write-Host "  [$key] $($menu[$key])"
            }
        }
        Write-Host ''
        $choice = Read-Host '  Enter choice'

        switch ($choice) {
            '1' { Invoke-Debloat }
            '2' { Invoke-WindowsFeatures }
            '3' { Install-CommonDevTools }
            '4' { Install-IDEs }
            '5' { Install-AutomationTools }
            '6' { Install-AITools }
            '7' { Install-TerminalTools }
            '8' { Install-ProductivityTools }
            '9' {
                Write-Host "`n  Starting FULL developer machine setup ...`n" -ForegroundColor Magenta
                Invoke-Debloat
                Invoke-WindowsFeatures -All
                Install-CommonDevTools -All
                Install-IDEs -All
                Install-AutomationTools -All
                Install-AITools -All
                Install-TerminalTools -All
                Install-ProductivityTools -All
            }
            '0' { break }
            default { Write-Warn 'Invalid choice. Please try again.' }
        }

        if ($choice -ne '0') {
            Write-Host ''
            Read-Host '  Press ENTER to return to the main menu'
        }
    } while ($choice -ne '0')
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
Assert-Administrator
Assert-Winget
Show-MainMenu

Write-Host ''
Write-Host '  Setup complete. Some changes require a reboot to take effect.' -ForegroundColor Green
Write-Host ''
