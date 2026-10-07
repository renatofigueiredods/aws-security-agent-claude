#!/usr/bin/env bash
# Stop hook. Devolve o turno ao agente para avaliar se a mudança de código pede diff scan.
# Só age em projeto com o marcador .security-agent/diff-hook, e uma vez por estado de diff.
set -uo pipefail

input=$(cat)
[ "$(jq -r '.stop_hook_active // false' <<<"$input")" = "true" ] && exit 0

dir="${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // empty' <<<"$input")}"
[ -n "$dir" ] && [ -f "$dir/.security-agent/diff-hook" ] || exit 0
git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Arquivos alterados ou novos, sem documentação, imagem e o próprio diretório de findings.
changed=$(
  { git -C "$dir" diff --name-only HEAD 2>/dev/null; git -C "$dir" ls-files --others --exclude-standard; } |
    grep -v -E '^\.security-agent/' |
    grep -v -i -E '\.(md|txt|rst|png|jpe?g|gif|svg|pdf)$' |
    sort -u
)
[ -n "$changed" ] || exit 0

# Impressão digital do conteúdo atual, para não repetir a sugestão sobre o mesmo diff.
# macOS não traz sha256sum, usa shasum.
sha() { if command -v sha256sum >/dev/null; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }
fp=$(cd "$dir" && while IFS= read -r f; do
  echo "$f"
  [ -f "$f" ] && sha "$f"
done <<<"$changed" | sha | cut -c1-64)
state="$dir/.security-agent/.diff-hook-last"
[ -f "$state" ] && [ "$(cat "$state")" = "$fp" ] && exit 0
echo "$fp" >"$state"

files=$(head -n 30 <<<"$changed" | sed 's/^/- /')
reason="Hook do AWS Security Agent. Avalie as mudanças de código pendentes neste projeto.

$files

Uma mudança é sensível quando entrada não confiável (parâmetro, header, body, upload, dado externo) chega a um sink sensível (SQL sem parametrização, shell, caminho de arquivo, requisição de rede, desserialização, decisão de autenticação, segredo), ou quando altera autenticação, autorização, criptografia ou configuração de segurança (CORS, headers, sessão). Endpoint de leitura com query parametrizada, refatoração sem mudança de comportamento, teste, log, doc e configuração estática ficam de fora.

A mudança está concluída quando o usuário commitou, disse que terminou, ou a tarefa pedida foi entregue sem pendência.

Sensível e concluída, sugira em uma linha um diff scan (workflow Diff Scan da skill aws-security-agent, base_ref HEAD) e aguarde a confirmação. Em qualquer outro caso, encerre o turno sem escrever nada."

jq -n --arg r "$reason" '{decision: "block", reason: $r}'
