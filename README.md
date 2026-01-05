# Claude Desktop for Fedora Linux

Community build of Claude Desktop for Fedora, converted from the Windows installer.

## Requirements

- Fedora Linux (tested on Fedora 43)
- sudo

## Installation
```bash
sudo ./claude-desktop-installer.sh
```

The script will:
1. Install dependencies
2. Download Claude Desktop Windows installer
3. Extract and convert for Linux
4. Build RPM package

After the build completes, install with:
```bash
sudo rpm -ivh --nodeps claude-build/x86_64/claude-desktop-*.rpm
```

## Usage

Launch from applications menu or run:
```bash
claude-desktop
```

Logs are saved to `~/.claude-desktop.log`

## Uninstallation
```bash
sudo ./uninstall.sh
```

This will remove the installed package and optionally clean up user configuration.

## MCP Configuration

Create `~/.config/Claude/claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/path/to/your/directory"
      ]
    }
  }
}
```

Restart Claude Desktop after configuration.

## Project Structure
```
claude-desktop-fedora/
├── claude-desktop-installer.sh           # Main installer script
├── uninstall.sh                          # Uninstaller script
├── templates/
│   ├── claude-native-stub.js             # Native module stub for Linux
│   ├── claude-desktop.desktop            # Desktop entry file
│   ├── claude-desktop-launcher.sh        # Launch script
│   └── claude-desktop.spec.template      # RPM spec template
└── README.md                             # This file
```

## Disclaimer

This is not an official Anthropic package. Use at your own risk.
