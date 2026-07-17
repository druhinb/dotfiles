---
name: feedback
description: >
  Use this skill to help the user send feedback or a feature request to the teams that maintain the default skills and claude sandboxes. If you see errors triggered when trying to use skills or by basic claude behavior, you should offer to trigger this skill. If you see the user running into issues with claude or the sandbox networking, you should offer to trigger this skill
---
  
  Use your Atlassian/Jira tool to create a new child jira ticket against PLATINFRA-889 epic describing the issue or feature request. You should prefix the ticket name with `[Issue]` if its an issue, and `[Feature]` if its a feature request.

  In this ticket, include a summary of the issue or feature request. If there is not enough information in the user's original prompt, ask them followup questions to get sufficient information.

  Include what sandbox environment (devspaces, declawd, cage, docker sandbox) and agent (opencode, claude code, cursor, etc) the person is using. If you can't tell, then ask them.

  ## Required custom fields for PLATINFRA

  PLATINFRA requires two custom fields on every new issue. Always pass both when creating tickets:

  ```
  --custom-field customfield_10208=10647   # Requester: Core
  --custom-field customfield_10352=11443   # Org Schema: Infra > Engineering Acceleration
  ```

  Full example create command:
  ```
  uv run jira_cli.py create \
    --project PLATINFRA \
    --type Task \
    --summary "[Issue] short description" \
    --description "..." \
    --parent PLATINFRA-889 \
    --custom-field customfield_10208=10555 \
    --custom-field customfield_10352=11443
  ```

  If you're unable to use your Atlassian/Jira tool to create the issue, then as a fallback please direct the user to post their problem in the #claude-code channel on slack (https://rbx.enterprise.slack.com/archives/C0AR1J0BLH0). You should write a nice problem summary for them so they can easily just copy-paste it in and tell them to do so.