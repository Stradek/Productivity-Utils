# PowerShell script to package Unreal Engine game using UAT
# Usage: .\PackageGame.ps1 [-ArchiveDirectory <path>] [-NoPause]
# Reads project configuration from config.json

param(
    [string]$ArchiveDirectory = "",
    [switch]$NoPause
)

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Load config.json
$ConfigPath = Join-Path $ScriptDir "config.json"
if (-not (Test-Path $ConfigPath)) {
    Write-Error "config.json not found at: $ConfigPath"
    exit 1
}

try {
    $Config = Get-Content $ConfigPath | ConvertFrom-Json
}
catch {
    Write-Error "Failed to parse config.json: $_"
    exit 1
}

# Validate required config fields
$RequiredFields = @("UnrealEnginePath", "ProjectFile", "ProjectName", "TargetPlatform", "BuildConfiguration")
foreach ($Field in $RequiredFields) {
    if (-not $Config.$Field) {
        Write-Error "Missing required field in config.json: $Field"
        exit 1
    }
}

$UnrealEnginePath = $Config.UnrealEnginePath
$ProjectFile = $Config.ProjectFile
$ProjectName = $Config.ProjectName
$TargetPlatform = $Config.TargetPlatform
$BuildConfiguration = $Config.BuildConfiguration

# Validate paths
if (-not (Test-Path $UnrealEnginePath)) {
    Write-Error "Unreal Engine path not found: $UnrealEnginePath"
    exit 1
}

if (-not (Test-Path $ProjectFile)) {
    Write-Error "Project file not found: $ProjectFile"
    exit 1
}

# Set default archive directory if not provided
if (-not $ArchiveDirectory) {
    if ($Config.ArchiveDirectory) {
        $ArchiveDirectory = $Config.ArchiveDirectory
    }
    else {
        # Default to project directory/Packaged/Platform/Config
        $ProjectDir = Split-Path -Parent $ProjectFile
        $ArchiveDirectory = Join-Path $ProjectDir "Packaged\$TargetPlatform\$BuildConfiguration"
    }
}

# Ensure archive directory exists
$ArchiveDirParent = Split-Path -Parent $ArchiveDirectory
if ($ArchiveDirParent -and -not (Test-Path $ArchiveDirParent)) {
    New-Item -ItemType Directory -Path $ArchiveDirParent -Force | Out-Null
}

# Get RunUAT.bat path
$RunUATPath = Join-Path $UnrealEnginePath "Engine\Build\BatchFiles\RunUAT.bat"

if (-not (Test-Path $RunUATPath)) {
    Write-Error "RunUAT.bat not found at: $RunUATPath"
    exit 1
}

# Convert project file path to relative path from engine root (UAT prefers relative paths)
$ProjectRelativePath = $ProjectFile
if ($ProjectFile.StartsWith($UnrealEnginePath)) {
    $ProjectRelativePath = $ProjectFile.Substring($UnrealEnginePath.Length).TrimStart('\', '/')
    $ProjectRelativePath = "./$ProjectRelativePath"
}

# Convert archive directory to relative path
$ArchiveRelativePath = $ArchiveDirectory
if ($ArchiveDirectory.StartsWith($UnrealEnginePath)) {
    $ArchiveRelativePath = $ArchiveDirectory.Substring($UnrealEnginePath.Length).TrimStart('\', '/')
    $ArchiveRelativePath = "./$ArchiveRelativePath"
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Packaging $ProjectName for $TargetPlatform" -ForegroundColor Cyan
Write-Host "Configuration: $BuildConfiguration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project: $ProjectFile" -ForegroundColor Yellow
Write-Host "Archive Directory: $ArchiveDirectory" -ForegroundColor Yellow
Write-Host ""

# Build UAT command
$UATArgs = @(
    "BuildCookRun",
    "-nop4",
    "-project=$ProjectRelativePath",
    "-targetplatform=$TargetPlatform",
    "-target=$ProjectName",
    "-clientconfig=$BuildConfiguration",
    "-build",
    "-cook",
    "-stage",
    "-archive",
    "-archivedirectory=$ArchiveRelativePath",
    "-package",
    "-compressed",
    "-pak",
    "-prereqs",
    "-utf8output",
    "-compile"
)

Write-Host "Running UAT BuildCookRun..." -ForegroundColor Green
Write-Host "Command: $RunUATPath $($UATArgs -join ' ')" -ForegroundColor Gray
Write-Host ""

# Change to engine root directory
Push-Location $UnrealEnginePath

try {
    # Collections to store errors and warnings
    $Errors = @()
    $Warnings = @()
    $OutputLines = @()
    
    # Run UAT and capture all output
    # Use & operator to execute and capture both stdout and stderr
    $AllOutput = @()
    
    # Execute command and capture all output (both stdout and stderr)
    & $RunUATPath $UATArgs 2>&1 | ForEach-Object {
        $line = $_.ToString()
        $OutputLines += $line
        $AllOutput += $line
        
        # Display output in real-time
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            Write-Host $line -ForegroundColor Red
        }
        else {
            Write-Host $line
        }
    }
    
    $ExitCode = $LASTEXITCODE
    
    # Parse all output lines for errors and warnings
    foreach ($line in $OutputLines) {
        # Parse for errors (LogXXX: Error: or LogXXX:Display: Error:)
        if ($line -match "Log\w+:\s*(?:Display:\s*)?Error:\s*(.+)") {
            # Extract the actual error line (remove "LogInit: Display: " prefix if present)
            $errorLine = $line -replace "^Log\w+:\s*Display:\s*", ""
            if ($Errors -notcontains $errorLine -and $Errors -notcontains $line) {
                $Errors += $errorLine
            }
        }
        # Parse for warnings (LogXXX: Warning: or LogXXX:Display: Warning:)
        elseif ($line -match "Log\w+:\s*(?:Display:\s*)?Warning:\s*(.+)") {
            # Extract the actual warning line (remove "LogInit: Display: " prefix if present)
            $warningLine = $line -replace "^Log\w+:\s*Display:\s*", ""
            if ($Warnings -notcontains $warningLine -and $Warnings -notcontains $line) {
                $Warnings += $warningLine
            }
        }
    }
    
    # Also parse the summary section specifically for unique errors/warnings
    $FullOutput = $OutputLines -join "`n"
    if ($FullOutput -match "(?s)Warning/Error Summary.*?Failure - (\d+) error\(s\), (\d+) warning\(s\)") {
        $ErrorCount = [int]$Matches[1]
        $WarningCount = [int]$Matches[2]
        
        # Extract the summary section - look for lines between "Warning/Error Summary" and "Failure -"
        $SummaryStart = -1
        $SummaryEnd = -1
        for ($i = 0; $i -lt $OutputLines.Count; $i++) {
            if ($OutputLines[$i] -match "Warning/Error Summary") {
                $SummaryStart = $i
            }
            if ($SummaryStart -ge 0 -and $OutputLines[$i] -match "Failure - \d+ error\(s\), \d+ warning\(s\)") {
                $SummaryEnd = $i
                break
            }
        }
        
        if ($SummaryStart -ge 0 -and $SummaryEnd -ge 0) {
            # Extract errors and warnings from summary section (these are the unique ones)
            for ($i = $SummaryStart; $i -le $SummaryEnd; $i++) {
                $line = $OutputLines[$i]
                # Skip separator lines and summary header lines
                if ($line -match "^-+$" -or $line -match "Warning/Error Summary" -or $line -match "Failure -" -or $line.Trim() -eq "") {
                    continue
                }
                # Match errors: can be "LogXXX: Error:" or "LogXXX: Display: LogYYY: Error:"
                if ($line -match "Log\w+:\s*(?:Display:\s*)?(?:Log\w+:\s*)?Error:\s*(.+)") {
                    # Extract the actual error line (remove "LogInit: Display: " prefix if present)
                    $errorLine = $line -replace "^Log\w+:\s*Display:\s*", ""
                    if ($Errors -notcontains $errorLine -and $Errors -notcontains $line) {
                        $Errors += $errorLine
                    }
                }
                # Match warnings: can be "LogXXX: Warning:" or "LogXXX: Display: LogYYY: Warning:"
                elseif ($line -match "Log\w+:\s*(?:Display:\s*)?(?:Log\w+:\s*)?Warning:\s*(.+)") {
                    # Extract the actual warning line (remove "LogInit: Display: " prefix if present)
                    $warningLine = $line -replace "^Log\w+:\s*Display:\s*", ""
                    if ($Warnings -notcontains $warningLine -and $Warnings -notcontains $line) {
                        $Warnings += $warningLine
                    }
                }
            }
        }
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Build Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    if ($ExitCode -eq 0) {
        Write-Host "Status: SUCCESS" -ForegroundColor Green
        Write-Host "Package location: $ArchiveDirectory" -ForegroundColor Green
    }
    else {
        Write-Host "Status: FAILED" -ForegroundColor Red
        Write-Host "Exit Code: $ExitCode" -ForegroundColor Red
    }
    
    # Display errors and warnings
    if ($Errors.Count -gt 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "ERRORS ($($Errors.Count))" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        foreach ($error in $Errors) {
            Write-Host $error -ForegroundColor Red
        }
    }
    
    if ($Warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "WARNINGS ($($Warnings.Count))" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        foreach ($warning in $Warnings) {
            Write-Host $warning -ForegroundColor Yellow
        }
    }
    
    if ($Errors.Count -eq 0 -and $Warnings.Count -eq 0) {
        Write-Host ""
        Write-Host "No errors or warnings found in output." -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    
    if (-not $NoPause) {
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    
    exit $ExitCode
}
catch {
    Write-Error "Failed to run UAT: $_"
    exit 1
}
finally {
    Pop-Location
}
