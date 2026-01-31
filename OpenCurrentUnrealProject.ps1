# Parameters
param(
    [switch]$GenerateProjectFiles
)

# Variables
$UnrealEnginePath = "D:\Programming\Repositories\UnrealEngine"
$ProjectFile = "D:\Programming\Repositories\UnrealEngine\ThirdPersonSandbox\ThirdPersonSandbox.uproject"  # or .uproject file

Push-Location $UnrealEnginePath

try {
    $shouldOpenRider = $true
    
    # Run GenerateProjectFiles.bat if requested
    if ($GenerateProjectFiles) {
        Write-Host "Running GenerateProjectFiles.bat..." -ForegroundColor Cyan
        
        & ".\GenerateProjectFiles.bat"
        
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            Write-Host "GenerateProjectFiles.bat failed with exit code: $LASTEXITCODE" -ForegroundColor Red
            $shouldOpenRider = $false
            exit $LASTEXITCODE
        } else {
            Write-Host "GenerateProjectFiles.bat completed successfully!" -ForegroundColor Green
        }
    }
    
    # Compile Development Editor
    if ($shouldOpenRider) {
        Write-Host "Compiling Development Editor..." -ForegroundColor Cyan
        
        # Get absolute path to project file
        $projectFullPath = (Resolve-Path $ProjectFile -ErrorAction Stop).Path
        $projectName = [System.IO.Path]::GetFileNameWithoutExtension($projectFullPath)
        
        # Get absolute path to Unreal Engine directory
        $unrealEngineFullPath = (Resolve-Path $UnrealEnginePath -ErrorAction Stop).Path
        
        # Find Build.bat in Unreal Engine directory
        $buildBat = Join-Path $unrealEngineFullPath "Engine\Build\BatchFiles\Build.bat"
        
        if (Test-Path $buildBat) {
            # Build command: Build.bat <ProjectName>Editor Win64 Development <ProjectPath>
            & $buildBat "${projectName}Editor" "Win64" "Development" $projectFullPath
            
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
                Write-Host "Compilation failed with exit code: $LASTEXITCODE" -ForegroundColor Red
                $shouldOpenRider = $false
                exit $LASTEXITCODE
            } else {
                Write-Host "Compilation completed successfully!" -ForegroundColor Green
            }
        } else {
            Write-Host "Warning: Build.bat not found at $buildBat. Skipping compilation." -ForegroundColor Yellow
            Write-Host "Current directory: $(Get-Location)" -ForegroundColor Yellow
            Write-Host "UnrealEnginePath: $unrealEngineFullPath" -ForegroundColor Yellow
        }
    }
    
    # Open Rider with the project file
    if ($shouldOpenRider) {
        # Get absolute path to project file if not already done
        if (-not (Test-Path variable:projectFullPath)) {
            $projectFullPath = (Resolve-Path $ProjectFile -ErrorAction Stop).Path
        }
        
        Write-Host "Opening Rider with project file: $projectFullPath" -ForegroundColor Cyan
        
        # Try to find Rider executable
        $riderExe = "rider64"
        if ($riderExe) {
            Start-Process -FilePath $riderExe -ArgumentList $projectFullPath
            Write-Host "Rider opened successfully!" -ForegroundColor Green
        } else {
            Write-Host "Rider executable not found. Attempting to open with 'rider' command..." -ForegroundColor Yellow
            try {
                Start-Process -FilePath "rider" -ArgumentList $projectFullPath -ErrorAction Stop
                Write-Host "Rider opened successfully!" -ForegroundColor Green
            } catch {
                Write-Host "Error: Could not find Rider. Please update the script with the correct Rider path." -ForegroundColor Red
                Write-Host "Error details: $_" -ForegroundColor Red
                exit 1
            }
        }
    }
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}
