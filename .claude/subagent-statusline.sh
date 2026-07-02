#!/usr/bin/env bash
# Compact Claude Code agent-panel rows. Emits one JSON object per visible task.

set -u

if ! command -v jq >/dev/null 2>&1; then
	printf 'Claude subagent status line requires jq\n' >&2
	exit 1
fi

jq -c '
  def clean: tostring | gsub("[\u0000-\u001f]"; " ");
  def present($fallback):
    if . == null or . == "" then $fallback else clean end;
  def short_model:
    if . == null or . == "" then "default"
    elif (ascii_downcase | contains("opus")) then "opus"
    elif (ascii_downcase | contains("sonnet")) then "sonnet"
    elif (ascii_downcase | contains("haiku")) then "haiku"
    else clean
    end;
  def status_mark:
    if . == "running" then ["●", "\u001b[38;2;137;180;250m"]
    elif . == "completed" then ["✓", "\u001b[38;2;166;227;161m"]
    elif . == "failed" then ["✗", "\u001b[38;2;243;139;168m"]
    elif . == "stopped" then ["■", "\u001b[38;2;250;179;135m"]
    else ["○", "\u001b[38;2;108;112;134m"]
    end;

  (.columns // 100 | tonumber? // 100) as $columns
  | ([($columns - 36), 12] | max) as $description_width
  | .tasks[]?
  | . as $task
  | ($task.status | present("pending")) as $status
  | ($status | status_mark) as $mark
  | ($task.label | present($task.name | present($task.type | present("agent")))) as $label
  | ($task.description | present("")) as $description
  | ($task.model | short_model) as $model
  | (($task.contextWindowSize // 0 | tonumber? // 0)) as $limit
  | (($task.tokenCount // 0 | tonumber? // 0)) as $tokens
  | (if $limit > 0 then (($tokens * 100 / $limit) | floor | tostring) + "%" else "—" end) as $context
  | {
      id: ($task.id | tostring),
      content: (
        $mark[1] + $mark[0] + "\u001b[0m "
        + "\u001b[1m" + $label + "\u001b[0m"
        + (if $description == "" then "" else " \u001b[38;2;108;112;134m· " + $description[0:$description_width] + "\u001b[0m" end)
        + " \u001b[38;2;108;112;134m[" + $model + " · " + $context + "]\u001b[0m"
      )
    }
'
