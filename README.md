# ignitepy

Set up a Python project for AI coding agents with a single command.

`ignitepy` creates a ready-to-go Python project where Claude Code and GitHub Copilot get fast, automatic feedback: type checking, linting, formatting, tests and coverage. It also writes the instruction files each agent reads, so they know how to work in your project from the first prompt.

```bash
ignitepy my-app claude 90 3.13
```

The setup follows the ideas from the Real Python article [How to Set Up a Python Project for Agentic Coding](https://realpython.com/python-project-for-agentic-coding/).

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/nippotam/ignitepy/main/install.sh | bash
```

Prefer to inspect it first? Clone the repo and run the installer:

```bash
git clone https://github.com/nippotam/ignitepy.git
cd ignitepy
./install.sh
```

The installer copies `ignitepy` to `~/.local/bin`, adds that folder to your `PATH` if needed, and warns you if `uv` or `git` is missing. Open a new terminal afterwards, or run the `source` command it prints.

### Requirements

- macOS, Linux, or Windows with WSL or Git Bash
- [uv](https://docs.astral.sh/uv/#installation)
- [git](https://git-scm.com/downloads)

Tested on macOS 27.

## Usage

```bash
ignitepy <name> [agent] [coverage] [pyversion]
```

| Argument | Description | Default |
|---|---|---|
| `name` | Project name (letters, digits, `-` and `_`). Creates `./<name>/` in the current folder. | required |
| `agent` | `claude`, `copilot` or `both` | `both` |
| `coverage` | Minimum test coverage in percent | `90` |
| `pyversion` | Python version, for example `3.13`. Use `-` to keep uv's default. | uv's default |

### Examples

```bash
ignitepy my-app                    # both agents, 90% coverage, default Python
ignitepy my-app claude             # Claude Code only
ignitepy my-app copilot 85 3.13    # Copilot only, 85% coverage, Python 3.13
ignitepy my-app both 90 -          # skip an argument with "-"
```

Run `ignitepy --help` at any time to see the usage.

## What you get

```
my-app/
├── .claude/settings.json            # claude, both: blocks reading .env
├── .github/copilot-instructions.md  # copilot, both
├── .env.example
├── .gitignore                       # includes .env
├── .pre-commit-config.yaml
├── .python-version
├── AGENTS.md                        # shared instructions for agents
├── CLAUDE.md                        # claude, both: imports @AGENTS.md
├── README.md
├── pyproject.toml
├── uv.lock
├── src/my_app/__init__.py
└── tests/test_main.py
```

- **Project**: a [uv](https://docs.astral.sh/uv/) project with a `src/` layout and a Git repository, with the first commit already made
- **Type checking**: mypy in strict mode
- **Linting and formatting**: Ruff, including import sorting
- **Tests**: pytest with pytest-cov, failing below the coverage threshold you chose
- **Pre-commit hooks**: Ruff and mypy run on every commit, pinned to the installed versions
- **Agent instructions**: `AGENTS.md` lists the commands agents should run after changing code. `CLAUDE.md` imports it for Claude Code. `.github/copilot-instructions.md` is a copy for Copilot, so update both if you edit one.
- **Secrets**: `.env` is git-ignored and Claude Code is configured not to read it. Use `.env.example` to document the variables your project needs.

The generated project includes one sample function and one test so everything passes out of the box. Replace them with your own code.

## Using ignitepy with a coding agent

`ignitepy` is non-interactive when you give it all its arguments, prints clear one-line errors, and exits with a non-zero code on failure. That makes it easy for Claude Code or Copilot to run for you. For example, you can ask your agent:

> Run `ignitepy --help`, then create a project called `my-app` for Claude Code with 90% coverage and Python 3.13.

## Update and uninstall

Update by running the install command again. To remove `ignitepy`:

```bash
curl -fsSL https://raw.githubusercontent.com/nippotam/ignitepy/main/install.sh | bash -s -- --uninstall
```

The `--uninstall` flag removes the command. It does not touch your `PATH` setting or any project you created.

### Installer options

| Option or variable | Effect |
|---|---|
| `--no-path` | Don't edit your shell config; print the line to add yourself |
| `--uninstall` | Remove `ignitepy` |
| `IGNITEPY_INSTALL_DIR` | Install somewhere other than `~/.local/bin` |
| `IGNITEPY_BRANCH` | Install from a branch other than `main` |
| `IGNITEPY_REPO` | Install from a fork, as `user/name` |
| `IGNITEPY_URL` | Full URL of the script, overrides repo and branch |

## Troubleshooting

**`command not found: ignitepy`**
The install folder isn't on your `PATH` yet. Open a new terminal, or run `source ~/.zshrc` (macOS default shell). To check, run `echo $PATH | tr ':' '\n' | grep local/bin`.

**`permission denied: ignitepy`**
The file isn't executable. Run `chmod +x ~/.local/bin/ignitepy`.

**Python version not found**
Install it with uv first, for example `uv python install 3.13`, then run `ignitepy` again.

**`VIRTUAL_ENV` does not match the project environment**
This warning means a different virtual environment is active in your shell than the project's `.venv`. Deactivate that environment with `deactivate`, then run project commands from the project directory with `uv run ...` (and `uv sync` first if needed). If you intentionally want to use the active environment instead, pass `--active` to `uv run`.

**A `pyproject.toml` in a parent folder (for example in your home directory)**
`ignitepy` detects this and makes the new project standalone, so the parent project doesn't interfere. You'll see a line saying it found a parent `pyproject.toml`.

## License

Released under the [MIT License](LICENSE).

## Credits

The project setup is based on the Real Python article [How to Set Up a Python Project for Agentic Coding](https://realpython.com/python-project-for-agentic-coding/). ignitepy automates the steps it describes and is not affiliated with Real Python.
