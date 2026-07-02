---
paths:
  - "setup.sh"
---

# Bootstrap conventions

- `setup.sh` is the single owner of package installation and symlink creation. Add new versioned runtime files to `link_dotfiles`; do not hand-maintain duplicate copies under `$HOME`.
- Preserve `--dry-run` behavior by routing mutations through `run`, `sudo_run`, or `link_file`.
- Existing targets are backed up before links are replaced. Keep link sources inside the repository and targets at their standard user locations.
- macOS with Homebrew is primary. Linux package installation remains best-effort and must not assume Homebrew paths or macOS-only commands.
- Optional tools and plugin installers should fail with a clear warning while allowing unrelated setup phases to continue.
- Never run full setup as a validation shortcut. Use `bash -n setup.sh` and `./setup.sh --dry-run --skip-neovim-tools`; leave clean-machine and end-to-end installation testing to an explicit integration phase.
