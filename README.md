# Productivity Utils

A collection of productivity scripts for Unreal Engine development workflow, designed to streamline opening projects in JetBrains Rider.

## Features

- **Automated Project Setup**: Generate Unreal Engine project files automatically
- **Compilation**: Compile Development Editor before opening Rider
- **Rider Integration**: Automatically detect and open JetBrains Rider with your Unreal project
- **Interactive Configuration**: First-time setup prompts for required paths
- **Cross-Platform Support**: Works on Windows (batch files included)

## Requirements

- Python 3.x
- Unreal Engine (with source code access)
- JetBrains Rider installed
- Windows OS (for batch files)

## Setup

1. Clone this repository to your desired location
2. Run either batch file or the Python script directly
3. On first run, you'll be prompted to provide:
   - **Unreal Engine repository path**: Path to your Unreal Engine source code directory
   - **Project file path**: Path to your `.uproject` or `.sln` file

The configuration will be saved to `config.json` (which is gitignored to keep your paths private).

## Usage

### Option 1: Using Batch Files (Windows)

**Generate Project Files and Open:**
```batch
Generate and Open - CurrentUnrealProject.bat
```
This will:
1. Generate Unreal Engine project files
2. Compile Development Editor
3. Open Rider with your project

**Open Only (Skip Project Generation):**
```batch
Open - CurrentUnrealProject.bat
```
This will:
1. Compile Development Editor (if needed)
2. Open Rider with your project

### Option 2: Using Python Script Directly

**Generate project files and open:**
```bash
python UnrealProductivityUtils.py --generate-project-files
```

**Open without generating project files:**
```bash
python UnrealProductivityUtils.py
```

**Use a custom config file:**
```bash
python UnrealProductivityUtils.py --config path/to/custom-config.json
```

## Files

- `UnrealProductivityUtils.py` - Main Python script that handles project generation, compilation, and Rider opening
- `Generate and Open - CurrentUnrealProject.bat` - Batch file wrapper that generates project files before opening
- `Open - CurrentUnrealProject.bat` - Batch file wrapper that opens Rider without generating project files
- `config.json` - User-specific configuration file (gitignored, created on first run)

## Configuration

The `config.json` file contains:
```json
{
    "UnrealEnginePath": "path/to/UnrealEngine",
    "ProjectFile": "path/to/Project.uproject"
}
```

You can manually edit this file or let the script recreate it interactively.

## How It Works

1. **Configuration Loading**: The script checks for `config.json` and prompts for setup if missing
2. **Project File Generation** (optional): Runs `GenerateProjectFiles.bat` in your Unreal Engine directory
3. **Compilation**: Builds the Development Editor configuration using Unreal's build system
4. **Rider Detection**: Automatically finds Rider installation in common locations:
   - `%LOCALAPPDATA%\Programs\Rider\bin\rider64.exe`
   - `%ProgramFiles%\JetBrains\Rider\bin\rider64.exe`
   - `%ProgramFiles(x86)%\JetBrains\Rider\bin\rider64.exe`
   - User profile directory (`%USERPROFILE%\JetBrains Rider <version>\bin\rider64.exe`)
5. **Project Opening**: Launches Rider with your project file

## Troubleshooting

- **Rider not found**: Ensure Rider is installed in one of the standard locations, or the script will attempt to use the `rider` command from PATH
- **Build failures**: Check that your Unreal Engine path is correct and contains the build scripts
- **Config errors**: Delete `config.json` and let the script recreate it with correct paths

## License

This is a personal productivity tool. Use as you see fit.
