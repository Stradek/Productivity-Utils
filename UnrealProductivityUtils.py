#!/usr/bin/env python3
"""
Open Unreal Engine project in Rider after optionally generating project files and compiling.
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


class Colors:
    """ANSI color codes for terminal output."""
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    RESET = '\033[0m'


def print_colored(message, color=Colors.RESET):
    """Print a colored message."""
    print(f"{color}{message}{Colors.RESET}")


def create_config_interactive(config_path):
    """Create config file by prompting user for values."""
    print_colored("Config file not found. Let's create one!", Colors.CYAN)
    print_colored("Please provide the following information:\n", Colors.CYAN)
    
    # Get Unreal Engine path
    unreal_engine_path = input("Enter Unreal Engine repository path: ").strip()
    if not unreal_engine_path:
        print_colored("Error: Unreal Engine path cannot be empty.", Colors.RED)
        sys.exit(1)
    
    # Get project file path
    project_file = input("Enter path to .sln or .uproject file: ").strip()
    if not project_file:
        print_colored("Error: Project file path cannot be empty.", Colors.RED)
        sys.exit(1)
    
    # Create config dictionary
    config = {
        "UnrealEnginePath": unreal_engine_path,
        "ProjectFile": project_file
    }
    
    # Save config file
    try:
        with open(config_path, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=4)
        print_colored(f"\nConfig file created successfully at {config_path}!", Colors.GREEN)
        return config
    except Exception as e:
        print_colored(f"Error creating config file: {e}", Colors.RED)
        sys.exit(1)


def load_config(config_path):
    """Load configuration from JSON file, or create one if it doesn't exist."""
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            config = json.load(f)
        
        # Validate that required keys exist
        if 'UnrealEnginePath' not in config or 'ProjectFile' not in config:
            print_colored("Warning: Config file is missing required fields. Recreating...", Colors.YELLOW)
            return create_config_interactive(config_path)
        
        return config
    except FileNotFoundError:
        return create_config_interactive(config_path)
    except json.JSONDecodeError as e:
        print_colored(f"Error: Invalid JSON in config file: {e}", Colors.RED)
        print_colored("Recreating config file...", Colors.YELLOW)
        return create_config_interactive(config_path)


def find_rider_executable():
    """Find Rider executable in common installation locations."""
    rider_paths = [
        os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Programs', 'Rider', 'bin', 'rider64.exe'),
        os.path.join(os.environ.get('ProgramFiles', ''), 'JetBrains', 'Rider', 'bin', 'rider64.exe'),
        os.path.join(os.environ.get('ProgramFiles(x86)', ''), 'JetBrains', 'Rider', 'bin', 'rider64.exe'),
    ]
    
    # Check user's home directory for JetBrains Rider installations
    # Pattern: %USERPROFILE%\JetBrains Rider <version>\bin\rider64.exe
    user_profile = os.environ.get('USERPROFILE', '')
    if user_profile:
        try:
            # Look for folders matching "JetBrains Rider*" in user profile
            for item in os.listdir(user_profile):
                if item.startswith('JetBrains Rider'):
                    rider_dir = os.path.join(user_profile, item)
                    if os.path.isdir(rider_dir):
                        rider_exe = os.path.join(rider_dir, 'bin', 'rider64.exe')
                        if os.path.exists(rider_exe):
                            rider_paths.append(rider_exe)
        except (OSError, PermissionError):
            pass
    
    for path in rider_paths:
        if os.path.exists(path):
            return path
    return None


def run_command(command, args=None, cwd=None):
    """Run a command and return the exit code."""
    cmd = [command]
    if args:
        cmd.extend(args)
    
    try:
        result = subprocess.run(cmd, cwd=cwd, check=False)
        return result.returncode
    except Exception as e:
        print_colored(f"Error running command: {e}", Colors.RED)
        return 1


def main():
    parser = argparse.ArgumentParser(description='Open Unreal Engine project in Rider')
    parser.add_argument('--generate-project-files', action='store_true',
                        help='Generate project files before opening Rider')
    parser.add_argument('--config', type=str, default='config.json',
                        help='Path to config JSON file (default: config.json)')
    
    args = parser.parse_args()
    
    # Load configuration
    script_dir = Path(__file__).parent
    config_path = script_dir / args.config
    config = load_config(config_path)
    
    unreal_engine_path = Path(config['UnrealEnginePath']).resolve()
    project_file = Path(config['ProjectFile']).resolve()
    
    if not unreal_engine_path.exists():
        print_colored(f"Error: Unreal Engine path does not exist: {unreal_engine_path}", Colors.RED)
        sys.exit(1)
    
    if not project_file.exists():
        print_colored(f"Error: Project file does not exist: {project_file}", Colors.RED)
        sys.exit(1)
    
    should_open_rider = True
    compilation_failed = False
    
    try:
        # Run GenerateProjectFiles.bat if requested
        if args.generate_project_files:
            print_colored("Running GenerateProjectFiles.bat...", Colors.CYAN)
            
            generate_bat = unreal_engine_path / "GenerateProjectFiles.bat"
            if not generate_bat.exists():
                print_colored(f"Error: GenerateProjectFiles.bat not found at {generate_bat}", Colors.RED)
                sys.exit(1)
            
            exit_code = run_command(str(generate_bat), cwd=str(unreal_engine_path))
            
            if exit_code != 0:
                print_colored(f"GenerateProjectFiles.bat failed with exit code: {exit_code}", Colors.RED)
                should_open_rider = False
                sys.exit(exit_code)
            else:
                print_colored("GenerateProjectFiles.bat completed successfully!", Colors.GREEN)
        
        # Compile Development Editor
        if should_open_rider:
            print_colored("Compiling Development Editor...", Colors.CYAN)
            
            project_name = project_file.stem
            build_bat = unreal_engine_path / "Engine" / "Build" / "BatchFiles" / "Build.bat"
            
            if build_bat.exists():
                # Build command: Build.bat <ProjectName>Editor Win64 Development <ProjectPath>
                build_args = [
                    f"{project_name}Editor",
                    "Win64",
                    "Development",
                    str(project_file)
                ]
                
                exit_code = run_command(str(build_bat), args=build_args, cwd=str(unreal_engine_path))
                
                if exit_code != 0:
                    print_colored(f"Warning: Compilation failed with exit code: {exit_code}", Colors.YELLOW)
                    print_colored("Opening Rider anyway...", Colors.YELLOW)
                    compilation_failed = True
                else:
                    print_colored("Compilation completed successfully!", Colors.GREEN)
            else:
                print_colored(f"Warning: Build.bat not found at {build_bat}. Skipping compilation.", Colors.YELLOW)
                print_colored(f"Current directory: {os.getcwd()}", Colors.YELLOW)
                print_colored(f"UnrealEnginePath: {unreal_engine_path}", Colors.YELLOW)
        
        # Open Rider with the project file
        if should_open_rider:
            print_colored(f"Opening Rider with project file: {project_file}", Colors.CYAN)
            
            rider_exe = find_rider_executable()
            
            if rider_exe:
                try:
                    subprocess.Popen([rider_exe, str(project_file)])
                    print_colored("Rider opened successfully!", Colors.GREEN)
                except Exception as e:
                    print_colored(f"Error opening Rider: {e}", Colors.RED)
                    compilation_failed = True
            else:
                print_colored("Rider executable not found. Attempting to open with 'rider' command...", Colors.YELLOW)
                try:
                    subprocess.Popen(['rider', str(project_file)])
                    print_colored("Rider opened successfully!", Colors.GREEN)
                except Exception as e:
                    print_colored("Error: Could not find Rider. Please update the script with the correct Rider path.", Colors.RED)
                    print_colored(f"Error details: {e}", Colors.RED)
                    compilation_failed = True
    
    except Exception as e:
        print_colored(f"Error: {e}", Colors.RED)
        compilation_failed = True
    
    # Pause console if compilation failed, otherwise exit normally
    if compilation_failed:
        print_colored("\nPress any key to exit...", Colors.YELLOW)
        try:
            input()
        except (EOFError, KeyboardInterrupt):
            pass


if __name__ == '__main__':
    main()
