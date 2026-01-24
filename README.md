# Homebrew Taps

Custom Homebrew formulas.

## Available Formulas

### roborev

Automatic code review daemon for git commits using AI agents.

**Install:**
```bash
brew install wesm/taps/roborev
```

Or tap first, then install:
```bash
brew tap wesm/taps
brew install roborev
```

**Quick Start:**
```bash
cd your-repo
roborev init      # Install post-commit hook
git commit -m "..." # Reviews happen automatically
roborev tui       # View reviews in interactive UI
```

For full documentation, visit [roborev.io](https://roborev.io).
