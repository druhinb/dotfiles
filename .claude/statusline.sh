#!/usr/bin/env bash
# Claude Code main status line using one jq parse and a lightweight git query.

set -u

if ! command -v jq >/dev/null 2>&1; then
	printf 'Claude status line requires jq\n' >&2
	exit 1
fi

input=$(command cat)
model=""
vim_mode=""
output_style=""
cwd="."
project_dir="."
repo_name=""
ctx_pct="0"
cost_usd="0"
session_name=""
session_id=""
agent_name=""
worktree_name=""
if ! parsed=$(
	printf '%s' "$input" | jq -er '
    def clean: tostring | gsub("[\u0000-\u001f]"; " ");
    "model=" + ((.model.display_name // "unknown" | clean) | @sh),
    "vim_mode=" + ((.vim.mode // "" | clean) | @sh),
    "output_style=" + ((.output_style.name // "" | clean) | @sh),
    "cwd=" + ((.workspace.current_dir // .cwd // "." | clean) | @sh),
    "project_dir=" + ((.workspace.project_dir // .cwd // "." | clean) | @sh),
    "repo_name=" + ((.workspace.repo.name // "" | clean) | @sh),
    "ctx_pct=" + (((.context_window.used_percentage // 0 | tonumber? // 0) | floor | tostring) | @sh),
    "cost_usd=" + (((.cost.total_cost_usd // 0 | tonumber? // 0) | tostring) | @sh),
    "session_name=" + ((.session_name // "" | clean) | @sh),
    "session_id=" + ((.session_id // "" | clean) | @sh),
    "agent_name=" + ((.agent.name // "" | clean) | @sh),
    "worktree_name=" + ((.worktree.name // .workspace.git_worktree // "" | clean) | @sh)
  '
); then
	printf 'Claude status line received invalid JSON\n' >&2
	exit 1
fi
eval "$parsed"

git_branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
[[ "$git_branch" == "HEAD" ]] && git_branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null || true)

workspace_name="${cwd##*/}"
project_name="${project_dir##*/}"
if [[ -n "$repo_name" ]]; then
	workspace="$repo_name"
	[[ -n "$workspace_name" && "$workspace_name" != "$repo_name" ]] && workspace+="/$workspace_name"
elif [[ -n "$workspace_name" ]]; then
	workspace="$workspace_name"
else
	workspace="${project_name:-workspace}"
fi

mode="${vim_mode:-$output_style}"
state=""
if [[ -n "$agent_name" ]]; then
	state="agent:$agent_name"
elif [[ -n "$worktree_name" ]]; then
	state="wt:$worktree_name"
elif [[ -n "$session_name" ]]; then
	state="$session_name"
elif [[ -n "$session_id" ]]; then
	state="#${session_id:0:8}"
fi

reset=$'\e[0m'
bold=$'\e[1m'
blue=$'\e[38;2;137;180;250m'
mauve=$'\e[38;2;203;166;247m'
green=$'\e[38;2;166;227;161m'
peach=$'\e[38;2;250;179;135m'
red=$'\e[38;2;243;139;168m'
teal=$'\e[38;2;148;226;213m'
dim=$'\e[38;2;108;112;134m'
sep="${dim} │ ${reset}"

if ((ctx_pct >= 80)); then
	ctx_color="$red"
elif ((ctx_pct >= 60)); then
	ctx_color="$peach"
else
	ctx_color="$green"
fi

LC_NUMERIC=C printf -v cost '%.2f' "$cost_usd"

case "$mode" in
NORMAL) mode_color="$blue" ;;
INSERT) mode_color="$green" ;;
VISUAL | "VISUAL LINE") mode_color="$mauve" ;;
*) mode_color="$dim" ;;
esac

parts="${blue}${bold}${model}${reset}"
[[ -n "$mode" ]] && parts+="${sep}${mode_color}${mode}${reset}"
parts+="${sep}${teal}${workspace}${reset}"
[[ -n "$git_branch" ]] && parts+="${sep}${mauve}${git_branch}${reset}"
parts+="${sep}${ctx_color}ctx ${ctx_pct}%${reset}"
parts+="${sep}${peach}\$${cost}${reset}"
[[ -n "$state" ]] && parts+="${sep}${dim}${state}${reset}"

printf '%b\n' "$parts"
