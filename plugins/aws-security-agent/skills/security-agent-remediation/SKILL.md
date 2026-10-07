---
name: security-agent-remediation
description: Pulls AWS Security Agent findings (pentest and code review) into a gitignored .security-agent/, builds a prioritized triage and drives remediation. Use when asked to fix, triage or prioritize findings, Security Agent pentest or code review results, or vulnerabilities reported in the AWS account, even without naming the service.
---

# AWS Security Agent findings remediation

Takes you from "I have findings somewhere in AWS" to "I'm fixing the most important ones", in four stages and in this order: discover, export, triage, remediate.

Findings carry working attack scripts, reproduction steps, file paths and sometimes leaked secrets. So the detail lives only in `.security-agent/`, which gets a `.gitignore` containing `*` before anything is written, and the chat shows only titles, counts and one impact line. Also check that the repository root `.gitignore` covers `.security-agent/`.

Prefer `call_api` from the `security-agent` MCP, so calls are visible and audited. Operation in PascalCase and `params` in camelCase (`agentSpaceId`, `pentestJobId`, `findingIds`). Use `get_api_guide` to discover operation names. The AWS CLI (`aws securityagent ...`) is the fallback when the MCP is unavailable.

## 1. Discover, read-only

The hierarchy is Application (account and Region), Agent Space, and inside it either Penetration test, Pentest job and Findings, or Code review, Code review job and Findings. Walk down it with `ListAgentSpaces`, `ListPentests`, `ListCodeReviews`, `ListPentestJobsForPentest` and `ListCodeReviewJobsForCodeReview`.

Job status is `IN_PROGRESS`, `STOPPING`, `STOPPED`, `FAILED` or `COMPLETED`. Only `COMPLETED` has a stable, full set of findings.

Agent spaces and scans are named after the target application. Before showing the raw list, infer which one matches the open repository from the directory name, `git remote -v`, the `name` in `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml` or `*.csproj`, and the README title. Compare case-insensitively, allowing partial matches. Present the guess with the signal behind it and the alternatives, for example "This repo looks like **X** (from `git remote`), which matches the **Y** agent space. Use that, or another?". With no confident match, show the full list. Export only after the user confirms, and pass the confirmed ids explicitly.

## 2. Export to `.security-agent/`

1. Create `.security-agent/.gitignore` containing `*`.
2. List the jobs of the confirmed scan, paginating with `nextToken` until it is absent. Filter `status == "COMPLETED"` and pick the greatest `createdAt`. With no completed job, stop and tell the user there is no completed job yet and that it is worth waiting or checking the job status.
3. `ListFindings` with `agentSpaceId` and `pentestJobId` or `codeReviewJobId`, paginating to the end. Confidence goes `FALSE_POSITIVE`, `UNCONFIRMED`, `LOW`, `MEDIUM`, `HIGH`. Keep `HIGH` and `MEDIUM`, and widen only when the user asks.
4. `BatchGetFindings` accepts up to 25 ids per call. Chunk in groups of 25, concatenate the `findings` arrays and tag each with `"source": "pentest"` or `"source": "code-review"`.
5. For each job, write `.security-agent/findings_<jobId>.md` with the full `BatchGetFindings` response, every field.

With no agent space, scan or completed job, report it to the user rather than retrying, since it usually means the scan has not finished or the credentials point at another account. On a credentials error, check `aws sts get-caller-identity` and the Region (default `us-east-1`, the service is regional).

## 3. Triage

Read the `findings_*.md` files and sort deterministically by the composite key, most urgent first.

1. **Risk level**, `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`, `INFORMATIONAL`, then `UNKNOWN` or missing.
2. **Risk score**, highest first. `riskScore` is a numeric string on pentest findings (`"10.0"`) and is often absent on code review findings. Coerce to float and treat missing as the lowest possible value.
3. **Confidence**, `HIGH`, `MEDIUM`, `LOW`, `UNCONFIRMED`, `FALSE_POSITIVE`.

For each finding's location, use `filePath` when set. Otherwise use `codeLocations[0].filePath` with the scanner's sandbox prefix stripped (or just the basename when the prefix is absent) and append `:<lineStart>`. Pentest findings often have no file, and the impact line then describes the endpoint or attack chain.

Summary for the user.

```
## Security Agent triage, <agent space>

<N> findings (<P> pentest, <C> code review) · confidence <levels> · severity <2 CRITICAL · 5 HIGH · 3 MEDIUM>

### Priority
1. [CRITICAL · score 10.0 · HIGH confidence] <name>
   - Type <riskType> · Source <pentest|code-review>
   - Where <file:line or endpoint>
   - Impact <one plain-language line>

### Recommended order
<what to fix first and why>
```

With more than about 10 findings, or when the user asks for the top N, detail the top N and summarize the rest as counts by severity. `description`, `reasoning` and `attackScript` stay in the files. Call out the `suggestedFix` of code review findings, which maps directly to repo changes, and map pentest findings to the responsible code where possible. A pentest and a code review finding pointing to the same root cause is the strongest priority signal.

## 4. Remediate

Security fixes change behavior (auth, validation, parsing), so they start from a plan, with code edits after approval. Ask whether to start with the first item on the list, naming it. On yes, enter plan mode and build the fix plan from the finding's title, location, impact and `suggestedFix`, referencing the `findingId` and leaving exploit steps in the file. For several findings, one plan per finding or per group of findings sharing a root cause, following the triage order.
