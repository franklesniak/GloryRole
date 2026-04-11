# Getting Started: Creating a New Repository from This Template

This guide walks you through creating a brand-new repository using `franklesniak/copilot-repo-template`. It is designed for beginners who may not be familiar with Git, Python, Node.js, or pre-commit. If you are looking to merge this template into an existing repository, refer to the README.md instead.

**Estimated time to complete:** 30-60 minutes (depending on your system and internet speed)

---

## Table of Contents

- [What This Template Provides](#what-this-template-provides)
  - [Repo Layout Examples](#repo-layout-examples)
- [Prerequisites](#prerequisites)
  - [Windows Setup](#windows-setup)
  - [macOS Setup](#macos-setup)
  - [Linux/FreeBSD Setup](#linuxfreebsd-setup)
- [Creating Your Repository on GitHub](#creating-your-repository-on-github)
- [Cloning Your New Repository](#cloning-your-new-repository)
- [Installing Dependencies](#installing-dependencies)
- [Initial Placeholder Replacement](#initial-placeholder-replacement)
- [Creating Optional Labels](#creating-optional-labels)
- [Installing and Configuring Pre-commit](#installing-and-configuring-pre-commit)
- [Language-Specific Customization](#language-specific-customization)
- [Updating package.json Metadata](#updating-packagejson-metadata)
- [Customizing the Pull Request Template](#customizing-the-pull-request-template)
- [Updating README.md](#updating-readmemd)
- [Customizing CONTRIBUTING.md](#customizing-contributingmd)
- [Customizing CODE_OF_CONDUCT.md](#customizing-code_of_conductmd)
- [Updating Copilot Instructions](#updating-copilot-instructions)
- [Additional Configuration (Optional)](#additional-configuration-optional)
- [Validation and Testing](#validation-and-testing)
- [Cleanup](#cleanup)
- [Troubleshooting](#troubleshooting)
- [Development Workflow](#development-workflow)
- [Next Steps](#next-steps)

---

## What This Template Provides

This template repository includes:

- **GitHub Copilot Instructions:** Comprehensive coding standards that guide AI-assisted development
- **Language-Specific Guidelines:** Modular instruction files for Markdown, PowerShell, Python, and Terraform
- **Linting Configurations:** Pre-configured settings for markdownlint and PSScriptAnalyzer
- **Pre-commit Hooks:** Automated code quality checks before commits
- **Issue Templates:** Structured templates for bug reports, feature requests, and documentation issues
- **Pull Request Template:** Checklist-based template for consistent PR reviews
- **CI Workflows:** GitHub Actions workflows for linting, testing, and validation
- **Multi-Agent Support:** Instruction files for Claude Code, OpenAI Codex CLI, and Gemini Code Assist

### Repo Layout Examples

Depending on your project's needs, you may organize your repository in different ways. Here are two common patterns:

**Root-Only Repo (Single Configuration):**

A repository with a single Terraform or application configuration:

```text
my-project/
├── .github/
│   ├── copilot-instructions.md
│   ├── instructions/
│   └── workflows/
├── main.tf              # Primary configuration
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── versions.tf          # Provider version constraints
├── .terraform.lock.hcl  # Dependency lock file
└── README.md
```

**Module-Based Repo:**

A repository containing reusable modules with examples and tests:

```text
my-modules/
├── .github/
│   ├── copilot-instructions.md
│   ├── instructions/
│   └── workflows/
├── modules/
│   └── vpc/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── README.md
├── examples/
│   └── basic-vpc/
│       ├── main.tf
│       └── README.md
├── tests/
│   └── vpc.tftest.hcl
└── README.md
```

Choose the structure that best fits your project when customizing the template.

---

## Prerequisites

Before you can use this template, you need to install several tools on your computer. Follow the instructions for your operating system below.

### Windows Setup

#### 1. Install Git for Windows

Git is the version control system used to track changes in your code.

1. Download Git for Windows from [https://git-scm.com/download/win](https://git-scm.com/download/win)
2. Run the installer and use these recommended settings:
   - **Select Components:** Keep defaults, ensure "Git Bash Here" is checked
   - **Default editor:** Choose your preferred editor (VS Code recommended if installed)
   - **Initial branch name:** Select "Let Git decide" (uses `master`) or "Override" and type `main`
   - **PATH environment:** Select "Git from the command line and also from 3rd-party software"
   - **SSH executable:** Select "Use bundled OpenSSH"
   - **HTTPS transport backend:** Select "Use the native Windows Secure Channel library"
   - **Line ending conversions:** Select "Checkout Windows-style, commit Unix-style line endings" (recommended)
   - **Terminal emulator:** Select "Use MinTTY"
   - **Default behavior of `git pull`:** Select "Fast-forward or merge"
   - **Credential helper:** Select "Git Credential Manager"
   - **Extra options:** Keep defaults
3. Click **Install** and wait for completion

#### 2. Install Python

Python is required for pre-commit hooks and Python-based linting tools.

1. Download Python from [https://www.python.org/downloads/](https://www.python.org/downloads/)
2. Run the installer
   - **IMPORTANT:** Check the box that says "Add Python to PATH" before clicking Install
   - Click "Install Now" for the default installation

> **Warning:** If you forget to check "Add Python to PATH," you will need to uninstall and reinstall Python, or manually add Python to your PATH environment variable.

#### 3. Install Node.js

Node.js is required for markdown linting scripts.

1. Download the LTS (Long Term Support) version from [https://nodejs.org/](https://nodejs.org/)
2. Run the installer and accept the defaults
3. When prompted about "Automatically install the necessary tools," you can uncheck this option (not required for this template)

#### 4. Verify Your Installations

Open **PowerShell** (search for "PowerShell" in the Start menu) and run these commands:

```powershell
# Check Git version
git --version

# Check Python version
python --version

# Check pip version
python -m pip --version

# Check Node.js version
node --version

# Check npm version (comes with Node.js)
npm --version
```

You should see version numbers for each command. If any command shows an error, revisit the installation steps for that tool.

**Example output:**

```text
git version 2.43.0.windows.1
Python 3.12.1
pip 23.3.2 from C:\Users\YourName\AppData\Local\Programs\Python\Python312\Lib\site-packages\pip (python 3.12)
v20.10.0
10.2.3
```

---

### macOS Setup

#### 1. Install Xcode Command Line Tools

The Xcode Command Line Tools provide essential developer tools including Git.

1. Open **Terminal** (press Cmd+Space, type "Terminal," and press Enter)
2. Run the following command:

   ```bash
   xcode-select --install
   ```

3. A dialog will appear asking you to install the tools. Click **Install** and wait for completion.

> **Note:** This may take several minutes depending on your internet connection.

#### 2. Install Homebrew (Recommended)

Homebrew is a package manager that makes it easy to install and manage software on macOS. While optional, it simplifies installation of Python and Node.js.

1. Open Terminal and run:

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. Follow the on-screen instructions. You may be prompted to enter your password.
3. After installation, follow the instructions shown to add Homebrew to your PATH (the installer will display the exact commands).

#### 3. Install Python

**Option A: Using Homebrew (recommended if you installed Homebrew):**

```bash
brew install python
```

**Option B: Using the official installer:**

1. Download Python from [https://www.python.org/downloads/](https://www.python.org/downloads/)
2. Run the installer package
3. Follow the prompts to complete installation

#### 4. Install Node.js

**Option A: Using Homebrew (recommended):**

```bash
brew install node
```

**Option B: Using the official installer:**

1. Download the LTS version from [https://nodejs.org/](https://nodejs.org/)
2. Run the installer package
3. Follow the prompts to complete installation

#### 5. Verify Your Installations

Open **Terminal** and run these commands:

```bash
# Check Git version
git --version

# Check Python version
python3 --version

# Check pip version
pip3 --version

# Check Node.js version
node --version

# Check npm version
npm --version
```

You should see version numbers for each command.

**Example output:**

```text
git version 2.39.3 (Apple Git-145)
Python 3.12.1
pip 23.3.2 from /opt/homebrew/lib/python3.12/site-packages/pip (python 3.12)
v20.10.0
10.2.3
```

> **Note:** On macOS, use `python3` instead of `python` to ensure you're using Python 3.

---

### Linux/FreeBSD Setup

The commands below vary depending on your Linux distribution. Find your distribution and follow the appropriate instructions.

#### Ubuntu/Debian

```bash
# Update package lists
sudo apt update

# Install Git
sudo apt install git

# Install Python 3 and pip
sudo apt install python3 python3-pip python3-venv

# Install Node.js (using NodeSource for LTS version)
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install nodejs
```

#### Fedora/RHEL/CentOS

```bash
# Install Git
sudo dnf install git

# Install Python 3 and pip
sudo dnf install python3 python3-pip

# Install Node.js
sudo dnf install nodejs npm
```

#### Arch Linux

```bash
# Install Git
sudo pacman -S git

# Install Python 3 and pip
sudo pacman -S python python-pip

# Install Node.js and npm
sudo pacman -S nodejs npm
```

#### FreeBSD

```bash
# Install Git
sudo pkg install git

# Install Python 3 and pip
sudo pkg install python3 py39-pip

# Install Node.js and npm
sudo pkg install node npm
```

#### Alternative: Using nvm for Node.js

If you prefer to manage multiple Node.js versions, you can use nvm (Node Version Manager):

```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Restart your terminal or run:
source ~/.bashrc  # or ~/.zshrc if using zsh

# Install the latest LTS version of Node.js
nvm install --lts

# Verify installation
node --version
npm --version
```

#### Verify Your Installations

Open a terminal and run these commands:

```bash
# Check Git version
git --version

# Check Python version
python3 --version

# Check pip version
pip3 --version

# Check Node.js version
node --version

# Check npm version
npm --version
```

You should see version numbers for each command.

---

## Creating Your Repository on GitHub

Now that you have all the prerequisites installed, you can create your new repository from this template.

### Step 1: Navigate to the Template Repository

1. Open your web browser and go to [https://github.com/franklesniak/copilot-repo-template](https://github.com/franklesniak/copilot-repo-template)

### Step 2: Create a New Repository from the Template

1. Click the green **"Use this template"** button near the top of the page
2. Select **"Create a new repository"** from the dropdown menu

### Step 3: Configure Your New Repository

On the "Create a new repository" page:

1. **Owner:** Select your GitHub username or an organization you belong to
2. **Repository name:** Enter a name for your new repository (e.g., `my-new-project`)
3. **Description (optional):** Enter a brief description of your project
4. **Visibility:**
   - **Public:** Anyone can see your repository
   - **Private:** Only you and people you invite can see your repository
5. **Include all branches:** Leave this **unchecked** unless you have a specific reason to include other branches. Most users only need the default branch.

### Step 4: Create the Repository

1. Click the green **"Create repository"** button
2. Wait a few seconds for GitHub to create your repository

You will be redirected to your new repository's page. The URL will be something like `https://github.com/YOUR-USERNAME/your-repo-name`.

---

## Cloning Your New Repository

Now you need to download (clone) your new repository to your local computer.

### Understanding SSH vs. HTTPS

There are two main ways to connect to GitHub:

- **HTTPS:** Easier to set up. You authenticate with your GitHub username and a personal access token (or GitHub CLI).
- **SSH:** More secure and convenient for frequent use. Requires setting up SSH keys once.

For beginners, we recommend **HTTPS** because it's simpler to get started. Advanced users may prefer SSH.

### Windows: Cloning with Git Bash or PowerShell

1. Open **Git Bash** (right-click on your desktop or in a folder and select "Git Bash Here") or **PowerShell**
2. Navigate to the folder where you want to store your project:

   ```powershell
   # Example: Navigate to your Documents folder
   cd ~/Documents
   ```

3. Clone your repository (replace `YOUR-USERNAME` and `your-repo-name` with your actual values):

   **Using HTTPS:**

   ```powershell
   git clone https://github.com/YOUR-USERNAME/your-repo-name.git
   ```

   **Using SSH (if you've set up SSH keys):**

   ```powershell
   git clone git@github.com:YOUR-USERNAME/your-repo-name.git
   ```

4. Navigate into your cloned repository:

   ```powershell
   cd your-repo-name
   ```

### macOS/Linux/FreeBSD: Cloning with Terminal

1. Open **Terminal**
2. Navigate to the folder where you want to store your project:

   ```bash
   # Example: Navigate to your home directory's projects folder
   cd ~/projects
   # Or create one if it doesn't exist:
   mkdir -p ~/projects && cd ~/projects
   ```

3. Clone your repository (replace `YOUR-USERNAME` and `your-repo-name` with your actual values):

   **Using HTTPS:**

   ```bash
   git clone https://github.com/YOUR-USERNAME/your-repo-name.git
   ```

   **Using SSH (if you've set up SSH keys):**

   ```bash
   git clone git@github.com:YOUR-USERNAME/your-repo-name.git
   ```

4. Navigate into your cloned repository:

   ```bash
   cd your-repo-name
   ```

> **Tip:** If you haven't set up SSH keys and want to use SSH, see [GitHub's SSH key documentation](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account).

---

## Installing Dependencies

After cloning, you need to install the project dependencies.

### Step 1: Navigate to Your Repository Directory

Make sure you're in your repository's root directory. You should see files like `package.json`, `README.md`, and the `.github` folder.

**Windows (PowerShell):**

```powershell
# If you're not already there:
cd C:\path\to\your-repo-name

# Verify you're in the right place by listing files:
dir
```

**macOS/Linux/FreeBSD (Terminal):**

```bash
# If you're not already there:
cd ~/projects/your-repo-name

# Verify you're in the right place by listing files:
ls -la
```

### Step 2: Install Node.js Dependencies

Run the following command to install the Node.js dependencies defined in `package.json`:

**All platforms:**

```bash
npm install
```

This command:

- Reads the `package.json` file to determine which packages are needed
- Downloads and installs those packages into a `node_modules` folder
- Creates or updates `package-lock.json` to lock dependency versions

**What gets installed:** The Node.js dependencies are primarily for **markdown linting** (markdownlint-cli2). This ensures your documentation follows consistent formatting rules.

> **Note:** The `node_modules` folder is automatically excluded from Git (via `.gitignore`), so these files won't be committed to your repository.
>
> **Tip:** The repository also includes an optional nested markdown linting script that checks Markdown code blocks within your documentation. See [Nested Markdown Linting Configuration](OPTIONAL_CONFIGURATIONS.md#nested-markdown-linting-configuration) in the optional configurations guide for details.

---

## Initial Placeholder Replacement

This template uses placeholder values that you **must** replace with your actual repository information. The CI workflow (`check-placeholders.yml`) will fail until you complete these replacements.

### Files That Need Placeholders Replaced

| File | Placeholders to Replace |
| --- | --- |
| `.github/ISSUE_TEMPLATE/config.yml` | `OWNER/REPO` (appears in URLs twice) |
| `.github/CODEOWNERS` | `@OWNER` (appears four times) |
| `CODE_OF_CONDUCT.md` | `[INSERT CONTACT METHOD]` (enforcement contact for code of conduct violations) |
| `CONTRIBUTING.md` | `OWNER/REPO` (appears in clone URL and issues URL) |
| `LICENSE` | `Frank Lesniak` (copyright holder name — replace with your name or organization) |
| `SECURITY.md` | `[security contact email]` |
| `.vscode/settings.json` | `window.title` value (replace with your repository name) |

### What the Placeholders Mean

- **`OWNER`:** Your GitHub username or organization name (e.g., `franklesniak`)
- **`REPO`:** Your repository name (e.g., `my-new-project`)
- **`OWNER/REPO`:** Combined format used in GitHub URLs (e.g., `franklesniak/my-new-project`)
- **`@OWNER`:** GitHub username with @ prefix for CODEOWNERS file (e.g., `@franklesniak`)
- **`Frank Lesniak`:** The template author's name in the LICENSE file. Replace with your name or organization name (the copyright holder for your project).
- **`[INSERT CONTACT METHOD]`:** A method for reporting code of conduct violations (e.g., an email address, a form URL, or instructions to contact maintainers). This should be actively monitored and capable of receiving sensitive reports.
- **`[security contact email]`:** An email address for receiving security vulnerability reports
- **`window.title` in `.vscode/settings.json`:** The VS Code window title that appears in the title bar when working in this repository. Replace the instruction text with your repository name for easy identification.

### Option A: Find and Replace Commands

#### Windows (PowerShell)

Open PowerShell in your repository directory and run these commands. Replace the placeholder values with your actual information:

```powershell
# Define your values (replace these with your actual username/org, repo name, and email)
$Owner = "your-username"
$Repo = "your-repo-name"
$SecurityEmail = "security@example.com"

# Replace OWNER/REPO in config.yml
(Get-Content ".github/ISSUE_TEMPLATE/config.yml" -Raw -Encoding UTF8).Replace('OWNER/REPO', "$Owner/$Repo") | Set-Content ".github/ISSUE_TEMPLATE/config.yml" -Encoding UTF8

# Replace OWNER/REPO in CONTRIBUTING.md
(Get-Content "CONTRIBUTING.md" -Raw -Encoding UTF8).Replace('OWNER/REPO', "$Owner/$Repo") | Set-Content "CONTRIBUTING.md" -Encoding UTF8

# Replace @OWNER in CODEOWNERS (note the @ prefix)
(Get-Content ".github/CODEOWNERS" -Raw -Encoding UTF8).Replace('@OWNER', "@$Owner") | Set-Content ".github/CODEOWNERS" -Encoding UTF8

# Replace contact method placeholder in CODE_OF_CONDUCT.md (uses security email; change if different contact preferred)
(Get-Content "CODE_OF_CONDUCT.md" -Raw -Encoding UTF8).Replace('[INSERT CONTACT METHOD]', $SecurityEmail) | Set-Content "CODE_OF_CONDUCT.md" -Encoding UTF8

# Replace security email placeholder in SECURITY.md
(Get-Content "SECURITY.md" -Raw -Encoding UTF8).Replace('[security contact email]', $SecurityEmail) | Set-Content "SECURITY.md" -Encoding UTF8

# Replace window.title placeholder in VS Code settings
(Get-Content ".vscode\settings.json" -Raw -Encoding UTF8).Replace('Go to .vscode/settings.json and make this the name of the repo', $Repo) | Set-Content ".vscode\settings.json" -Encoding UTF8
```

#### macOS/Linux/FreeBSD (Bash)

Open Terminal in your repository directory and run the commands below. Replace the placeholder values with your actual information.

> **Note:** The `LICENSE` file contains the template author's name (`Frank Lesniak`) in the copyright notice. This is not a pattern-based placeholder, so you'll need to manually update it with your own name or organization. Optionally update the copyright year to the current year or your project's start year.

**Step 1: Define your values** (all platforms):

```bash
# Define your values (replace these with your actual username/org, repo name, and email)
OWNER="your-username"
REPO="your-repo-name"
SECURITY_EMAIL="security@example.com"
```

**Step 2: Run the replacement commands** for your platform:

##### Linux (GNU sed)

```bash
# Replace OWNER/REPO in config.yml
sed -i "s|OWNER/REPO|$OWNER/$REPO|g" .github/ISSUE_TEMPLATE/config.yml

# Replace OWNER/REPO in CONTRIBUTING.md
sed -i "s|OWNER/REPO|$OWNER/$REPO|g" CONTRIBUTING.md

# Replace @OWNER in CODEOWNERS
sed -i "s|@OWNER|@$OWNER|g" .github/CODEOWNERS

# Replace contact method placeholder in CODE_OF_CONDUCT.md
sed -i "s|\[INSERT CONTACT METHOD\]|$SECURITY_EMAIL|g" CODE_OF_CONDUCT.md

# Replace security email placeholder in SECURITY.md
sed -i "s|\[security contact email\]|$SECURITY_EMAIL|g" SECURITY.md

# Replace window.title placeholder in VS Code settings
sed -i 's|Go to \.vscode/settings\.json and make this the name of the repo|'"$REPO"'|g' .vscode/settings.json
```

##### macOS / FreeBSD (BSD sed)

```bash
# Replace OWNER/REPO in config.yml
sed -i '' "s|OWNER/REPO|$OWNER/$REPO|g" .github/ISSUE_TEMPLATE/config.yml

# Replace OWNER/REPO in CONTRIBUTING.md
sed -i '' "s|OWNER/REPO|$OWNER/$REPO|g" CONTRIBUTING.md

# Replace @OWNER in CODEOWNERS
sed -i '' "s|@OWNER|@$OWNER|g" .github/CODEOWNERS

# Replace contact method placeholder in CODE_OF_CONDUCT.md
sed -i '' "s|\[INSERT CONTACT METHOD\]|$SECURITY_EMAIL|g" CODE_OF_CONDUCT.md

# Replace security email placeholder in SECURITY.md
sed -i '' "s|\[security contact email\]|$SECURITY_EMAIL|g" SECURITY.md

# Replace window.title placeholder in VS Code settings
sed -i '' 's|Go to \.vscode/settings\.json and make this the name of the repo|'"$REPO"'|g' .vscode/settings.json
```

##### Windows (Git Bash or WSL)

If using **Git Bash**, use the Linux (GNU sed) commands above. If using **WSL (Windows Subsystem for Linux)**, use the Linux commands. Alternatively, use the PowerShell commands in the previous section.

> **Note on special characters:** If your email or contact method contains special `sed` characters (`&`, `\`, or `|`), escape them with a backslash or use the PowerShell commands instead, which handle special characters more reliably.

### Option B: Manual Replacement

If you prefer, you can open each file in a text editor and manually find and replace the placeholders:

1. **`.github/ISSUE_TEMPLATE/config.yml`:**
   - Find: `OWNER/REPO`
   - Replace with: `your-username/your-repo-name` (appears in two URLs)

2. **`.github/CODEOWNERS`:**
   - Find: `@OWNER`
   - Replace with: `@your-username` (appears four times)

3. **`CODE_OF_CONDUCT.md`:**
   - Find: `[INSERT CONTACT METHOD]`
   - Replace with: your contact method for code of conduct reports (e.g., email address)

4. **`CONTRIBUTING.md`:**
   - Find: `OWNER/REPO`
   - Replace with: `your-username/your-repo-name` (appears in clone URL and issues link)

5. **`SECURITY.md`:**
   - Find: `[security contact email]`
   - Replace with: your actual security contact email address

6. **`.vscode/settings.json`:**
   - Find: `Go to .vscode/settings.json and make this the name of the repo`
   - Replace with: your repository name (e.g., `my-awesome-project`)

7. **`LICENSE`:**
   - Find: `Frank Lesniak`
   - Replace with: your name or organization name (the copyright holder)
   - Optionally update the copyright year to the current year or your project's start year

### Understanding the CODEOWNERS File

The `.github/CODEOWNERS` file defines who is automatically requested to review pull requests. The `@OWNER` placeholder should be replaced with:

- Your GitHub username (e.g., `@octocat`) for personal repositories
- A team reference (e.g., `@my-org/maintainers`) for organization repositories

For example, if your GitHub username is `janedoe`, replace `@OWNER` with `@janedoe`.

### Understanding the Security Email Placeholder

The `[security contact email]` placeholder in `SECURITY.md` should be replaced with an email address that:

- Is actively monitored
- Can receive sensitive security reports
- Is not publicly visible (unlike GitHub issues)

If you prefer not to use email, you can:

1. Remove the email section entirely from `SECURITY.md`
2. Keep only the GitHub Security Advisories option (see [OPTIONAL_CONFIGURATIONS.md](OPTIONAL_CONFIGURATIONS.md) for details)

---

## Creating Optional Labels

The issue templates include labels that should exist in your repository.

**Default GitHub labels (already exist in new repositories):**

- `bug` — Used by bug_report.yml
- `enhancement` — Used by feature_request.yml
- `documentation` — Used by documentation_issue.yml

**Optional label to create:**

The templates include a commented-out `triage` label. To use it:

**Using GitHub CLI (Windows PowerShell / macOS / Linux):**

```bash
gh label create triage --description "Needs triage" --color "d4c5f9"
```

**Or via GitHub web UI:**

1. Go to your repository
2. Click **Issues** or **Pull requests**
3. Above the list, click **Labels**
4. Click **New label**
5. Under "Label name", type `triage`
6. Under "Description", type `Needs triage`
7. Edit the color hexadecimal number to `d4c5f9` (light purple)
8. Click **Create label**

After creating the label, uncomment the `- triage` line in each issue template (`bug_report.yml`, `feature_request.yml`, and `documentation_issue.yml`).

---

## Installing and Configuring Pre-commit

### Understanding Pre-commit

[Pre-commit](https://pre-commit.com/) is a framework for managing git hooks. It automatically runs code quality checks (formatting, linting, validation) before each commit, catching issues early and ensuring consistent code quality across your team.

**Why pre-commit is not a project dependency:**

- Pre-commit is a **development tool**, not a runtime or test dependency
- It manages its own isolated environments for each hook (e.g., Black, Ruff)
- Installing it globally or via `pipx` keeps your project dependencies clean
- This is standard practice in the Python community
- CI workflows install pre-commit separately

> **Why pipx is recommended:**
>
> When you install Python packages with CLI tools using `pip`, the executables are placed in a `Scripts` folder (Windows) or `bin` folder (macOS/Linux) that may not be in your system PATH. This can cause "command not found" errors.
>
> `pipx` addresses this by installing Python CLI tools in isolated environments and exposing their executables from a single, well-defined binary directory. To make that directory available on the command line, you must run `pipx ensurepath` once (and restart your shell); after that, new tools installed with `pipx` will typically be usable without additional PATH changes. This is the [official recommendation from the pre-commit project](https://pre-commit.com/#install).
>
> If the `pipx` command itself is not yet on your PATH (for example, just after installation on Windows), you can invoke it via the Python module instead, such as `python -m pipx ensurepath` on Windows or `python3 -m pipx ensurepath` on macOS/Linux/FreeBSD for the initial setup.
>
> If you prefer to use `pip`, you can invoke pre-commit as a Python module using `python -m pre_commit` (Windows) or `python3 -m pre_commit` (macOS/Linux/FreeBSD) instead of the `pre-commit` command directly.

### Installation - Windows

#### Option 1: Using pipx (recommended)

[pipx](https://pipx.pypa.io/) installs Python applications in isolated environments and, after you run `pipx ensurepath` once, adds the pipx binaries directory to your PATH so you can run installed tools from the command line. First install pipx if you don't have it:

```powershell
# First, upgrade pip to the latest version (recommended)
python -m pip install --upgrade pip

# Install pipx
python -m pip install pipx

# Configure PATH (use module invocation in case pipx isn't on PATH yet)
python -m pipx ensurepath
```

Then install pre-commit:

```powershell
# Use module invocation to ensure it works even if pipx isn't on PATH
python -m pipx install pre-commit
```

> **Note:** You need to restart your PowerShell window (or open a new one) before running `pre-commit` directly by name, because PATH changes only apply to new shells. Using `python -m pipx` avoids needing `pipx` on PATH and lets you install packages in the same session, but `pipx run pre-commit` runs from a temporary environment and should not be used for `pre-commit install` (it can create hooks that reference a non-existent interpreter).

#### Option 2: Using pip

Open PowerShell and run:

```powershell
# First, upgrade pip to the latest version (recommended)
python -m pip install --upgrade pip

# Then install pre-commit
python -m pip install pre-commit
```

> **Note:** When using pip, the `pre-commit` command may not be recognized because Python's `Scripts` folder is not always added to PATH. Use `python -m pre_commit` instead of `pre-commit` for all commands. For example, use `python -m pre_commit --version` to verify installation.
>
> **Troubleshooting:** If you see `pip: The term 'pip' is not recognized`, ensure you checked "Add Python to PATH" during Python installation. Using `python -m pip` instead of `pip` directly is more reliable on Windows.

#### Verifying installation

**If you installed with pipx:**

```powershell
pre-commit --version
```

> **Note:** If `pre-commit` is not found, you need to restart your PowerShell window so the PATH changes from `pipx ensurepath` take effect. Alternatively, you can verify pipx installed pre-commit by running `python -m pipx list` to see installed packages.

**If you installed with pip:**

```powershell
python -m pre_commit --version
```

You should see output like `pre-commit 4.0.1`.

### Installation - macOS/Linux/FreeBSD

#### Option 1: Using pipx (recommended)

[pipx](https://pipx.pypa.io/) installs Python applications in isolated environments and, after you run `pipx ensurepath` once, adds the pipx binaries directory to your PATH so you can run installed tools from the command line.

> **Important (PEP 668 systems):** On newer Linux distributions (Ubuntu 23.04+, Fedora 38+) and some macOS configurations, `python3 -m pip install` commands fail with an `externally-managed-environment` error. If you're on one of these systems, **skip the pip commands below** and install pipx via your OS package manager instead:
>
> - Debian / Ubuntu: `sudo apt install pipx && pipx ensurepath`
> - Fedora: `sudo dnf install pipx && pipx ensurepath`
> - macOS (Homebrew): `brew install pipx && pipx ensurepath`
>
> After running `pipx ensurepath`, restart your terminal, then proceed to the "Then install pre-commit" step below.

If pip works on your system, first install pipx:

```bash
# First, upgrade pip to the latest version (recommended)
python3 -m pip install --upgrade pip

# Install pipx
python3 -m pip install pipx

# Configure PATH (use module invocation in case pipx isn't on PATH yet)
python3 -m pipx ensurepath
```

Then install pre-commit:

```bash
pipx install pre-commit
```

> **Note:** If you installed pipx via an OS package manager (Homebrew, apt, dnf), use `pipx install pre-commit` as shown above. If you installed pipx via pip and pipx isn't on your PATH yet, you can use `python3 -m pipx install pre-commit` instead. After installing pre-commit, you'll need to restart your terminal before running `pre-commit` directly by name. Do not use `pipx run pre-commit install`—it runs from a temporary environment and can create hooks referencing a non-existent interpreter.

#### Option 2: Using Homebrew (macOS only)

```bash
brew install pre-commit
```

#### Option 3: Using pip

> **Important (PEP 668 systems):** On newer Linux distributions (Ubuntu 23.04+, Fedora 38+) and some macOS configurations, `python3 -m pip install` commands fail with an `externally-managed-environment` error. If you're on one of these systems, **do not use pip**—use Option 1 (pipx via OS package manager) instead:
>
> - Debian / Ubuntu: `sudo apt install pipx && pipx ensurepath`
> - Fedora: `sudo dnf install pipx && pipx ensurepath`
> - macOS (Homebrew): `brew install pipx && pipx ensurepath`
>
> After running `pipx ensurepath`, restart your terminal, then run `pipx install pre-commit`.

If pip works on your system:

```bash
# First, upgrade pip to the latest version (recommended)
python3 -m pip install --upgrade pip

# Then install pre-commit
python3 -m pip install pre-commit
```

> **Note:** When using pip, the `pre-commit` command may not be recognized if Python's `bin` folder is not in your PATH. Use `python3 -m pre_commit` instead of `pre-commit` for all commands. For example, use `python3 -m pre_commit --version` to verify installation.

#### Verifying installation

**If you installed with pipx:**

```bash
pre-commit --version
```

> **Note:** If `pre-commit` is not found, you need to restart your terminal so the PATH changes from `pipx ensurepath` take effect. Alternatively, you can verify pipx installed pre-commit by running `python3 -m pipx list` to see installed packages.

**If you installed with Homebrew:**

```bash
pre-commit --version
```

> **Note:** If `pre-commit` is not found, ensure Homebrew's `bin` directory (typically `/opt/homebrew/bin` on Apple Silicon or `/usr/local/bin` on Intel Macs) is in your PATH. You can add it by running `eval "$(/opt/homebrew/bin/brew shellenv)"` (Apple Silicon) or `eval "$(/usr/local/bin/brew shellenv)"` (Intel) in your shell configuration file.

**If you installed with pip:**

```bash
python3 -m pre_commit --version
```

You should see output like `pre-commit 4.0.1`.

### Activating Hooks in Your Repository

Navigate to your repository directory and run:

**Windows (PowerShell):**

**If you installed with pipx:**

```powershell
cd C:\path\to\your-repo-name
pre-commit install
```

> **Note:** If `pre-commit` is not found, run `python -m pipx ensurepath` and restart your PowerShell window. Do not use `pipx run pre-commit install` because it runs from a temporary environment and can create hooks that reference a non-existent interpreter.

**If you installed with pip:**

```powershell
cd C:\path\to\your-repo-name
python -m pre_commit install
```

**macOS/Linux/FreeBSD:**

**If you installed with pipx:**

```bash
cd ~/projects/your-repo-name
pre-commit install
```

> **Note:** If `pre-commit` is not found, run `python3 -m pipx ensurepath` (or `pipx ensurepath` if `pipx` is already on your PATH) and restart your terminal. Do not use `pipx run pre-commit install` because it runs from a temporary environment and can create hooks that reference a non-existent interpreter.

**If you installed with Homebrew:**

```bash
cd ~/projects/your-repo-name
pre-commit install
```

> **Note:** If `pre-commit` is not found, ensure Homebrew's `bin` directory is in your PATH (see verification section above).

**If you installed with pip:**

```bash
cd ~/projects/your-repo-name
python3 -m pre_commit install
```

This command modifies `.git/hooks/pre-commit` to run pre-commit automatically before each commit. You only need to run this once per repository clone.

**What happens:** Git will now automatically run all configured hooks every time you run `git commit`. If any hook fails, the commit is blocked until you fix the issues.

### Running Pre-commit Manually

Run pre-commit on all files:

**If you installed with pipx:**

```bash
pre-commit run --all-files
```

> **Note:** If `pre-commit` is not found, you may need to add the pipx binary location to your PATH. On **Windows**, run `python -m pipx ensurepath`. On **macOS/Linux/FreeBSD**, run `python3 -m pipx ensurepath`. In both cases, you can alternatively run `pipx ensurepath` if `pipx` itself is already on your PATH, then restart your terminal. `pipx run pre-commit` can be used for one-off commands but runs from a temporary environment (slower and doesn't validate your installed version).

**If you installed with Homebrew:**

```bash
pre-commit run --all-files
```

**If you installed with pip (Windows):**

```powershell
python -m pre_commit run --all-files
```

**If you installed with pip (macOS/Linux/FreeBSD):**

```bash
python3 -m pre_commit run --all-files
```

**First run behavior:** The first time you run pre-commit, it downloads and installs the hook environments (e.g., Black, Ruff). This may take a minute or two. Subsequent runs are much faster.

**Interpreting output:**

```text
Trim Trailing Whitespace......................................Passed
Fix End of Files..............................................Passed
Check Yaml....................................................Passed
Check for added large files...................................Passed
black.........................................................Passed
ruff..........................................................Passed
markdownlint-cli2.............................................Passed
```

- **Passed:** The check found no issues
- **Failed:** The check found issues (some hooks auto-fix, others require manual fixes)
- **Skipped:** The hook didn't apply to any files in this commit

> **Tip:** If hooks auto-fix files (like trailing whitespace or formatting), review the changes and include them in your commit. Pre-commit will run again and should pass.

---

## Language-Specific Customization

This template includes support for Python, PowerShell, Terraform, and Markdown/documentation. You should remove support for languages you don't need and configure the ones you do use.

### Decision Point: Which Languages Do You Need?

Review your project requirements and decide which languages you'll be using:

- **Python:** Server-side code, scripts, data processing, APIs
- **PowerShell:** Windows automation, cross-platform scripting, DevOps tasks
- **Markdown:** Documentation (always needed)

### If Using Python

#### 1. Rename the Package Directory

The template includes an example Python package at `src/copilot_repo_template/`. Rename it to match your project name:

**Windows (PowerShell):**

```powershell
# Replace 'your_package_name' with your actual package name
# Use underscores, not hyphens (Python package naming convention)
Move-Item -Path "src\copilot_repo_template" -Destination "src\your_package_name"
```

**macOS/Linux/FreeBSD:**

```bash
# Replace 'your_package_name' with your actual package name
mv src/copilot_repo_template src/your_package_name
```

#### 2. Update pyproject.toml

Open `pyproject.toml` and update the following fields:

```toml
[project]
name = "your-project-name"  # Your project name (can use hyphens)
version = "0.1.0"
description = "Your project description"
authors = [
    { name = "Your Name" }
]
keywords = ["your", "keywords", "here"]

# Add your runtime dependencies
dependencies = [
    # "requests>=2.28.0",
    # "pydantic>=2.0.0",
]
```

#### 3. Update Test Imports

Open `tests/test_example.py` and update the import statements to match your package name:

```python
# Change from:
from copilot_repo_template.example import hello

# To:
from your_package_name.example import hello
```

#### 4. Replace Example Code with Your Project Code

The template includes example files demonstrating Python coding standards. Replace these with your actual project code:

1. **Replace the example module:**
   - Delete or replace `src/your_package_name/example.py` with your actual Python modules
   - The example file contains `greet()` and `add_numbers()` functions for demonstration only

2. **Update `__init__.py`:**
   - Update `src/your_package_name/__init__.py` with your package's docstring and any exports you need
   - Update the `__version__` variable if using versioning

3. **Replace example tests:**
   - Delete or replace `tests/test_example.py` with tests for your actual modules
   - Update the docstring in `tests/__init__.py` to reflect your project name (replace "copilot-repo-template" with your project's name)
   - Follow the pytest conventions demonstrated in the example test file

> **Tip:** The example files demonstrate the coding standards defined in `.github/instructions/python.instructions.md`. Review this file when writing your own code to ensure consistency.

#### 5. Verify Python Setup

Install the package in development mode and run tests:

**Windows (PowerShell):**

```powershell
python -m pip install -e ".[dev]"
pytest tests/ -v
```

**macOS/Linux/FreeBSD:**

```bash
pip3 install -e ".[dev]"
pytest tests/ -v
```

You should see output indicating tests passed. If you haven't yet replaced the example tests with your own, you'll see the template's example tests running.

### If NOT Using Python

Remove Python-related files and configurations:

**Windows (PowerShell):**

```powershell
# Remove Python package and test files
Remove-Item -Recurse -Force "src"
Remove-Item -Force "tests\test_example.py"
Remove-Item -Force "tests\__init__.py"
Remove-Item -Force "pyproject.toml"

# Remove Python CI workflow
Remove-Item -Force ".github\workflows\python-ci.yml"

# Remove Python instructions
Remove-Item -Force ".github\instructions\python.instructions.md"

# Remove Python templates
Remove-Item -Recurse -Force "templates\python"
```

**macOS/Linux/FreeBSD:**

```bash
# Remove Python package and test files
rm -rf src/
rm -f tests/test_example.py tests/__init__.py
rm -f pyproject.toml

# Remove Python CI workflow
rm -f .github/workflows/python-ci.yml

# Remove Python instructions
rm -f .github/instructions/python.instructions.md

# Remove Python templates
rm -rf templates/python/
```

#### Update Pre-commit Configuration

Edit `.pre-commit-config.yaml` to remove Python-specific hooks. Delete or comment out the Black and Ruff sections:

```yaml
# Remove or comment out these sections:
#  - repo: https://github.com/psf/black
#    rev: 26.1.0
#    hooks:
#      - id: black
#        args: [--line-length=100]
#
#  - repo: https://github.com/astral-sh/ruff-pre-commit
#    rev: v0.14.14
#    hooks:
#      - id: ruff-check
#        args: [--fix, --line-length=100]
```

#### Update Issue Templates

Edit `.github/ISSUE_TEMPLATE/bug_report.yml` and `.github/ISSUE_TEMPLATE/feature_request.yml` to remove "Python" from the Area dropdown options.

#### Update Pull Request Template

Edit `.github/pull_request_template.md` to remove the "Python-Specific (if applicable)" section.

### If Using PowerShell

#### 1. Review PSScriptAnalyzer Settings

The template includes PSScriptAnalyzer configuration at `.github/linting/PSScriptAnalyzerSettings.psd1`. This enforces the OTBS (One True Brace Style) formatting style.

Review the settings file to understand the rules being enforced. You can customize these settings based on your team's preferences.

#### 2. Add PowerShell Scripts

Add your PowerShell scripts to appropriate locations in your repository. The CI workflow will automatically lint any `.ps1` files.

#### 3. Run PSScriptAnalyzer Locally

**Install PSScriptAnalyzer (if not already installed):**

```powershell
Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
```

**Run linting on a script:**

```powershell
# Lint a single file
Invoke-ScriptAnalyzer -Path .\your-script.ps1 -Settings .\.github\linting\PSScriptAnalyzerSettings.psd1

# Auto-fix formatting issues
Invoke-ScriptAnalyzer -Path .\your-script.ps1 -Settings .\.github\linting\PSScriptAnalyzerSettings.psd1 -Fix
```

#### 4. Run Pester Tests

**Install Pester 5.x (if not already installed):**

```powershell
Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser
```

**Run tests:**

```powershell
Invoke-Pester -Path tests/ -Output Detailed
```

### If NOT Using PowerShell

Remove PowerShell-related files and configurations:

**Windows (PowerShell):**

```powershell
# Remove PowerShell CI workflow
Remove-Item -Force ".github\workflows\powershell-ci.yml"

# Remove PowerShell instructions
Remove-Item -Force ".github\instructions\powershell.instructions.md"

# Remove linting configuration
Remove-Item -Recurse -Force ".github\linting"

# Remove PowerShell tests
Remove-Item -Recurse -Force "tests\PowerShell"

# Remove PowerShell templates
Remove-Item -Recurse -Force "templates\powershell"
```

**macOS/Linux/FreeBSD:**

```bash
# Remove PowerShell CI workflow
rm -f .github/workflows/powershell-ci.yml

# Remove PowerShell instructions
rm -f .github/instructions/powershell.instructions.md

# Remove linting configuration
rm -rf .github/linting/

# Remove PowerShell tests
rm -rf tests/PowerShell/

# Remove PowerShell templates
rm -rf templates/powershell/
```

#### Update Issue Templates

Edit `.github/ISSUE_TEMPLATE/bug_report.yml` and `.github/ISSUE_TEMPLATE/feature_request.yml` to remove "PowerShell" from the Area dropdown options.

#### Update Pull Request Template

Edit `.github/pull_request_template.md` to remove the "PowerShell-Specific (if applicable)" section.

---

## Updating package.json Metadata

**File:** `package.json`

The `package.json` file contains template-specific values that should be updated to reflect your project. This applies to **all projects** using this template, not just Node.js projects, because `package.json` is used for the markdown linting tooling.

### Fields to Update

Open `package.json` and update the following fields:

| Field | Template Value | Update To |
| --- | --- | --- |
| `name` | `"copilot-repo-template"` | Your project name (lowercase, no spaces) |
| `description` | `"Template repository with Copilot instructions and code quality tooling"` | Your project description |
| `author` | `"Frank Lesniak"` | Your name or organization |
| `keywords` | `["template", "copilot", "linting"]` | Keywords relevant to your project |

### Example

After updating, your `package.json` metadata might look like:

```json
{
  "name": "my-awesome-project",
  "version": "1.0.0",
  "description": "A tool for automating cloud infrastructure deployments",
  "private": true,
  "keywords": [
    "automation",
    "cloud",
    "infrastructure"
  ],
  "author": "Jane Developer"
}
```

### Fields to Keep As-Is

The following fields can typically remain unchanged:

- `version` — Start at `1.0.0` unless you have a specific versioning scheme
- `private` — Keep as `true` unless you plan to publish to npm
- `scripts` — These are configured for markdown linting and should be kept
- `engines` — Specifies the minimum Node.js version required
- `devDependencies` — Required packages for markdown linting

> **See Also:** [OPTIONAL_CONFIGURATIONS.md](OPTIONAL_CONFIGURATIONS.md#nodejs-package-configuration) for additional optional configurations like adding `repository`, `homepage`, and `bugs` fields.

---

## Customizing the Pull Request Template

**File:** `.github/pull_request_template.md`

The pull request template provides a contributor checklist for consistent PR reviews.

### Delete Template Comment

Delete the HTML comment at the top of the file (lines 1-4):

```markdown
<!--
Template users: see OPTIONAL_CONFIGURATIONS.md for guidance on tailoring this PR
template. Delete this comment once the PR template is tailored for your needs.
-->
```

### Language-Specific Sections

Remove sections for languages you're not using:

- **If NOT using Python:** Delete the entire "Python-Specific (if applicable)" section
- **If NOT using PowerShell:** Delete the entire "PowerShell-Specific (if applicable)" section

### Pre-commit Verification Section

- **If using pre-commit:** Keep the section. Optionally strengthen the conditional language to direct language (see [Pull Request Template Customization](OPTIONAL_CONFIGURATIONS.md#pull-request-template-customization) for details).
- **If NOT using pre-commit:** Delete the entire "Pre-commit Verification (if configured)" section.

> **See Also:** [OPTIONAL_CONFIGURATIONS.md](OPTIONAL_CONFIGURATIONS.md#pull-request-template-customization) for additional customizations like adding language-specific sections for other languages (Node.js, .NET, Go, Rust, Java), customizing Type of Change options, or strengthening test requirements.

---

## Updating README.md

The template README includes both a project section (for your use) and a template documentation section (for template users). You should customize the project section and remove the template documentation.

### Understanding the Current README Structure

The README has two main parts:

1. **Project section (lines 1-10):** Keep this—add your project name and description
2. **Template section (starting with "Readme for the Copilot Repository Template"):** Delete this

### What to Keep

Keep the top section and customize it:

```markdown
# Your Project Name

> **Note:** This repository was created from [`franklesniak/copilot-repo-template`](https://github.com/franklesniak/copilot-repo-template).

## Description

Your actual project description goes here. Explain what your project does,
why it exists, and who it's for.
```

### What to Delete

Delete everything from the heading `## Readme for the Copilot Repository Template` down to the end of the file, including:

- What This Template Provides
- Repository Structure
- How to Use This Template
- Validating Your New Repository
- Language Support
- Linting Tools
- Testing
- Code Quality
- Template Maintenance
- License (keep this, but update if needed)

### Minimal README Template

Here's a minimal template for your project README:

```markdown
# Your Project Name

> **Note:** This repository was created from [`franklesniak/copilot-repo-template`](https://github.com/franklesniak/copilot-repo-template).

## Description

Brief description of what your project does.

## Installation

Instructions for installing your project.

## Usage

Examples of how to use your project.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

MIT License - See [LICENSE](LICENSE) for details.
```

---

## Customizing CONTRIBUTING.md

**File:** `CONTRIBUTING.md`

The `CONTRIBUTING.md` file includes a "For Template Users" section near the end that contains meta-instructions about the template itself. This section should be removed for most downstream projects.

### Remove "For Template Users" Section

This section (starting with `## For Template Users`) includes:

- Information about understanding instruction files
- Guidance on customizing for your project
- First-time setup validation steps

**For non-template projects (most common):** Delete the entire "For Template Users" section, including the HTML comment above it.

**To delete:**

Locate the section starting with:

````markdown
<!--
TEMPLATE ADOPTERS: This entire section is meta-documentation about the template itself.
...
-->

## For Template Users
````

Delete from the HTML comment through the end of the file.

**To keep (if your project is also a template):** Leave the section as-is and customize it for your template's specific guidance.

### Other Customizations

See [OPTIONAL_CONFIGURATIONS.md](OPTIONAL_CONFIGURATIONS.md) for additional `CONTRIBUTING.md` customization guidance, including:

- Replacing `OWNER/REPO` placeholders with your organization and repository name
- Updating Python version requirements
- Removing language-specific sections you don't use

---

## Customizing CODE_OF_CONDUCT.md

**File:** `CODE_OF_CONDUCT.md`

The `CODE_OF_CONDUCT.md` file defines community standards and expectations for behavior when participating in your project. It also establishes enforcement procedures for handling violations.

### Understanding the Contact Method Placeholder

The `[INSERT CONTACT METHOD]` placeholder in `CODE_OF_CONDUCT.md` should be replaced with a method for reporting code of conduct violations that:

- Is actively monitored
- Can receive sensitive reports privately
- Is appropriate for your project's size and community

**Examples of contact methods:**

- An email address (e.g., `conduct@example.com`)
- A link to a reporting form
- Instructions to contact specific maintainers via direct message

If you used the same email for both `CODE_OF_CONDUCT.md` and `SECURITY.md` during the [Initial Placeholder Replacement](#initial-placeholder-replacement) step, consider whether you want a separate contact method for code of conduct issues versus security vulnerabilities.

### About the Contributor Covenant

This template includes the [Contributor Covenant v3.0](https://www.contributor-covenant.org/version/3/0/code_of_conduct/), which is:

- **Widely recognized:** Used by over 200,000 open source projects
- **GitHub-supported:** Listed as a recommended code of conduct when creating new repositories
- **Comprehensive:** Covers encouraged behaviors, restricted behaviors, enforcement procedures, and scope

### Whether to Keep or Remove

**Keep the file if your project:**

- Accepts contributions from others
- Has or expects community interaction (issues, discussions, PRs)
- Is part of an organization that requires a code of conduct

**Consider removing the file if your project:**

- Is a personal project that doesn't accept external contributions
- Is internal/private with no external community interaction

> **Note:** The placeholder check workflow treats `CODE_OF_CONDUCT.md` as optional—it will continue to pass if the file is missing.

See [OPTIONAL_CONFIGURATIONS.md](OPTIONAL_CONFIGURATIONS.md#code-of-conduct-configuration) for advanced customization options including alternative code of conduct templates and customizing enforcement procedures.

---

## Updating Copilot Instructions

The `.github/copilot-instructions.md` file contains repository-wide coding standards that guide GitHub Copilot's code generation. You should customize this for your project.

### Customizing the Source of Truth Section

Edit `.github/copilot-instructions.md` and update the "Source of Truth" section to point to your project's specification or design documents:

```markdown
## Source of Truth

> **Important:** Read **`docs/spec/requirements.md`** before making changes.
> If any instruction here conflicts with the spec, **the spec wins**.
```

If you don't have a specification document yet, you can simplify this section or leave the placeholder guidance.

### Updating the Language Table

If you removed Python or PowerShell support, update the language table to reflect your project's languages:

```markdown
## Language-Specific Instructions

This repository uses modular instruction files for language-specific standards:

| Language | Instruction File | Applies To |
| --- | --- | --- |
| Markdown/Docs | `.github/instructions/docs.instructions.md` | `**/*.md` |
```

Remove rows for languages you're not using.

### Updating Linting and Testing Tables

If you removed Python or PowerShell support, also update the **Linting Configurations** and **Testing Tools** tables in `.github/copilot-instructions.md`.

**Linting Configurations table** — Remove the PSScriptAnalyzer row if you removed PowerShell:

```markdown
## Linting Configurations

| Tool | Configuration File | Purpose |
| --- | --- | --- |
| markdownlint | `.markdownlint.jsonc` | Markdown linting |
```

**Testing Tools table** — Remove rows for languages you're not using:

If you removed Python:

```markdown
## Testing Tools

| Language | Framework | Configuration | Test Location |
| --- | --- | --- | --- |
| PowerShell | Pester 5.x | Inline in `.github/workflows/powershell-ci.yml` | `tests/PowerShell/` |
```

If you removed PowerShell:

```markdown
## Testing Tools

| Language | Framework | Configuration | Test Location |
| --- | --- | --- | --- |
| Python | pytest | `pyproject.toml` (`[tool.pytest.ini_options]`) | `tests/` |
```

If you removed both Python and PowerShell, remove the entire Testing Tools section or update it for your project's languages.

### Reviewing Instruction Files

Review the files in `.github/instructions/` and remove or modify any that don't apply to your project:

- `docs.instructions.md` - Documentation standards (keep for all projects)
- `powershell.instructions.md` - PowerShell standards (remove if not using PowerShell)
- `python.instructions.md` - Python standards (remove if not using Python)
- `terraform.instructions.md` - Terraform/IaC standards (remove if not using Terraform)

### Reviewing Agent Instruction Files

The template includes three agent instruction files at the repository root for multi-platform AI coding agent support:

- `CLAUDE.md` — Claude Code, GitHub Copilot coding agent
- `AGENTS.md` — OpenAI Codex CLI, GitHub Copilot coding agent
- `GEMINI.md` — Gemini Code Assist, GitHub Copilot coding agent

These files are synchronized summaries of the rules in `.github/copilot-instructions.md`. They provide essential guidance to their respective AI coding platforms.

**To customize for your project:**

1. **Remove unneeded files** — Delete agent files for platforms you do not use (e.g., if not using Claude Code, delete `CLAUDE.md`)
2. **Keep remaining files** — Keep all agent files for platforms you want to support, or accept that agents on those platforms receive no project-specific instructions
3. **Keep files synchronized** — If you modified `.github/copilot-instructions.md` (language table, testing table, linting table, or Source of Truth section), apply equivalent changes to any remaining agent files to keep them synchronized

---

## Additional Configuration (Optional)

### Installing the GitHub CLI

Several optional configuration steps use the GitHub CLI (`gh`). If you haven't installed it yet:

**Windows:**

Download from [cli.github.com](https://cli.github.com/) or use winget:

```powershell
winget install --id GitHub.cli
```

**macOS:**

```bash
brew install gh
```

**Linux (Debian/Ubuntu):**

```bash
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
```

After installation, authenticate with GitHub:

```bash
gh auth login
```

### Creating the `triage` Label

The issue templates reference a `triage` label that doesn't exist by default. Creating this label enables better issue organization.

**Why it's not created automatically:** GitHub doesn't support auto-creating labels when a repository is created from a template. This is a platform limitation.

**Using GitHub CLI:**

```bash
gh label create triage --description "Needs triage" --color "d4c5f9"
```

**Using the GitHub web interface:**

1. Go to your repository on GitHub
2. Navigate to **Issues** > **Labels** (or go to Settings > Labels)
3. Click **New label**
4. Enter:
   - **Label name:** `triage`
   - **Description:** `Needs triage`
   - **Color:** `d4c5f9` (lavender)
5. Click **Create label**

**After creating the label:** Uncomment the `# - triage` line in each issue template where you want it applied:

- `.github/ISSUE_TEMPLATE/bug_report.yml`
- `.github/ISSUE_TEMPLATE/documentation_issue.yml`
- `.github/ISSUE_TEMPLATE/feature_request.yml`

### Configuring Dependabot

The template includes Dependabot configuration at `.github/dependabot.yml` for automated dependency updates.

**To customize update frequency:**

Edit `.github/dependabot.yml` and modify the `schedule` section:

```yaml
schedule:
  interval: "weekly"  # Options: daily, weekly, monthly
```

**To disable Dependabot:**

Delete `.github/dependabot.yml` from your repository.

### Branch Ruleset (Recommended)

Repository rulesets help prevent accidental force pushes and ensure code review. Rulesets are the recommended replacement for classic branch protection rules and offer more granular control. See [GitHub's rulesets documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets) for setup instructions.

For detailed guidance on branch ruleset setup, see the "Branch Ruleset Setup" section in [`.github/DESIGN_DECISIONS.md`](.github/DESIGN_DECISIONS.md).

---

## Validation and Testing

Before committing your changes, validate that everything is configured correctly.

### Run Pre-commit on All Files

```bash
pre-commit run --all-files
```

**Expected output for a clean run:**

```text
Trim Trailing Whitespace......................................Passed
Fix End of Files..............................................Passed
Check Yaml....................................................Passed
Check for added large files...................................Passed
black.........................................................Passed
ruff..........................................................Passed
markdownlint-cli2.............................................Passed
```

**Troubleshooting common failures:**

- **Trailing whitespace / End of file:** These are auto-fixed. Re-run pre-commit and it should pass.
- **YAML errors:** Check for syntax errors in `.yml` files.
- **Markdown errors:** Run `npm run lint:md` to see specific issues.
- **Black/Ruff errors:** These may auto-fix. Re-run pre-commit. For persistent issues, check the specific error messages.

### Run Tests (If Applicable)

**Python:**

```bash
pytest tests/ -v
```

**PowerShell:**

```powershell
Invoke-Pester -Path tests/ -Output Detailed
```

### Commit and Push

**Stage all changes:**

```bash
git add .
```

**Review what will be committed:**

```bash
git status
```

**Create your initial commit:**

```bash
git commit -m "Initial project setup from template"
```

> **Note:** Pre-commit hooks will run automatically. If they modify files, review the changes, stage them (`git add .`), and commit again.

**Push to GitHub:**

```bash
git push origin main
```

### Verify CI Workflows Pass

After pushing, go to your repository on GitHub and:

1. Click the **Actions** tab
2. Verify that all workflows complete successfully (green checkmarks)

### Verify Placeholder Check Workflow

The `check-placeholders.yml` workflow verifies that you've replaced all `OWNER/REPO` placeholders. If this workflow fails:

1. Read the error messages to identify which files still have placeholders
2. Replace the placeholders with your actual organization and repository name
3. Commit and push the fixes

**What the workflow checks:**

- `OWNER/REPO` in `.github/ISSUE_TEMPLATE/config.yml`
- `OWNER/REPO` in `CONTRIBUTING.md`
- `@OWNER` in `.github/CODEOWNERS`
- `[security contact email]` in `SECURITY.md`

**After all placeholders are replaced:**

Once you've replaced all placeholders and the workflow passes, you have two options:

- **Keep the workflow** — It serves as a safety net for any future template updates or additions
- **Remove the workflow** — Delete `.github/workflows/check-placeholders.yml` if you no longer need placeholder checking

See [Placeholder Check Workflow Configuration](OPTIONAL_CONFIGURATIONS.md#placeholder-check-workflow-configuration) for more details on customizing this workflow.

### Post-clone Verification Plan

After completing the setup checklist, perform the following quick verification:

1. **Verify template functionality** in your newly created repository (template maintainers can create a separate test repository to verify template changes)
2. **Open each issue type** once and ensure required fields behave correctly
3. **Click key links** in the issue template chooser:
   - Contributing Guide link
   - Security Vulnerabilities link
   - (If enabled) Discussions link
4. **Verify issue form rendering:**
   - Open a bug report issue template
   - Paste a Python traceback into the Logs/Error Output field
   - Confirm it renders cleanly as plain text (not mangled by Markdown parsing)
5. **Verify security flow:**
   - From your repository's main page, click the **Security** tab
   - Confirm SECURITY.md is accessible
6. **Open a test PR** to verify the PR workflow:
   - Create a trivial change (e.g., add a comment to a file)
   - Open a pull request and confirm:
     - PR template renders correctly
     - Contributing guidelines link works
     - CI workflows trigger as expected
   - Close the test PR without merging

---

## Cleanup

After completing setup and verification, clean up template-specific files.

### Keep DESIGN_DECISIONS.md

The design decisions document (`.github/DESIGN_DECISIONS.md`) contains rationale for template design choices. **We recommend keeping this file** as it provides valuable context for:

- Understanding why certain configurations were made
- Onboarding new maintainers who benefit from design context
- Recording your own design decisions alongside the template's rationale
- Future code reviews and maintenance decisions

The file is internal documentation that does not affect end users or repository functionality.

### Consider This Getting Started Guide

You have three options for `GETTING_STARTED_NEW_REPO.md`:

1. **Delete it** if your project won't be used as a template for others
2. **Keep it** if your project is also a template that others will clone
3. **Modify it** to be specific to your project's setup process

**To delete:**

**Windows (PowerShell):**

```powershell
Remove-Item -Force "GETTING_STARTED_NEW_REPO.md"
```

**macOS/Linux/FreeBSD:**

```bash
rm -f GETTING_STARTED_NEW_REPO.md
```

### Final Cleanup Commit

```bash
git add .
git commit -m "Remove template documentation after initial setup"
git push origin main
```

---

## Troubleshooting

### Pre-commit Hook Failures

**Problem:** Pre-commit hooks fail with "command not found" errors.

**Solution:** Ensure pre-commit is installed globally and in your PATH:

```bash
pip install pre-commit
pre-commit --version
```

**Problem:** Hooks download every time you commit.

**Solution:** This is normal on first run. The environments are cached in `~/.cache/pre-commit/`. If they keep downloading, check disk space and permissions.

### Python ModuleNotFoundError

**Problem:** `ModuleNotFoundError: No module named 'copilot_repo_template'`

**Solution:** You need to either:

1. Rename `src/copilot_repo_template/` to your package name and update imports
2. Install the package in development mode: `pip install -e ".[dev]"`
3. If not using Python, delete the `src/` directory

### Node.js/npm Errors

**Problem:** `npm install` fails with permission errors.

**Solution:**

- **Windows:** Run PowerShell as Administrator
- **macOS/Linux:** Don't use `sudo npm install`. Instead, fix npm permissions or use a version manager like nvm.

**Problem:** `npm run lint:md` fails with "command not found".

**Solution:** Run `npm install` first to install dependencies.

### Placeholder Check CI Failures

**Problem:** The `check-placeholders.yml` workflow fails.

**Solution:** Read the error messages carefully. They tell you exactly which files and lines contain placeholders. Replace:

- `OWNER/REPO` with `your-username/your-repo-name`
- `@OWNER` with `@your-username`
- `[security contact email]` with your actual email or remove the email option

### Permission Errors

**Windows:**

- Run PowerShell as Administrator for system-wide installations
- Check that Python and Node.js are in your PATH
- Restart PowerShell after installing new tools

**macOS/Linux/FreeBSD:**

- Don't use `sudo` for pip or npm installations in your home directory
- Check file ownership: `ls -la`
- Fix ownership: `sudo chown -R $(whoami) ~/.npm ~/.cache`

### Pre-commit Not Running on Commit

**Problem:** Git commits succeed without running pre-commit hooks.

**Solution:** Re-install the hooks:

**Windows (PowerShell):**

If you installed with pipx:

```powershell
pre-commit install
```

> **Note:** If `pre-commit` is not found, run `python -m pipx ensurepath` and restart your PowerShell window. Do not use `pipx run pre-commit install` because it runs from a temporary environment and can create hooks that reference a non-existent interpreter.

If you installed with pip:

```powershell
python -m pre_commit install
```

**macOS/Linux/FreeBSD:**

If you installed with pipx:

```bash
pre-commit install
```

> **Note:** If `pre-commit` is not found, run `python3 -m pipx ensurepath` (or `pipx ensurepath` if `pipx` is already on your PATH) and restart your terminal. Do not use `pipx run pre-commit install` because it runs from a temporary environment and can create hooks that reference a non-existent interpreter.

If you installed with Homebrew:

```bash
pre-commit install
```

> **Note:** If `pre-commit` is not found, ensure Homebrew's `bin` directory (typically `/opt/homebrew/bin` on Apple Silicon or `/usr/local/bin` on Intel Macs) is in your PATH.

If you installed with pip:

```bash
python3 -m pre_commit install
```

Verify the hook exists:

**Windows:**

```powershell
Get-Content .git\hooks\pre-commit
```

**macOS/Linux/FreeBSD:**

```bash
cat .git/hooks/pre-commit
```

---

## Development Workflow

Now that your repository is set up, you're ready to start development! For the standard development workflow, including:

- Creating branches
- Making changes
- Running tests
- Submitting pull requests
- Code review process

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed instructions.

**Quick reference for daily development:**

**Windows (PowerShell):**

```powershell
# Create a feature branch
git checkout -b feature/your-feature-name

# Make changes and run pre-commit
pre-commit run --all-files

# Stage and commit
git add .
git commit -m "Add your feature"

# Push and open a PR
git push origin feature/your-feature-name
```

If `pre-commit` is not on PATH:

- **pipx users:** Run `python -m pipx ensurepath` (or `pipx ensurepath` if `pipx` is already on your PATH) and restart your PowerShell window, then run `pre-commit run --all-files`.
- **pip users:** Use module invocation:

  ```powershell
  python -m pre_commit run --all-files
  ```

**macOS/Linux/FreeBSD:**

```bash
# Create a feature branch
git checkout -b feature/your-feature-name

# Make changes and run pre-commit
pre-commit run --all-files

# Stage and commit
git add .
git commit -m "Add your feature"

# Push and open a PR
git push origin feature/your-feature-name
```

If `pre-commit` is not on PATH:

- **pipx users:** Run `python3 -m pipx ensurepath` (or `pipx ensurepath` if `pipx` is already on your PATH) and restart your terminal, then run `pre-commit run --all-files`.
- **pip users:** Use module invocation:

  ```bash
  python3 -m pre_commit run --all-files
  ```

---

## Next Steps

After completing the initial setup, you may want to explore additional customization options:

- **[Optional Configurations](OPTIONAL_CONFIGURATIONS.md)**: Fine-tune your repository with optional settings like enabling GitHub Discussions, adjusting Dependabot frequency, customizing linting rules, and more.

---

**Congratulations!** 🎉 Your repository is now fully configured and ready for development. Happy coding!
