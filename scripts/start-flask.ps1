# scripts/start-flask.ps1
# Usage: run this from PowerShell. It locates a copied flask_app (in Main-Project-Trained\flask_app or flask_app),
# creates/uses a .venv inside the app folder, installs requirements, and runs the Flask server.

$ErrorActionPreference = 'Stop'

# Determine repository root (script is in <repo>/scripts)
# Use automatic $PSScriptRoot if available; otherwise derive from MyInvocation
$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) { $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$repoRoot = Split-Path -Parent $scriptRoot

# Candidate locations for the copied flask app (build each path separately)
$path1 = Join-Path -Path $repoRoot -ChildPath 'Main-Project-Trained\flask_app'
$path2 = Join-Path -Path $repoRoot -ChildPath 'flask_app'
$candidates = @($path1, $path2)

$appDir = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $appDir) {
    Write-Host "No flask_app directory found in expected locations:" -ForegroundColor Yellow
    foreach ($c in $candidates) { Write-Host "  - $c" }
    Write-Host "Please copy your flask_app into one of the above locations and re-run this script." -ForegroundColor Red
    exit 1
}

Write-Host "Using Flask app directory: $appDir" -ForegroundColor Green
Set-Location $appDir

# Prefer an existing .venv in the app dir, else fall back to system 'python' on PATH
$venvDir = Join-Path $appDir '.venv'
$venvPython = Join-Path $venvDir 'Scripts\python.exe'
$pythonCmd = $null
if (Test-Path $venvPython) {
    # Use the existing virtualenv's python if present
    $pythonCmd = $venvPython
    Write-Host "Found existing virtualenv python at $venvPython" -ForegroundColor Green
} else {
    # Fall back to system python on PATH
    $py = Get-Command python -ErrorAction SilentlyContinue
    if ($py) { $pythonCmd = $py.Source }
    else {
        # Fall back to the 'py' launcher (common on Windows) if present
        $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
        if ($pyLauncher) {
            $pythonCmd = $pyLauncher.Source
            Write-Host "Found 'py' launcher at $pythonCmd; will use 'py -3' to create venv if needed" -ForegroundColor Green
        }
    }
}

if (-not $pythonCmd) {
    Write-Host "Cannot find 'python' (neither system python nor .venv python). Install Python 3.8+ or create a .venv in the app folder." -ForegroundColor Red
    exit 1
}

# If no .venv exists, create it using the detected python
if (-not (Test-Path $venvDir)) {
    Write-Host "Creating virtual environment in $venvDir..."
    if ($pythonCmd -like '*\\py.exe') {
        & $pythonCmd -3 -m venv $venvDir
    } else {
        & $pythonCmd -m venv $venvDir
    }
}

# Ensure venv python path is set for later operations
$venvPython = Join-Path $venvDir 'Scripts\python.exe'
if (-not (Test-Path $venvPython)) {
    Write-Host "Virtualenv python not found at $venvPython" -ForegroundColor Red
    exit 1
}

# Upgrade pip and install requirements
Write-Host "Ensuring pip is up-to-date and installing requirements..."
& $venvPython -m pip install --upgrade pip setuptools wheel

$reqFile = if (Test-Path (Join-Path $appDir 'requirements-flask.txt')) { 'requirements-flask.txt' }
else { if (Test-Path (Join-Path $appDir 'requirements.txt')) { 'requirements.txt' } else { $null } }

if ($reqFile) {
    Write-Host "Installing from $reqFile..."
    & $venvPython -m pip install -r (Join-Path $appDir $reqFile)
} else {
    Write-Host "No requirements file found, installing Flask as a fallback..."
    & $venvPython -m pip install flask
}

# Find application entry file
$entryCandidates = @('app.py','run.py','wsgi.py')
$entry = $null
foreach ($c in $entryCandidates) {
    if (Test-Path (Join-Path $appDir $c)) { $entry = $c; break }
}
if (-not $entry) {
    if (Test-Path (Join-Path $appDir 'app\__init__.py')) { $entry = 'app' }
}
if (-not $entry) {
    Write-Host 'Could not find common Flask entry file (app.py/run.py/wsgi.py or app/__init__.py).' -ForegroundColor Yellow
    Write-Host "Defaulting to 'app.py' - if your entry is different, set FLASK_APP manually or create app.py." -ForegroundColor Yellow
    $entry = 'app.py'
}

# Start Flask using venv Python to ensure the venv environment is used
$msg = "Starting Flask app using entry '{0}'..." -f $entry
Write-Host $msg -ForegroundColor Green
$env:FLASK_APP = $entry
$env:FLASK_ENV = 'development'

# Run Flask with the venv python -m flask to avoid relying on external PATH
& $venvPython -m flask run --host=127.0.0.1 --port=5000

# End of script
