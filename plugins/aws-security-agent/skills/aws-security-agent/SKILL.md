---
name: aws-security-agent
description: Runs AWS Security Agent through the security-agent MCP. Use for security scans of the code (full, or diff-only before a commit, PR or deploy), threat model reviews of requirements.md or design.md, pentests of a deployed application, and scan status or results. Also use to suggest a scan when a change to auth, endpoints or external input is finished, or before generating tasks from a design. To triage and fix findings already reported, use security-agent-remediation.
---

# AWS Security Agent

The `security-agent` MCP (package `awslabs.security-agent-mcp-server`) talks to AWS Security Agent in the account and Region of the process's AWS credentials. Every scan and every pentest is billed to that account, so each run starts from a user request or a user confirmation.

| Tool | Purpose |
|---|---|
| `setup_check` | Verify credentials, agent space and service role |
| `setup` | Create or reuse the agent space and IAM role |
| `start_security_scan` | Zip, upload and start a full scan. Returns `scan_id` immediately |
| `start_diff_scan` | Upload the repo plus `git diff`, scan focused on the changes |
| `start_threat_model_review` | Upload spec docs plus source, start a threat model (STRIDE) |
| `get_scan_status` | Job step and elapsed time |
| `get_scan_findings` | Findings, partial results included while the job runs |
| `list_scans` | Recent scans |
| `stop_scan` | Cancel a scan |
| `call_api` | Call any API operation (PascalCase operation, camelCase `params`) |
| `get_api_guide` | List the API operations |

## Routing

| Intent | Action |
|---|---|
| Direct scan request | Full scan |
| Checkpoint (ready to commit, PR, prod) or a finished security-sensitive change | Suggest a diff scan and wait |
| Writing `requirements.md` or `design.md`, or about to generate tasks from them | Suggest a threat model review first and wait |
| Test a deployed application | Pentest |
| Progress | `get_scan_status` |
| Results | `get_scan_findings` and Findings presentation |
| Target domains, integrations, any other operation | `get_api_guide`, then `call_api` |
| Fix or triage existing findings | Skill `security-agent-remediation` |

A proactive suggestion fits in one line and happens at most once per session. Once declined, the topic is closed for the session. Without setup, the suggestion is setup.

## Setup

1. Call `setup_check`.
2. Not set up and `existing_agent_spaces` returned, show each name and id and ask which one to use or whether to create a new one. The user's choice decides, with no auto-selection. An existing space becomes `setup(agent_space_id="as-...")`. A new space needs the question about an existing IAM service role, then `setup(name="...")` or `setup(name="...", service_role_arn="arn:...")`.
3. In a git repository, enable the diff scan hook, which is on by default. If `.security-agent/diff-hook` does not exist, create `.security-agent/.gitignore` containing `*` and the empty file `.security-agent/diff-hook`, and say in one line: "Enabled the diff scan suggestion at the end of turns with code changes. To turn it off, delete `.security-agent/diff-hook`." If the user asks to skip it, skip this step.
4. Confirm setup is complete.

The server only accepts paths inside `WORKSPACE_ROOT` and, when unset, inside the directory where Claude Code was opened. To scan another directory, the user exports `SECURITY_AGENT_WORKSPACE_ROOT=/path` and reopens Claude Code.

## Following a job

Every `start_*` returns a `scan_id` immediately and the job keeps running in AWS. When it starts, share the id and the polling interval, and mention the user can ask to stop polling. In the same turn, follow it to a terminal state (`COMPLETED`, `FAILED`, `STOPPED`) or until the user asks to stop. Between checks run `sleep <interval>` in Bash with `run_in_background: true` and check the status when it finishes. The first check happens after the first interval. Speak to the user only when the status changes.

| Job | Interval |
|---|---|
| Full scan and threat model | 300 s |
| Diff scan | 120 s |
| Pentest | 900 s |

## Full scan

Periodic review of the whole codebase, slower and broader.

1. `setup_check`.
2. `start_security_scan(path="<absolute workspace path>", title="<repo>-<branch>")`. Absolute path, title without spaces and unique per scan.
3. Follow with a 300 s interval.
4. On `COMPLETED`, `get_scan_findings` and Findings presentation.

## Diff scan

Only what changed since a git ref. Needs no prior full scan.

1. `setup_check`.
2. Ask what to scan, with `HEAD` (uncommitted changes) as the default, `main` for the whole branch, or a ref the user provides.
3. `start_diff_scan(path="<absolute workspace path>", base_ref="<ref>")`.
4. Follow with a 120 s interval.
5. On `COMPLETED`, `get_scan_findings` and Findings presentation focused on the changed code.

## Threat model review

Checks whether `requirements.md` and `design.md` (or the design or plan document being edited) change the application's security posture. Needs no prior scan.

1. `setup_check`.
2. Collect the absolute paths of the documents, at least one.
3. `start_threat_model_review(path="<absolute workspace path>", specs=["<abs>/requirements.md", "<abs>/design.md"])`.
4. Follow with a 300 s interval.
5. On `COMPLETED`, `get_scan_findings`. Each threat has `statement`, `severity`, `stride`, `threatImpact`, `recommendation` and `impactedAssets`. Group by severity and call out every threat that is a regression from the previous design as a security posture break. Then follow Findings presentation.

## Pentest

Runs for hours, depending on scope.

1. `setup_check`, and `setup` the first time.
2. `call_api("CreateTargetDomain", {agentSpaceId, targetDomainName, verificationMethod: "HTTP_ROUTE"})`.
3. `call_api("VerifyTargetDomain", {agentSpaceId, targetDomainId})`.
4. `call_api("CreatePentest", {agentSpaceId, title, assets: {endpoints: [{uri: "..."}]}, serviceRole: "arn:..."})`.
5. `call_api("StartPentestJob", {agentSpaceId, pentestId})`.
6. Follow with `call_api("BatchGetPentestJobs", {agentSpaceId, pentestJobIds: [...]})` and a 900 s interval.
7. On `COMPLETED`, `call_api("ListFindings", {agentSpaceId, pentestJobId})` and Findings presentation.

## Findings presentation

At the end of any scan, deliver both parts.

**Chat summary**, grouped by severity, with each finding's location.

```
🟣 CRITICAL: {name}
   File: {filePath}:{lineStart}
   {description}
🔴 HIGH ...
🟡 MEDIUM ...
🟢 LOW ...
```

**Full report** at `.security-agent/findings-{scan_id}.md`, with `.security-agent/.gitignore` containing `*` created first. The report carries every field the API returned for each finding (`findingId`, `name`, `description`, `riskLevel`, `riskType`, `confidence`, `status`, `codeLocations` with `filePath`, `lineStart` and `lineEnd`, `remediationCode`, and any other). Tell the user the file path.

```markdown
# Scan report {scan_id}

**Type** FULL | DIFF | THREAT_MODEL · **Title** {title} · **Started** {started_at} · **Total** {count}

| Severity | Count |
|---|---|
| CRITICAL | N |
| HIGH | N |
| MEDIUM | N |
| LOW | N |

### 🟣 CRITICAL, {name}
- **ID** {findingId}
- **Risk type** {riskType}
- **Confidence** {confidence}
- **Status** {status}
- **Location** `{filePath}:{lineStart}-{lineEnd}`

{description}

{remediationCode}
```

Then offer remediation in one line, asking whether to apply the fixes top-down by severity. On yes, go through every finding from CRITICAL to LOW in sequence, applying `remediationCode` at the `codeLocations` and reporting one line per fix with the name and `file:line`. When all fixes are applied, run `start_diff_scan(path, base_ref="HEAD")` to verify and follow it. If the user picks specific findings, fix only those. If the user declines, point to the report file and close the topic for the session.

## Troubleshooting

| Symptom | Action |
|---|---|
| "Not configured. Run setup first." | `setup_check`, then `setup` |
| "S3 access validation failed" | Bucket not registered on the agent space. Rerun the scan, which registers it, or run `setup` |
| "Agent space no longer exists" | `setup` to create or pick another |
| Scan taking too long | `get_scan_status` and check for errors or the current step |
| Code too large | Scan a subdirectory |
| Path outside the allowed root | `SECURITY_AGENT_WORKSPACE_ROOT` and reopen Claude Code |
| Credentials or service unavailable | `aws sts get-caller-identity` and check the Region (`AWS_REGION`, default `us-east-1`) |

Supported Regions at https://docs.aws.amazon.com/securityagent/latest/userguide/resilience.html.
