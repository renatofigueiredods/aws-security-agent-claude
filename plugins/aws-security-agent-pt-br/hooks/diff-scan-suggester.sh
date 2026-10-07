#!/usr/bin/env bash
# Stop hook. Hands the turn back to the agent to decide whether the code change warrants a diff scan.
# Acts only in projects with the .security-agent/diff-hook marker, once per diff state.
# Usage: diff-scan-suggester.sh [en|pt-br]
set -uo pipefail

lang="${1:-en}"
input=$(cat)
[ "$(jq -r '.stop_hook_active // false' <<<"$input")" = "true" ] && exit 0

dir="${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // empty' <<<"$input")}"
[ -n "$dir" ] && [ -f "$dir/.security-agent/diff-hook" ] || exit 0
git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Changed or new files, excluding docs, images and the findings directory itself.
changed=$(
  { git -C "$dir" diff --name-only HEAD 2>/dev/null; git -C "$dir" ls-files --others --exclude-standard; } |
    grep -v -E '^\.security-agent/' |
    grep -v -i -E '\.(md|txt|rst|png|jpe?g|gif|svg|pdf)$' |
    sort -u
)
[ -n "$changed" ] || exit 0

# Fingerprint of the current content, so the same diff is evaluated only once.
# macOS ships shasum instead of sha256sum.
sha() { if command -v sha256sum >/dev/null; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }
fp=$(cd "$dir" && while IFS= read -r f; do
  echo "$f"
  [ -f "$f" ] && sha "$f"
done <<<"$changed" | sha | cut -c1-64)
state="$dir/.security-agent/.diff-hook-last"
[ -f "$state" ] && [ "$(cat "$state")" = "$fp" ] && exit 0
echo "$fp" >"$state"

files=$(head -n 30 <<<"$changed" | sed 's/^/- /')

if [ "$lang" = "pt-br" ]; then
  reason="Hook do AWS Security Agent. Avalie as mudanças de código pendentes neste projeto.

$files

Uma mudança é sensível quando entrada não confiável (parâmetro, header, body, upload, dado externo) chega a um sink sensível (SQL sem parametrização, shell, caminho de arquivo, requisição de rede, desserialização, decisão de autenticação, segredo), ou quando altera autenticação, autorização, criptografia ou configuração de segurança (CORS, headers, sessão). Endpoint de leitura com query parametrizada, refatoração sem mudança de comportamento, teste, log, doc e configuração estática ficam de fora.

A mudança está concluída quando o usuário commitou, disse que terminou, ou a tarefa pedida foi entregue sem pendência.

Sensível e concluída, sugira em uma linha um diff scan (workflow Diff scan da skill aws-security-agent, base_ref HEAD) e aguarde a confirmação. Em qualquer outro caso, encerre o turno sem escrever nada."
else
  reason="AWS Security Agent hook. Evaluate the pending code changes in this project.

$files

A change is security-sensitive when untrusted input (request params, headers, body, uploads, external data) reaches a sensitive sink (SQL without parameterization, shell, filesystem paths, network requests, deserialization, auth decisions, secrets), or when it changes authentication, authorization, cryptography or security configuration (CORS, headers, sessions). Read-only endpoints with parameterized queries, behavior-preserving refactors, tests, logging, docs and static configuration are out of scope.

The change is complete when the user committed, said it is done, or the requested task was delivered with no pending follow-ups.

If it is sensitive and complete, suggest a diff scan in one line (Diff scan workflow of the aws-security-agent skill, base_ref HEAD) and wait for confirmation. Otherwise, end the turn without writing anything."
fi

jq -n --arg r "$reason" '{decision: "block", reason: $r}'
