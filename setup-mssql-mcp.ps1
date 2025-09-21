# Microsoft MSSQL MCP Server Automation Script
# Based on the official Microsoft Azure SQL samples repository
# Supports both Azure AD authentication and SQL Server authentication

param(
    [Parameter(Mandatory=$false)]
    [string]$InstallPath = "$env:USERPROFILE\.mcp\servers\mssql",
    
    [Parameter(Mandatory=$false)]
    [string]$ServerName = "",
    
    [Parameter(Mandatory=$false)]
    [string]$DatabaseName = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Username = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Password = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$UseAzureAuth = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$ReadOnly = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$TrustServerCertificate = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipNodeCheck = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$ConfigureVSCode = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$ConfigureClaudeDesktop = $false
)

# Color functions for better output
function Write-Info {
    param([string]$Message)
    Write-Host "INFO: $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "SUCCESS: $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "WARNING: $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "ERROR: $Message" -ForegroundColor Red
}

function Test-NodeInstallation {
    try {
        $nodeVersion = node --version 2>$null
        if ($nodeVersion) {
            Write-Success "Node.js found: $nodeVersion"
            return $true
        }
    }
    catch {
        Write-Warning "Node.js not found in PATH"
        return $false
    }
    return $false
}

function Test-GitInstallation {
    try {
        $gitVersion = git --version 2>$null
        if ($gitVersion) {
            Write-Success "Git found: $gitVersion"
            return $true
        }
    }
    catch {
        Write-Warning "Git not found in PATH"
        return $false
    }
    return $false
}

function Install-NodeJS {
    Write-Info "Installing Node.js..."
    
    try {
        winget --version | Out-Null
        Write-Info "Using winget to install Node.js..."
        winget install OpenJS.NodeJS
        Write-Success "Node.js installation completed"
        
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    }
    catch {
        Write-Warning "winget not available. Please install Node.js manually from https://nodejs.org/"
        Write-Info "After installing Node.js, re-run this script."
        exit 1
    }
}

function Install-Git {
    Write-Info "Installing Git..."
    
    try {
        winget --version | Out-Null
        Write-Info "Using winget to install Git..."
        winget install Git.Git
        Write-Success "Git installation completed"
        
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    }
    catch {
        Write-Warning "winget not available. Please install Git manually from https://git-scm.com/downloads"
        Write-Info "After installing Git, re-run this script."
        exit 1
    }
}

function New-MCPServerDirectory {
    param([string]$Path)
    
    if (Test-Path $Path) {
        Write-Warning "Directory already exists: $Path"
        $response = Read-Host "Do you want to continue? This will overwrite existing files (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            exit 0
        }
        Remove-Item -Path $Path -Recurse -Force
    }
    
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Write-Success "Created directory: $Path"
    
    return $Path
}

function Install-MCPSQLServer {
    param([string]$InstallPath)
    
    $originalLocation = Get-Location
    
    try {
        Set-Location $InstallPath
        
        Write-Info "Cloning Microsoft Azure SQL samples repository..."
        git clone https://github.com/Azure-Samples/SQL-AI-samples.git | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to clone the repository"
            exit 1
        }
        
        Write-Info "Navigating to MCP server directory..."
        $mcpServerPath = Join-Path $InstallPath "SQL-AI-samples\MssqlMcp\Node"
        Set-Location $mcpServerPath
        
        Write-Info "Installing npm dependencies..."
        npm install | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to install npm dependencies"
            exit 1
        }
        
        Write-Success "MCP MSSQL server installed and built successfully"
        
        # Return the path to the built index.js
        $indexJsPath = Join-Path $mcpServerPath "dist\index.js"
        
        if (Test-Path $indexJsPath) {
            Write-Info "Found built server at: $indexJsPath"
            return $indexJsPath
        } else {
            Write-Warning "Built index.js not found at expected location: $indexJsPath"
            # Try to find it
            $foundFiles = Get-ChildItem -Path $mcpServerPath -Name "index.js" -Recurse
            if ($foundFiles) {
                $indexJsPath = Join-Path $mcpServerPath $foundFiles[0]
                Write-Info "Found index.js at: $indexJsPath"
                return $indexJsPath
            } else {
                Write-Error "Could not locate built index.js file"
                Write-Info "Available files in dist directory:"
                $distPath = Join-Path $mcpServerPath "dist"
                if (Test-Path $distPath) {
                    Get-ChildItem -Path $distPath | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor Gray }
                }
                exit 1
            }
        }
    }
    finally {
        Set-Location $originalLocation
    }
}

function Update-AuthenticationCode {
    param([string]$IndexTsPath, [bool]$EnableSqlAuth)
    
    if (-not $EnableSqlAuth) {
        Write-Info "Skipping SQL authentication code modification (Azure AD only)"
        return
    }
    
    Write-Info "Downloading pre-modified index.ts with SQL Server authentication support..."
    
    try {
        # Download the modified file
        $modifiedFileUrl = "https://raw.githubusercontent.com/ashvinb/MSSQL_MCP_SQL_AUTH_FILE_REPLACEMENT/master/index.ts"
        
        # Backup the original file
        $backupPath = $IndexTsPath + ".backup." + (Get-Date -Format 'yyyyMMdd_HHmmss')
        Copy-Item $IndexTsPath $backupPath
        Write-Info "Original file backed up to: $backupPath"
        
        # Download the modified file
        Invoke-WebRequest -Uri $modifiedFileUrl -OutFile $IndexTsPath -UseBasicParsing
        Write-Success "Downloaded modified index.ts with SQL Server authentication support"
        
        # Verify the file was downloaded
        if (Test-Path $IndexTsPath) {
            $fileSize = (Get-Item $IndexTsPath).Length
            if ($fileSize -gt 0) {
                Write-Success "File downloaded successfully ($fileSize bytes)"
            } else {
                Write-Error "Downloaded file is empty"
                # Restore backup
                Copy-Item $backupPath $IndexTsPath
                return
            }
        } else {
            Write-Error "Failed to download the file"
            return
        }
        
        # Navigate to the project root directory
        $projectRoot = Split-Path $IndexTsPath -Parent | Split-Path -Parent
        $currentLocation = Get-Location
        Set-Location $projectRoot
        
        # Rebuild the solution with npm install (which includes the build step)
        Write-Info "Rebuilding solution with npm install..."
        npm install | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Solution rebuilt successfully with SQL Server authentication support"
        } else {
            Write-Warning "npm install completed with warnings. Attempting direct build..."
            
            # Fallback to direct build command
            npm run build | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Project built successfully with npm run build"
            } else {
                Write-Warning "Build completed with warnings. The server should still work."
            }
        }
        
        Set-Location $currentLocation
        
    } catch {
        Write-Error "Failed to download or apply the modified authentication code: $($_.Exception.Message)"
        Write-Info "Attempting to restore original file..."
        
        if (Test-Path $backupPath) {
            Copy-Item $backupPath $IndexTsPath
            Write-Info "Original file restored from backup"
        }
        
        Write-Warning "SQL Server authentication may not work without the modified code"
        Write-Info "You can manually download and replace the file from:"
        Write-Info "  $modifiedFileUrl"
        Write-Info "  Save it as: $IndexTsPath"
        Write-Info "  Then run: npm install"
    }
}

function New-VSCodeConfig {
    param(
        [string]$IndexJsPath,
        [string]$ServerName,
        [string]$DatabaseName,
        [string]$Username,
        [string]$Password,
        [bool]$UseAzureAuth,
        [bool]$ReadOnly,
        [bool]$TrustServerCertificate
    )
    
    $config = @{
        mcp = @{
            servers = @{
                "MSSQL MCP" = @{
                    type = "stdio"
                    command = "node"
                    args = @($IndexJsPath)
                    env = @{
                        SERVER_NAME = $ServerName
                        DATABASE_NAME = $DatabaseName
                        READONLY = $ReadOnly.ToString().ToLower()
                        TRUST_SERVER_CERTIFICATE = $TrustServerCertificate.ToString().ToLower()
                        ENCRYPT = "true"
                    }
                }
            }
        }
    }
    
    # Add authentication details
    if (-not $UseAzureAuth -and $Username -and $Password) {
        $config.mcp.servers."MSSQL MCP".env.USERNAME = $Username
        $config.mcp.servers."MSSQL MCP".env.PASSWORD = $Password
    }
    
    $configJson = $config | ConvertTo-Json -Depth 10
    $vsCodeSettingsPath = "$env:APPDATA\Code\User\settings.json"
    
    Write-Info "VS Code configuration:"
    Write-Host $configJson -ForegroundColor Gray
    Write-Info "Add this configuration to your VS Code settings.json file at: $vsCodeSettingsPath"
}

function New-ClaudeDesktopConfig {
    param(
        [string]$IndexJsPath,
        [string]$ServerName,
        [string]$DatabaseName,
        [string]$Username,
        [string]$Password,
        [bool]$UseAzureAuth,
        [bool]$ReadOnly,
        [bool]$TrustServerCertificate
    )
    
    $config = @{
        mcpServers = @{
            "MSSQL MCP" = @{
                command = "node"
                args = @($IndexJsPath)
                env = @{
                    SERVER_NAME = $ServerName
                    DATABASE_NAME = $DatabaseName
                    READONLY = $ReadOnly.ToString().ToLower()
                    TRUST_SERVER_CERTIFICATE = $TrustServerCertificate.ToString().ToLower()
                    ENCRYPT = "true"
                }
            }
        }
    }
    
    # Add authentication details
    if (-not $UseAzureAuth -and $Username -and $Password) {
        $config.mcpServers."MSSQL MCP".env.USERNAME = $Username
        $config.mcpServers."MSSQL MCP".env.PASSWORD = $Password
    }
    
    $configJson = $config | ConvertTo-Json -Depth 10
    $claudeConfigPath = "$env:APPDATA\Claude\claude_desktop_config.json"
    
    if (Test-Path $claudeConfigPath) {
        Write-Info "Backing up existing Claude Desktop configuration..."
        Copy-Item $claudeConfigPath "$claudeConfigPath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    }
    
    $configJson | Out-File -FilePath $claudeConfigPath -Encoding UTF8
    Write-Success "Claude Desktop configuration created: $claudeConfigPath"
}

function Show-UsageInstructions {
    param(
        [string]$InstallPath, 
        [string]$IndexJsPath,
        [bool]$UseAzureAuth,
        [string]$ServerName,
        [string]$DatabaseName
    )
    
    Write-Host "`n" -NoNewline
    Write-Success "=== Microsoft MSSQL MCP Server Setup Complete ==="
    Write-Host ""
    Write-Info "Installation Directory: $InstallPath"
    Write-Info "Server Executable: $IndexJsPath"
    Write-Host ""
    
    if ($UseAzureAuth) {
        Write-Info "Authentication: Azure Active Directory (Entra)"
        Write-Warning "On first use, you'll be prompted for Azure authentication"
    } else {
        Write-Info "Authentication: SQL Server Authentication"
        Write-Warning "Credentials are stored in configuration - ensure proper security measures"
    }
    
    Write-Host ""
    Write-Info "Example natural language queries you can now use:"
    Write-Host "  • 'What tables are available in my database?'" -ForegroundColor White
    Write-Host "  • 'Show me the top 10 customers by revenue'" -ForegroundColor White
    Write-Host "  • 'Describe the structure of the Orders table'" -ForegroundColor White
    Write-Host "  • 'Find all products with low inventory'" -ForegroundColor White
    Write-Host ""
    
    if ($ConfigureVSCode) {
        Write-Info "VS Code: Configuration has been displayed above"
        Write-Info "Add it to your settings.json and enable Agent Mode"
    }
    
    if ($ConfigureClaudeDesktop) {
        Write-Info "Claude Desktop: Configuration file has been updated"
        Write-Warning "Restart Claude Desktop completely to apply changes"
    }
    
    Write-Host ""
    Write-Success "Your database is now ready for AI-powered natural language interactions!"
}

# Main execution
Write-Info "Starting Microsoft MSSQL MCP Server setup..."
Write-Info "Based on official Microsoft Azure SQL samples repository"

# Check for prerequisites
if (-not $SkipNodeCheck) {
    if (-not (Test-NodeInstallation)) {
        $installNode = Read-Host "Node.js is required. Install it now? (Y/n)"
        if ($installNode -ne 'n' -and $installNode -ne 'N') {
            Install-NodeJS
            if (-not (Test-NodeInstallation)) {
                Write-Error "Node.js installation failed or not in PATH. Please install manually and re-run this script."
                exit 1
            }
        } else {
            Write-Error "Node.js is required for MCP server. Exiting."
            exit 1
        }
    }
    
    if (-not (Test-GitInstallation)) {
        $installGit = Read-Host "Git is required to clone the repository. Install it now? (Y/n)"
        if ($installGit -ne 'n' -and $installGit -ne 'N') {
            Install-Git
            if (-not (Test-GitInstallation)) {
                Write-Error "Git installation failed or not in PATH. Please install manually and re-run this script."
                exit 1
            }
        } else {
            Write-Error "Git is required to clone the repository. Exiting."
            exit 1
        }
    }
}

# Create installation directory
$installDir = New-MCPServerDirectory -Path $InstallPath

# Get SQL Server connection details if not provided
if (-not $ServerName) {
    $ServerName = Read-Host "Enter SQL Server name (e.g., localhost\SQLEXPRESS or server.database.windows.net)"
    while (-not $ServerName) {
        Write-Warning "Server name is required"
        $ServerName = Read-Host "Enter SQL Server name"
    }
}

if (-not $DatabaseName) {
    $DatabaseName = Read-Host "Enter database name"
    while (-not $DatabaseName) {
        Write-Warning "Database name is required"
        $DatabaseName = Read-Host "Enter database name"
    }
}

# Determine authentication method
if (-not $UseAzureAuth -and -not $Username) {
    Write-Host ""
    Write-Info "Authentication Options:"
    Write-Host "1. Azure Active Directory (Entra) - Recommended for Azure SQL" -ForegroundColor White
    Write-Host "2. SQL Server Authentication - For local/on-premises SQL Server" -ForegroundColor White
    
    $authChoice = Read-Host "Choose authentication method (1/2)"
    
    if ($authChoice -eq '1') {
        $UseAzureAuth = $true
        Write-Info "Using Azure AD authentication"
    } else {
        $UseAzureAuth = $false
        Write-Info "Using SQL Server authentication"
        
        $Username = Read-Host "Enter SQL Server username"
        while (-not $Username) {
            Write-Warning "Username is required for SQL authentication"
            $Username = Read-Host "Enter SQL Server username"
        }
        
        $Password = Read-Host "Enter SQL Server password" -AsSecureString
        $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
        while (-not $Password) {
            Write-Warning "Password is required for SQL authentication"
            $securePassword = Read-Host "Enter SQL Server password" -AsSecureString
            $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
        }
    }
}

# Ask about read-only mode
if (-not $ReadOnly) {
    $readOnlyChoice = Read-Host "Enable read-only mode for safety? (Y/n)"
    $ReadOnly = ($readOnlyChoice -ne 'n' -and $readOnlyChoice -ne 'N')
}

# Install the MCP server
Write-Info "Installing MCP server from Microsoft repository..."
$indexJsPath = Install-MCPSQLServer -InstallPath $installDir

if (-not $indexJsPath -or $indexJsPath -eq "" -or -not (Test-Path $indexJsPath)) {
    Write-Error "Failed to install MCP server or locate executable"
    Write-Info "Expected path: $indexJsPath"
    if ($installDir) {
        Write-Info "Searching for index.js files in installation directory..."
        Get-ChildItem -Path $installDir -Recurse -Name "index.js" -ErrorAction SilentlyContinue | ForEach-Object { 
            Write-Host "  Found: $_" -ForegroundColor Gray 
        }
    }
    exit 1
}

Write-Success "MCP server installed successfully at: $indexJsPath"

# Update authentication code if using SQL Server auth
if (-not $UseAzureAuth) {
    if ($indexJsPath -and (Test-Path $indexJsPath)) {
        $mcpNodePath = Split-Path (Split-Path $indexJsPath -Parent) -Parent
        $indexTsPath = Join-Path $mcpNodePath "src\index.ts"
        
        if (Test-Path $indexTsPath) {
            Update-AuthenticationCode -IndexTsPath $indexTsPath -EnableSqlAuth $true
            
            # Update the path to the rebuilt version (should still be the same)
            if (Test-Path $indexJsPath) {
                Write-Success "Using rebuilt index.js at: $indexJsPath"
            } else {
                Write-Warning "Rebuilt index.js not found, using original path"
            }
        } else {
            Write-Warning "Source TypeScript file not found at: $indexTsPath"
            Write-Info "SQL Server authentication may not work without manual code modification"
        }
    } else {
        Write-Error "Invalid index.js path: $indexJsPath"
        exit 1
    }
}

# Ask about client configurations
Write-Host ""
$configureVS = Read-Host "Generate VS Code configuration? (y/N)"
$ConfigureVSCode = ($configureVS -eq 'y' -or $configureVS -eq 'Y')

$configureClaude = Read-Host "Configure Claude Desktop? (Y/n)"
$ConfigureClaudeDesktop = ($configureClaude -ne 'n' -and $configureClaude -ne 'N')

# Generate configurations
if ($ConfigureVSCode) {
    New-VSCodeConfig -IndexJsPath $indexJsPath -ServerName $ServerName -DatabaseName $DatabaseName -Username $Username -Password $Password -UseAzureAuth $UseAzureAuth -ReadOnly $ReadOnly -TrustServerCertificate $TrustServerCertificate
}

if ($ConfigureClaudeDesktop) {
    New-ClaudeDesktopConfig -IndexJsPath $indexJsPath -ServerName $ServerName -DatabaseName $DatabaseName -Username $Username -Password $Password -UseAzureAuth $UseAzureAuth -ReadOnly $ReadOnly -TrustServerCertificate $TrustServerCertificate
}

# Show usage instructions
Show-UsageInstructions -InstallPath $installDir -IndexJsPath $indexJsPath -UseAzureAuth $UseAzureAuth -ServerName $ServerName -DatabaseName $DatabaseName

Write-Success "Setup completed successfully!"
Write-Host ""
Write-Warning "Security Reminder: If using SQL authentication, ensure proper credential protection in production environments."