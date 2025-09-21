# MSSQL MCP Server with Username/Password Authentication

## Purpose

This repository provides a modified version of the Microsoft MSSQL MCP (Model Context Protocol) server that supports SQL Server username and password authentication. The out-of-the-box MCP server from Microsoft only supports Azure AD authentication, which limits its use in environments where traditional SQL Server authentication is required.

This script automatically:
- Downloads the modified MSSQL MCP server files from this repository
- Rebuilds the solution with username/password authentication support
- Configures the server for use with VS Code and Claude Desktop

## What's Modified

The original Microsoft MSSQL MCP server has been enhanced to support:
- ✅ SQL Server username/password authentication
- ✅ Azure AD authentication (original functionality preserved)
- ✅ Connection string customization
- ✅ Environment variable configuration

## Files in This Repository

- `index.ts` - Modified MSSQL MCP server implementation with SQL auth support
- `setup-mssql-mcp.ps1` - PowerShell automation script for installation and configuration
- `mcp.json` - Sample configuration file for VS Code

## Quick Start

### Prerequisites

- Node.js (v18 or higher)
- PowerShell (Windows)
- VS Code (for integration)

### Installation

1. **Clone or download this repository**
   ```powershell
   git clone https://github.com/ashvinb/MSSQL_MCP_SQL_AUTH_FILE_REPLACEMENT.git
   cd MSSQL_MCP_SQL_AUTH_FILE_REPLACEMENT
   ```

2. **Run the setup script**
   ```powershell
   .\setup-mssql-mcp.ps1 -ServerName "your-server.com" -DatabaseName "your-database" -Username "your-username" -Password "your-password" -ConfigureVSCode
   ```

### Configuration Options

The setup script supports various authentication modes:

#### SQL Server Authentication
```powershell
.\setup-mssql-mcp.ps1 -ServerName "server.com" -DatabaseName "mydb" -Username "sqluser" -Password "sqlpass"
```

#### Azure AD Authentication
```powershell
.\setup-mssql-mcp.ps1 -ServerName "server.database.windows.net" -DatabaseName "mydb" -UseAzureAuth
```

#### Read-Only Mode
```powershell
.\setup-mssql-mcp.ps1 -ServerName "server.com" -DatabaseName "mydb" -Username "user" -Password "pass" -ReadOnly
```

## VS Code Integration

### Using the JSON Configuration File

After running the setup script with `-ConfigureVSCode`, the MCP server will be automatically configured in VS Code. The configuration is stored in your VS Code settings and uses a format similar to this:

```json
{
  "servers": {
    "MSSQL MCP": {
      "type": "stdio",
      "command": "node",
      "args": ["C:\\Users\\YourUser\\.mcp\\servers\\mssql\\SQL-AI-samples\\MssqlMcp\\Node\\dist\\index.js"],
      "env": {
        "SERVER_NAME": "your-server.com",
        "DATABASE_NAME": "your-database",
        "USERNAME": "your-username",
        "PASSWORD": "your-password",
        "READONLY": "false",
        "ENCRYPT": "true",
        "TRUST_SERVER_CERTIFICATE": "true"
      },
      "dev": {
        "debug": { "type": "node" }
      }
    }
  }
}
```

### Manual VS Code Configuration

If you need to manually configure VS Code:

1. Open VS Code settings (JSON)
2. Add the MCP server configuration to your `settings.json`:
   ```json
   {
     "mcp.servers": {
       "mssql": {
         "type": "stdio",
         "command": "node",
         "args": ["path-to-your-mcp-server/dist/index.js"],
         "env": {
           "SERVER_NAME": "your-server",
           "DATABASE_NAME": "your-database",
           "USERNAME": "your-username",
           "PASSWORD": "your-password"
         }
       }
     }
   }
   ```

### Environment Variables

The MCP server supports these environment variables:

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `SERVER_NAME` | SQL Server hostname or IP | Yes | - |
| `DATABASE_NAME` | Database name to connect to | Yes | - |
| `USERNAME` | SQL Server username | No* | - |
| `PASSWORD` | SQL Server password | No* | - |
| `READONLY` | Enable read-only mode | No | false |
| `ENCRYPT` | Enable connection encryption | No | true |
| `TRUST_SERVER_CERTIFICATE` | Trust server certificate | No | true |

*Required for SQL Server authentication, optional for Azure AD authentication

## Troubleshooting

### Common Issues

1. **Node.js not found**
   - Ensure Node.js v18+ is installed and in your PATH

2. **Connection failures**
   - Verify server name, database name, and credentials
   - Check firewall settings
   - Ensure SQL Server authentication is enabled (if using username/password)

3. **Permission errors**
   - Run PowerShell as Administrator if needed
   - Check file permissions in the installation directory

### Debug Mode

To enable debug output:
```powershell
.\setup-mssql-mcp.ps1 -ServerName "server" -DatabaseName "db" -Username "user" -Password "pass" -Verbose
```

## Contributing

This repository addresses a gap in the official Microsoft MSSQL MCP server. If you encounter issues or have improvements:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

This project builds upon Microsoft's official SQL AI samples. Please refer to the original Microsoft repository for licensing terms.

## Acknowledgments

- Based on Microsoft's official Azure SQL samples repository
- Enhanced to support traditional SQL Server authentication
- Community-driven solution for broader SQL Server compatibility
