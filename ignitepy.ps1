<#
.SYNOPSIS
    ignitepy - scaffold a Python project that gives AI coding agents fast feedback.

.DESCRIPTION
    Windows (PowerShell) port of the ignitepy bash script.
    Based on Real Python's "How to Set Up a Python Project for Agentic Coding":
    https://realpython.com/python-project-for-agentic-coding/

    Works in Windows PowerShell 5.1 and PowerShell 7+.
    Requires: uv, git.

.EXAMPLE
    .\ignitepy.ps1 my-app
    .\ignitepy.ps1 my-app claude
    .\ignitepy.ps1 my-app copilot 85 3.13
    .\ignitepy.ps1 my-app both 90 -
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $Name = '',
    [Parameter(Position = 1)] [string] $Agent = 'both',
    [Parameter(Position = 2)] [string] $Coverage = '90',
    [Parameter(Position = 3)] [string] $PyVersion = '-',
    [Alias('h')] [switch] $Help
)

$ErrorActionPreference = 'Stop'

function Show-Usage {
@'
ignitepy - set up a Python project for Claude Code and/or GitHub Copilot

USAGE
  ignitepy <name> [agent] [coverage] [pyversion]

ARGUMENTS
  name       Project name (letters, digits, - and _). Creates .\<name>\
  agent      claude | copilot | both            (default: both)
  coverage   Minimum test coverage in percent   (default: 90)
  pyversion  Python version, e.g. 3.13          (default: uv's default; "-" to skip)

EXAMPLES
  ignitepy my-app
  ignitepy my-app claude
  ignitepy my-app copilot 85 3.13
  ignitepy my-app both 90 -

WHAT IT CREATES
  uv project (src layout) + Git repo, Ruff, mypy (strict), pytest with a
  coverage gate, pre-commit hooks, AGENTS.md, .env.example, and:
    claude  -> CLAUDE.md (imports @AGENTS.md) + .claude\settings.json
    copilot -> .github\copilot-instructions.md

NOTES
  Non-interactive when all arguments are given, so a coding agent can run it.
  Requires: uv, git. Exit code is non-zero on any failure.
'@
}

function Fail([string] $Message) {
    throw "ignitepy: error: $Message"
}

# Run a native command and stop the script if it returns a non-zero exit code
# (PowerShell does not do this on its own for external programs).
function Exec {
    $cmd = $args[0]
    $rest = if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { @() }
    & $cmd @rest
    if ($LASTEXITCODE -ne 0) {
        Fail "'$cmd $($rest -join ' ')' failed with exit code $LASTEXITCODE"
    }
}

# Same as Exec, but returns the command's output.
function ExecOutput {
    $cmd = $args[0]
    $rest = if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { @() }
    $out = & $cmd @rest
    if ($LASTEXITCODE -ne 0) {
        Fail "'$cmd $($rest -join ' ')' failed with exit code $LASTEXITCODE"
    }
    return ($out | Out-String).Trim()
}

# Write UTF-8 (no BOM) with LF line endings, like the bash version does.
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Text([string] $Path, [string] $Text, [switch] $Append) {
    $full = [System.IO.Path]::GetFullPath((Join-Path $PWD.Path $Path))
    $Text = $Text -replace "`r`n", "`n"
    if (-not $Text.EndsWith("`n")) { $Text += "`n" }
    if ($Append) {
        [System.IO.File]::AppendAllText($full, $Text, $Utf8NoBom)
    } else {
        [System.IO.File]::WriteAllText($full, $Text, $Utf8NoBom)
    }
}

function Main {
    if ($Help -or $Name -in @('-h', '--help', 'help')) {
        Show-Usage
        return 0
    }

    # --- Arguments (prompt for the name only if missing and a terminal is attached)
    if (-not $Name) {
        if (-not [Console]::IsInputRedirected) {
            $Name = Read-Host 'Project name'
        } else {
            [Console]::Error.WriteLine((Show-Usage | Out-String))
            return 2
        }
    }
    $pyversion = if ($PyVersion -eq '-') { '' } else { $PyVersion }

    # --- Validation
    if ($Name -notmatch '^[A-Za-z][A-Za-z0-9_-]*$') {
        Fail "invalid name '$Name' (use letters, digits, - and _; start with a letter)"
    }
    if ($Agent -notin @('claude', 'copilot', 'both')) {
        Fail "agent must be claude, copilot or both (got '$Agent')"
    }
    if ($Coverage -notmatch '^[0-9]+$' -or [int]$Coverage -gt 100) {
        Fail "coverage must be an integer from 0 to 100 (got '$Coverage')"
    }
    if ($pyversion -and $pyversion -notmatch '^[0-9]+\.[0-9]+$') {
        Fail "pyversion must look like 3.13 (got '$pyversion')"
    }
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Fail 'uv not found. Install it: https://docs.astral.sh/uv/#installation'
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Fail 'git not found'
    }
    if (Test-Path -LiteralPath $Name) {
        Fail "'$Name' already exists in $($PWD.Path)"
    }

    $pyLabel = if ($pyversion) { $pyversion } else { 'default' }
    Write-Host "> Creating $Name (agent=$Agent, coverage=$Coverage%, python=$pyLabel)"

    # --- Project scaffold
    $initArgs = @('init', '--no-workspace', '--package')
    if ($pyversion) { $initArgs += @('--python', $pyversion) }
    $initArgs += $Name
    Exec uv @initArgs
    Set-Location -LiteralPath $Name

    # If a parent folder holds a pyproject.toml (e.g. in your user profile), uv may
    # treat this project as one of its workspace members. Make the project its own
    # workspace root so it stays fully standalone.
    $d = Split-Path -Parent $PWD.Path
    while ($d) {
        if (Test-Path -LiteralPath (Join-Path $d 'pyproject.toml')) {
            Write-Text 'pyproject.toml' @'

# Standalone project: ignore any parent workspace
[tool.uv.workspace]
members = []
'@ -Append
            Write-Host "[i] Found $d\pyproject.toml, isolating the project from it"
            break
        }
        $d = Split-Path -Parent $d
    }

    # Pin the Python version inside the project so a stray .python-version or
    # pyproject.toml in a parent folder is never used
    if ($pyversion) {
        Exec uv python pin $pyversion
    } elseif (-not (Test-Path -LiteralPath '.python-version')) {
        $toml = [System.IO.File]::ReadAllText((Join-Path $PWD.Path 'pyproject.toml'))
        if ($toml -match 'requires-python\s*=\s*">=([0-9]+\.[0-9]+)') {
            Exec uv python pin $Matches[1]
        }
    }
    Exec uv add --dev ruff mypy pytest pytest-cov pre-commit

    # Drop the generated CLI entry point; we replace main() with a testable function
    $pyprojectPath = Join-Path $PWD.Path 'pyproject.toml'
    $toml = [System.IO.File]::ReadAllText($pyprojectPath)
    $toml = [regex]::Replace($toml, '(?m)^\[project\.scripts\]\r?\n(?:[^\r\n]+\r?\n)*(?:\r?\n)?', '')
    [System.IO.File]::WriteAllText($pyprojectPath, $toml, $Utf8NoBom)

    $pkg = (Get-ChildItem -LiteralPath 'src' -Directory |
        Where-Object { $_.Name -notlike '__*' -and $_.Name -notlike '*.egg-info' } |
        Select-Object -First 1).Name
    if (-not $pkg) { Fail 'could not find the package folder under src\' }

    Write-Text "src\$pkg\__init__.py" @'
def double(value: int) -> int:
    return value * 2
'@

    New-Item -ItemType Directory -Force -Path 'tests' | Out-Null
    Write-Text 'tests\test_main.py' @"
from $pkg import double


def test_double_returns_twice_the_input() -> None:
    assert double(4) == 8
"@

    # --- Tool configuration
    Write-Text 'pyproject.toml' @"

[tool.ruff]
line-length = 80

[tool.ruff.lint]
extend-select = ["I"]  # Sort imports

[tool.mypy]
strict = true

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "--cov=src --cov-report=term-missing --cov-fail-under=$Coverage"
"@ -Append

    $ruffV = (ExecOutput uv run ruff --version) -split '\s+' | Select-Object -Index 1
    $mypyV = (ExecOutput uv run mypy --version) -split '\s+' | Select-Object -Index 1
    Write-Text '.pre-commit-config.yaml' @"
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v$ruffV
    hooks:
      - id: ruff-check
      - id: ruff-format
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v$mypyV
    hooks:
      - id: mypy
"@

    # --- Agent instructions
    Write-Text 'AGENTS.md' @'
# AGENTS.md

## Development workflow

- This project is typed. Run mypy after adding or modifying code:
  - `uv run mypy .`
- Use Ruff for formatting and linting:
  - `uv run ruff format .`
  - `uv run ruff check .`
- Run the full test suite after modifying code:
  - `uv run pytest`
- Add or update tests when changing behavior.
- Before committing, run:
  - `uv run pre-commit run --all-files`
- Prefer small, focused functions.

## Documentation

- Update documentation when public behavior changes.
'@

    if ($Agent -ne 'copilot') {
        Write-Text 'CLAUDE.md' '@AGENTS.md'
        New-Item -ItemType Directory -Force -Path '.claude' | Out-Null
        Write-Text '.claude\settings.json' @'
{
  "permissions": {
    "deny": ["Read(./.env)"]
  }
}
'@
    }

    if ($Agent -ne 'claude') {
        New-Item -ItemType Directory -Force -Path '.github' | Out-Null
        Copy-Item -LiteralPath 'AGENTS.md' -Destination '.github\copilot-instructions.md'
    }

    # --- Secrets
    Write-Text '.gitignore' @'

# Environment variables
.env
'@ -Append
    Write-Text '.env.example' @'
# Copy this file to .env and fill in the values your project needs.
# .env is git-ignored, so real secrets never reach the repository.
API_KEY=your-api-key-here
'@

    # --- Verify, install hooks, commit
    Exec uv run ruff check --fix
    Exec uv run ruff format
    Exec uv run pre-commit install
    Exec uv run pytest -q
    Exec git add .
    Exec git commit -qm 'Initial agent-ready scaffold'

    Write-Host "[ok] $Name is ready. Next: cd $Name"
    return 0
}

try {
    $code = Main
    exit $code
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
