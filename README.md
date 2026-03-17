# win11-setup-script

A PowerShell script that automates setting up a Windows 11 machine for software development.
It features an interactive menu so you can pick exactly what you need.

---

## Features

| Category | What it does |
|---|---|
| **Debloat** | Removes pre-installed bloatware (Xbox apps, Cortana, Bing, etc.), disables telemetry, advertising ID, location tracking, unnecessary services & scheduled tasks, and configures Explorer to show file extensions and hidden files. |
| **Windows Features** | Enables WSL 2, Hyper-V, Windows Sandbox, Developer Mode, and OpenSSH Client. |
| **Common Dev Tools** | Git, Node.js LTS, Python 3.12, Go, Rust, Java JDK 21, .NET SDK 8, Docker Desktop, PowerShell 7, fzf, bat, ripgrep, eza, jq, curl, make, CMake, LLVM, fnm, uv. |
| **IDEs & Code Editors** | VS Code, Visual Studio 2022 Community, IntelliJ IDEA, PyCharm, WebStorm, GoLand, Rider, DataGrip, Neovim, Vim, Emacs, Sublime Text 4, Notepad++, Cursor. |
| **Automation & DevOps** | Terraform, Packer, Vault, kubectl, Helm, yq, Ansible Lint, AWS CLI, Azure CLI, Google Cloud SDK, Pulumi, ArgoCD CLI, k9s, kubectx, GitHub CLI, GitLab CLI, JFrog CLI, Vagrant, Chocolatey. |
| **AI & ML Tools** | Ollama, LM Studio, Jan, Claude Desktop, Cursor, Hugging Face CLI, NVIDIA CUDA Toolkit, Python 3.12, uv, Node.js. |
| **Terminal & Shell** | Windows Terminal, Oh My Posh, Starship, WezTerm, Alacritty, Hyper, Gpg4win, chezmoi, btop, Neovim. |
| **Productivity** | Firefox, Chrome, Brave, Postman, Insomnia, Fiddler, Wireshark, PowerToys, 7-Zip, Notion, Slack, Discord, Zoom, DBeaver, TablePlus, Figma, VLC. |

---

## Requirements

- **Windows 11** (Windows 10 may work for most features)
- **PowerShell 7+** — required. Install it first if not already present:
  ```powershell
  winget install --id Microsoft.PowerShell --silent --accept-package-agreements
  ```
- **Administrator privileges** — right-click "PowerShell 7" → "Run as administrator"
- **winget** (App Installer) — ships with Windows 11 by default.  
  If missing, install from the [Microsoft Store](https://apps.microsoft.com/detail/9nblggh4nns1) or via [aka.ms/getwinget](https://aka.ms/getwinget).

---

## Quick Start

Open **PowerShell 7 as Administrator** and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\Setup-Windows11Dev.ps1
```

You will be presented with an interactive main menu:

```
  Main Menu
  ---------
  [1] Debloat Windows 11 (remove bloatware, disable telemetry)
  [2] Windows Features  (WSL2, Hyper-V, Sandbox, Developer Mode)
  [3] Common Developer Tools  (Git, Node, Python, Go, Rust, Docker ...)
  [4] IDEs & Code Editors  (VS Code, VS 2022, JetBrains, Neovim ...)
  [5] Automation & DevOps Tools  (Terraform, kubectl, AWS/Azure CLI ...)
  [6] AI & Machine Learning Tools  (Ollama, LM Studio, CUDA ...)
  [7] Terminal & Shell Enhancements  (Windows Terminal, Oh My Posh ...)
  [8] Productivity & Utilities  (browsers, Postman, PowerToys, 7-Zip ...)
  [9] Run EVERYTHING (full developer machine setup)
  [0] Exit
```

Within each software category you can select individual packages or install the whole pack at once.

---

## Run from the web (one-liner)

> ⚠️ **Security Note:** Running scripts directly from the internet without reviewing them first is a security risk.
> Always inspect the script at the URL below before executing it.

```powershell
# Recommended: download first, review, then run
Invoke-WebRequest -Uri https://raw.githubusercontent.com/JJKW1984/win11-setup-script/main/Setup-Windows11Dev.ps1 -OutFile .\Setup-Windows11Dev.ps1
# Review the file, then:
Set-ExecutionPolicy Bypass -Scope Process -Force
.\Setup-Windows11Dev.ps1
```

> **Note:** Some features (WSL 2, Hyper-V, Windows Sandbox) require a **reboot** to take effect.

---

## File Structure

```
win11-setup-script/
└── Setup-Windows11Dev.ps1   # Main setup script
```

---

## Notes

- All software is installed via **winget**, the official Windows Package Manager.
- If a package is already installed, winget will skip it silently.
- Registry changes take effect immediately but some (Explorer settings) may require re-logging in.
- The debloat section only removes Microsoft-provided bloatware and does **not** touch user data.

---

## Contributing

Pull requests are welcome! To add a package, add an entry to the relevant `$packages` ordered hashtable inside the corresponding `Install-*` function.

---

## License

MIT