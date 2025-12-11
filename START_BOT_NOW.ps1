# ╔═════════════════════════════════════════════════════════════════════════════╗
# ║                                                                             ║
# ║                   🚀 QUICK START - BOT LAUNCH SCRIPT                       ║
# ║                    Ejecuta el bot con UN comando                            ║
# ║                                                                             ║
# ╚═════════════════════════════════════════════════════════════════════════════╝

param(
    [switch]$clean = $false,
    [switch]$verbose = $false,
    [string]$mode = "monitor"  # monitor, semi_auto, auto
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Success { Write-Host $args -ForegroundColor Green -BackgroundColor Black }
function Write-Error { Write-Host $args -ForegroundColor Red -BackgroundColor Black }
function Write-Warning { Write-Host $args -ForegroundColor Yellow -BackgroundColor Black }
function Write-Info { Write-Host $args -ForegroundColor Cyan -BackgroundColor Black }

Write-Host ""
Write-Host "╔═════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║                                                                             ║" -ForegroundColor Magenta
Write-Host "║                   🚀 QUICK START - BOT LAUNCH SCRIPT                       ║" -ForegroundColor Magenta
Write-Host "║                    Professional Trading Bot v1.0                           ║" -ForegroundColor Magenta
Write-Host "║                                                                             ║" -ForegroundColor Magenta
Write-Host "╚═════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# Step 1: Validate environment
Write-Info "════════════════════════════════════════════════════════════════"
Write-Info "STEP 1/5: VALIDATING ENVIRONMENT"
Write-Info "════════════════════════════════════════════════════════════════"

$pythonPath = (Get-Command python.exe -ErrorAction SilentlyContinue).Source
if (-not $pythonPath) {
    Write-Error "❌ Python not found in PATH"
    Write-Info "Please install Python 3.8+ or add it to PATH"
    exit 1
}

$pythonVersion = python.exe --version
Write-Success "✓ Python found: $pythonVersion"

# Check critical files
$requiredFiles = @(
    "config.json",
    "main.py", 
    "broker_capture.py",
    "LAUNCH_COMPLETE_BOT.py"
)

$missingFiles = @()
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Success "✓ Found: $file"
    } else {
        Write-Error "❌ Missing: $file"
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Error "Cannot proceed without required files: $($missingFiles -join ', ')"
    exit 1
}

# Step 2: Check Python packages
Write-Info ""
Write-Info "════════════════════════════════════════════════════════════════"
Write-Info "STEP 2/5: CHECKING PYTHON PACKAGES"
Write-Info "════════════════════════════════════════════════════════════════"

$requiredPackages = @("pandas", "numpy", "playwright", "flask", "sklearn")
$missingPackages = @()

foreach ($package in $requiredPackages) {
    $result = python.exe -c "import $package" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✓ $package installed"
    } else {
        Write-Warning "⚠️  $package missing"
        $missingPackages += $package
    }
}

if ($missingPackages.Count -gt 0) {
    Write-Warning "Installing missing packages..."
    Write-Info "Run: pip install -r requirements.txt"
    Write-Warning "Attempting to continue anyway..."
}

# Step 3: Validate configuration
Write-Info ""
Write-Info "════════════════════════════════════════════════════════════════"
Write-Info "STEP 3/5: VALIDATING CONFIGURATION"
Write-Info "════════════════════════════════════════════════════════════════"

if (Test-Path "config.json") {
    Write-Success "✓ config.json found"
    
    # Try to parse JSON
    try {
        $config = Get-Content "config.json" | ConvertFrom-Json
        Write-Success "✓ config.json is valid JSON"
        
        $broker = $config.broker
        $assets = $config.assets.Count
        $timeframes = $config.timeframes.Count
        
        Write-Success "  - Broker: $broker"
        Write-Success "  - Assets: $assets"
        Write-Success "  - Timeframes: $timeframes"
    } catch {
        Write-Error "❌ config.json is invalid: $_"
        exit 1
    }
}

# Step 4: Clean or start
Write-Info ""
Write-Info "════════════════════════════════════════════════════════════════"
Write-Info "STEP 4/5: CLEANUP & PREPARATION"
Write-Info "════════════════════════════════════════════════════════════════"

if ($clean) {
    Write-Warning "Cleaning up old files..."
    Remove-Item -Path "logs" -Recurse -ErrorAction SilentlyContinue | Out-Null
    Write-Success "✓ Old logs cleaned"
}

# Create logs directory
if (-not (Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" | Out-Null
    Write-Success "✓ Created logs directory"
}

# Step 5: Launch bot
Write-Info ""
Write-Info "════════════════════════════════════════════════════════════════"
Write-Info "STEP 5/5: LAUNCHING BOT"
Write-Info "════════════════════════════════════════════════════════════════"

Write-Success ""
Write-Success "🚀 Starting Trading Bot..."
Write-Success ""

# Run the integrated launcher
if ($verbose) {
    python.exe LAUNCH_COMPLETE_BOT.py
} else {
    python.exe LAUNCH_COMPLETE_BOT.py 2>&1 | Tee-Object -FilePath "logs/launch.log"
}

$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Success ""
    Write-Success "════════════════════════════════════════════════════════════════"
    Write-Success "✅ BOT LAUNCHED SUCCESSFULLY"
    Write-Success "════════════════════════════════════════════════════════════════"
    Write-Success ""
} else {
    Write-Error ""
    Write-Error "════════════════════════════════════════════════════════════════"
    Write-Error "❌ BOT LAUNCH FAILED"
    Write-Error "════════════════════════════════════════════════════════════════"
    Write-Error ""
    Write-Info "Check logs/launch.log for details"
}

exit $exitCode
