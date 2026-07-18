#!/usr/bin/env bash

# sync-agents.sh regenerates the Codex (.toml) and Opencode (.md) agent
# definitions, plus Opencode commands, from the canonical Claude Code sources
# under .claude/agents and .claude/commands. Claude owns the body, name, and
# description; per-client metadata (Opencode model/temperature/permission,
# Codex extra keys) is preserved. Client-only agents/commands are never touched.
#
# All frontmatter/TOML parsing and emission is delegated to an embedded python3
# heredoc that uses the Python standard library ONLY (no pyyaml, no tomllib
# writer) so the script runs on a bare macOS/Linux python3 with no extra deps.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK=0
DRIFT=0

usage() {
	cat <<'EOF'
Usage: sync-agents.sh [--check]

Regenerate Codex and Opencode agent/command definitions from the canonical
Claude Code sources under .claude/agents and .claude/commands.

Options:
  --check      Report drift without writing. Exits non-zero if any derived
               file is out of date.
  -h, --help   Show this help.
EOF
}

have() {
	command -v "$1" >/dev/null 2>&1
}

warn() {
	echo "sync-agents: $*" >&2
}

die() {
	warn "$*"
	exit 1
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--check)
		CHECK=1
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		warn "unknown argument: $1"
		usage >&2
		exit 2
		;;
	esac
	shift
done

have python3 || die "python3 required"

# generate CLIENT CLAUDE_SRC TARGET OUTPATH
# Reads the Claude source (and existing TARGET, if any) and writes the
# regenerated content for CLIENT to OUTPATH.
generate() {
	python3 - "$@" <<'PY'
import os
import re
import sys

client, claude_src, target, outpath = sys.argv[1:5]


def read(path):
    with open(path, "r") as fh:
        return fh.read()


def write(path, content):
    with open(path, "w") as fh:
        fh.write(content)


def split_frontmatter(text):
    """Return (frontmatter_lines, body) splitting on the first two '---'."""
    if not text.startswith("---"):
        return [], text
    parts = text.split("\n")
    end = None
    for i in range(1, len(parts)):
        if parts[i].strip() == "---":
            end = i
            break
    if end is None:
        return [], text
    fm_lines = parts[1:end]
    body = "\n".join(parts[end + 1:])
    return fm_lines, body


def parse_fm_fields(fm_lines):
    """Hand-rolled parser for name, description, model, and tools list."""
    name = desc = model = None
    tools = []
    i = 0
    while i < len(fm_lines):
        line = fm_lines[i]
        if line.startswith("name:"):
            name = line[len("name:"):].strip()
        elif line.startswith("description:"):
            desc = line[len("description:"):].strip()
        elif line.startswith("model:"):
            model = line[len("model:"):].strip()
        elif line.startswith("tools:"):
            j = i + 1
            while j < len(fm_lines) and fm_lines[j].startswith("  - "):
                tools.append(fm_lines[j][4:].strip())
                j += 1
            i = j - 1
        i += 1
    return name, desc, model, tools


def yq(s):
    """YAML double-quoted, escaped scalar."""
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def toml_str(s):
    """TOML basic (single-line) string."""
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def toml_ml(body):
    """Escape a body for a TOML multiline basic string."""
    b = body.replace("\\", "\\\\")
    b = b.replace('"""', '\\"\\"\\"')
    return b


def load_claude():
    fm, body = split_frontmatter(read(claude_src))
    name, desc, model, tools = parse_fm_fields(fm)
    body = body.rstrip() + "\n"
    return name, desc, model, tools, body


def extract_extra_toml(text):
    """Return raw lines for top-level keys other than the canonical three."""
    skip = {"name", "description", "developer_instructions"}
    lines = text.split("\n")
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r"^([A-Za-z0-9_]+)\s*=\s*(.*)$", line)
        if m:
            key = m.group(1)
            val = m.group(2)
            if val.startswith('"""') and val.count('"""') < 2:
                j = i + 1
                while j < len(lines) and '"""' not in lines[j]:
                    j += 1
                block = lines[i:j + 1]
                if key not in skip:
                    out.extend(block)
                i = j + 1
                continue
            if key not in skip:
                out.append(line)
        i += 1
    return out


def replace_description(tfm, desc):
    new_fm = []
    replaced = False
    for line in tfm:
        if line.startswith("description:") and not replaced:
            new_fm.append("description: " + yq(desc))
            replaced = True
        else:
            new_fm.append(line)
    if not replaced:
        new_fm.insert(0, "description: " + yq(desc))
    return new_fm


def synth_opencode_agent_fm(desc, tools):
    lines = ["description: " + yq(desc), "mode: subagent",
             "model: llm-gateway/glm-5.2", "permission:"]
    edit_allow = any(t in ("Edit", "Write") for t in tools)
    lines.append("  edit: " + ("allow" if edit_allow else "deny"))
    bare_bash = False
    bash_allows = []
    for t in tools:
        if t == "Bash":
            bare_bash = True
        elif t.startswith("Bash(") and t.endswith(")"):
            bash_allows.append(t[5:-1])
    lines.append("  bash:")
    lines.append('    "*": ' + ('"ask"' if bare_bash else '"deny"'))
    for pat in bash_allows:
        lines.append("    " + yq(pat) + ': "allow"')
    return lines


def emit_codex():
    name, desc, model, tools, body = load_claude()
    extra = extract_extra_toml(read(target)) if os.path.exists(target) else []
    header = "name = %s\ndescription = %s\n" % (toml_str(name), toml_str(desc))
    for line in extra:
        header += line + "\n"
    header += "\n"
    di = 'developer_instructions = """\n' + toml_ml(body) + '"""\n'
    write(outpath, header + di)


def emit_opencode_agent():
    name, desc, model, tools, body = load_claude()
    if os.path.exists(target):
        tfm, _ = split_frontmatter(read(target))
        new_fm = replace_description(tfm, desc)
    else:
        new_fm = synth_opencode_agent_fm(desc, tools)
    write(outpath, "---\n" + "\n".join(new_fm) + "\n---\n" + body)


def emit_opencode_command():
    name, desc, model, tools, body = load_claude()
    if os.path.exists(target):
        tfm, _ = split_frontmatter(read(target))
        new_fm = replace_description(tfm, desc)
    else:
        new_fm = ["description: " + yq(desc)]
    write(outpath, "---\n" + "\n".join(new_fm) + "\n---\n" + body)


emitters = {
    "codex": emit_codex,
    "opencode-agent": emit_opencode_agent,
    "opencode-command": emit_opencode_command,
}

if client not in emitters:
    sys.stderr.write("unknown client: %s\n" % client)
    sys.exit(1)
emitters[client]()
PY
}

# render_target CLIENT CLAUDE_SRC TARGET
render_target() {
	local client="$1" src="$2" target="$3"
	local tmp
	tmp="$(mktemp)"
	generate "$client" "$src" "$target" "$tmp"
	if [[ "$CHECK" -eq 1 ]]; then
		if [[ -e "$target" ]] && cmp -s "$target" "$tmp"; then
			:
		else
			echo "drift: $target" >&2
			if [[ -e "$target" ]]; then
				diff -u "$target" "$tmp" || true
			fi
			DRIFT=1
		fi
		rm -f "$tmp"
	else
		if [[ -e "$target" ]] && cmp -s "$target" "$tmp"; then
			rm -f "$tmp"
		else
			mv "$tmp" "$target"
			echo "updated: $target"
		fi
	fi
}

main() {
	local src name
	for src in "$DOTFILES_DIR"/.claude/agents/*.md; do
		[[ -e "$src" ]] || continue
		name="$(basename "$src" .md)"
		render_target codex "$src" "$DOTFILES_DIR/codex/.codex/agents/$name.toml"
		render_target opencode-agent "$src" "$DOTFILES_DIR/opencode/.config/opencode/agents/$name.md"
	done
	for src in "$DOTFILES_DIR"/.claude/commands/*.md; do
		[[ -e "$src" ]] || continue
		name="$(basename "$src" .md)"
		render_target opencode-command "$src" "$DOTFILES_DIR/opencode/.config/opencode/commands/$name.md"
	done
	if [[ "$CHECK" -eq 1 && "$DRIFT" -ne 0 ]]; then
		die "derived agent/command files are out of date; run ./sync-agents.sh"
	fi
}

main
