#!/usr/bin/env bash
# Minimal statusline for Claude Code — Catppuccin Mocha palette.
# Receives session JSON on stdin; outputs one ANSI-colored line.

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "unknown"')
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')
repo_name=$(echo "$input" | jq -r '.workspace.repo.name // empty')

# Git branch from cwd
git_branch=$(git -C "$(echo "$input" | jq -r '.cwd // "."')" rev-parse --abbrev-ref HEAD 2>/dev/null)

# Catppuccin Mocha colors (truecolor)
reset=$'\e[0m'
blue=$'\e[38;2;137;180;250m'    # sapphire
mauve=$'\e[38;2;203;166;247m'   # mauve
green=$'\e[38;2;166;227;161m'   # green
peach=$'\e[38;2;250;179;135m'   # peach
red=$'\e[38;2;243;139;168m'     # red
yellow=$'\e[38;2;249;226;175m'  # yellow
teal=$'\e[38;2;148;226;213m'    # teal
dim=$'\e[38;2;108;112;134m'     # overlay0
bold=$'\e[1m'
sep="${dim} │${reset}"

# Context color based on usage
if [[ "$ctx_pct" -ge 80 ]]; then
  ctx_color="$red"
elif [[ "$ctx_pct" -ge 60 ]]; then
  ctx_color="$peach"
else
  ctx_color="$green"
fi

# Format cost (strip trailing zeros)
if [[ "$cost_usd" != "0" && -n "$cost_usd" ]]; then
  cost_fmt=$(printf '%.2f' "$cost_usd")
  cost="${peach}\$${cost_fmt}${reset}"
else
  cost=""
fi

# Git branch
if [[ -n "$git_branch" ]]; then
  branch="${mauve} ${git_branch}${reset}"
else
  branch=""
fi

# Vim mode indicator
if [[ -n "$vim_mode" ]]; then
  case "$vim_mode" in
    INSERT)  vim_indicator="${green}${bold}INSERT${reset}" ;;
    NORMAL)  vim_indicator="${blue}${bold}NORMAL${reset}" ;;
    VISUAL)  vim_indicator="${mauve}${bold}VISUAL${reset}" ;;
    *)       vim_indicator="${dim}${vim_mode}${reset}" ;;
  esac
else
  vim_indicator=""
fi

# Assemble
parts=""
[[ -n "$vim_indicator" ]] && parts+="${vim_indicator}${sep} "
parts+="${blue}${bold}${model}${reset}"
parts+="${sep} ${ctx_color}${ctx_pct}%${reset}"
[[ -n "$branch" ]] && parts+="${sep}${branch}"
[[ -n "$cost" ]] && parts+="${sep} ${cost}"

echo -e "$parts"
