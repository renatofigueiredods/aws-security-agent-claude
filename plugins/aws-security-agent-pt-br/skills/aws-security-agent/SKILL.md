---
name: aws-security-agent
description: Opera o AWS Security Agent pelo MCP security-agent. Use para scan de segurança do código (completo ou só do diff antes de commit, PR ou deploy), threat model review de requirements.md ou design.md, pentest de aplicação publicada, e status ou resultado de scan. Use também para sugerir um scan quando uma mudança em autenticação, endpoint ou entrada externa terminar, ou antes de gerar tarefas a partir de um design. Para triar e corrigir findings já reportados, use security-agent-remediation.
---

# AWS Security Agent

O MCP `security-agent` (pacote `awslabs.security-agent-mcp-server`) conversa com o AWS Security Agent na conta e região das credenciais AWS do processo. Cada scan e cada pentest gera cobrança na conta, então toda execução parte de um pedido ou de uma confirmação do usuário.

| Ferramenta | Função |
|---|---|
| `setup_check` | Verifica credenciais, agent space e service role |
| `setup` | Cria ou reaproveita agent space e role IAM |
| `start_security_scan` | Compacta o código, envia e inicia o scan completo. Devolve `scan_id` na hora |
| `start_diff_scan` | Envia o repositório e o `git diff`, scan focado nas mudanças |
| `start_threat_model_review` | Envia documentos de spec e o código, inicia threat model (STRIDE) |
| `get_scan_status` | Etapa e tempo decorrido do job |
| `get_scan_findings` | Findings, inclusive parciais durante a execução |
| `list_scans` | Scans recentes |
| `stop_scan` | Cancela um scan |
| `call_api` | Chama qualquer operação da API (operação em PascalCase, `params` em camelCase) |
| `get_api_guide` | Lista as operações da API |

## Roteamento

| Intenção | Ação |
|---|---|
| Pedido direto de scan | Scan completo |
| Checkpoint (pronto para commit, PR, produção) ou mudança sensível concluída | Sugerir diff scan e aguardar |
| Escrevendo `requirements.md` ou `design.md`, ou prestes a gerar tarefas a partir deles | Sugerir threat model review antes e aguardar |
| Testar aplicação publicada | Pentest |
| Andamento | `get_scan_status` |
| Resultado | `get_scan_findings` e Apresentação dos findings |
| Domínios alvo, integrações, outra operação | `get_api_guide` e depois `call_api` |
| Corrigir ou triar findings existentes | Skill `security-agent-remediation` |

Sugestão proativa cabe em uma linha e acontece uma vez por sessão. Recusada, o assunto se encerra na sessão. Sem setup feito, a sugestão é o setup.

## Setup

1. Chame `setup_check`.
2. Sem setup e com `existing_agent_spaces` na resposta, mostre nome e id de cada um e pergunte qual usar ou se cria um novo. A escolha do usuário decide, sem seleção automática. Space existente vira `setup(agent_space_id="as-...")`. Space novo pede a pergunta sobre service role IAM existente e depois `setup(name="...")` ou `setup(name="...", service_role_arn="arn:...")`.
3. Em repositório git, ative o hook de diff scan, que vem ligado por padrão. Se `.security-agent/diff-hook` não existir, crie `.security-agent/.gitignore` com `*` e o arquivo vazio `.security-agent/diff-hook`, e avise em uma linha: "Ativei a sugestão de diff scan ao fim dos turnos com mudança de código. Para desligar, apague `.security-agent/diff-hook`." Se o usuário pedir para não ativar, pule este passo.
4. Confirme que o setup terminou.

O servidor aceita apenas caminhos dentro de `WORKSPACE_ROOT` e, sem ela, dentro do diretório onde o Claude Code foi aberto. Quando o usuário quiser escanear outro diretório, ele exporta `SECURITY_AGENT_WORKSPACE_ROOT=/caminho` e reabre o Claude Code.

## Acompanhar um job

Todo `start_*` devolve um `scan_id` imediatamente e o job segue na AWS. Ao iniciar, informe o id e o intervalo de checagem, e diga que o usuário pode pedir para parar de acompanhar. No mesmo turno, siga até um estado terminal (`COMPLETED`, `FAILED`, `STOPPED`) ou até o usuário pedir para parar. Entre as consultas rode `sleep <intervalo>` no Bash com `run_in_background: true` e consulte o status quando ele terminar. A primeira consulta acontece depois do primeiro intervalo. Fale com o usuário somente quando o status mudar.

| Job | Intervalo |
|---|---|
| Scan completo e threat model | 300 s |
| Diff scan | 120 s |
| Pentest | 900 s |

## Scan completo

Revisão periódica do código inteiro, mais lenta e mais ampla.

1. `setup_check`.
2. `start_security_scan(path="<caminho absoluto do workspace>", title="<repo>-<branch>")`. Caminho absoluto, título sem espaço e único por scan.
3. Acompanhe com intervalo de 300 s.
4. Em `COMPLETED`, `get_scan_findings` e Apresentação dos findings.

## Diff scan

Só o que mudou desde uma ref do git. Independe de scan completo anterior.

1. `setup_check`.
2. Pergunte o que escanear, com `HEAD` (mudanças não commitadas) como padrão, `main` para a branch inteira, ou uma ref informada pelo usuário.
3. `start_diff_scan(path="<caminho absoluto do workspace>", base_ref="<ref>")`.
4. Acompanhe com intervalo de 120 s.
5. Em `COMPLETED`, `get_scan_findings` e Apresentação dos findings focada no código alterado.

## Threat model review

Verifica se `requirements.md` e `design.md` (ou o documento de design ou plano em edição) alteram a postura de segurança da aplicação. Independe de scan anterior.

1. `setup_check`.
2. Reúna os caminhos absolutos dos documentos, pelo menos um.
3. `start_threat_model_review(path="<caminho absoluto do workspace>", specs=["<abs>/requirements.md", "<abs>/design.md"])`.
4. Acompanhe com intervalo de 300 s.
5. Em `COMPLETED`, `get_scan_findings`. Cada ameaça traz `statement`, `severity`, `stride`, `threatImpact`, `recommendation` e `impactedAssets`. Agrupe por severidade e destaque como quebra de postura toda ameaça que represente regressão em relação ao design anterior. Siga a Apresentação dos findings.

## Pentest

Roda por horas, conforme o escopo.

1. `setup_check`, e `setup` se for a primeira vez.
2. `call_api("CreateTargetDomain", {agentSpaceId, targetDomainName, verificationMethod: "HTTP_ROUTE"})`.
3. `call_api("VerifyTargetDomain", {agentSpaceId, targetDomainId})`.
4. `call_api("CreatePentest", {agentSpaceId, title, assets: {endpoints: [{uri: "..."}]}, serviceRole: "arn:..."})`.
5. `call_api("StartPentestJob", {agentSpaceId, pentestId})`.
6. Acompanhe com `call_api("BatchGetPentestJobs", {agentSpaceId, pentestJobIds: [...]})` e intervalo de 900 s.
7. Em `COMPLETED`, `call_api("ListFindings", {agentSpaceId, pentestJobId})` e Apresentação dos findings.

## Apresentação dos findings

Ao fim de qualquer scan, entregue as duas partes.

**Resumo no chat**, agrupado por severidade, com local de cada finding.

```
🟣 CRITICAL: {name}
   Arquivo: {filePath}:{lineStart}
   {description}
🔴 HIGH ...
🟡 MEDIUM ...
🟢 LOW ...
```

**Relatório completo** em `.security-agent/findings-{scan_id}.md`, com `.security-agent/.gitignore` contendo `*` criado antes. O relatório traz todos os campos que a API devolveu para cada finding (`findingId`, `name`, `description`, `riskLevel`, `riskType`, `confidence`, `status`, `codeLocations` com `filePath`, `lineStart` e `lineEnd`, `remediationCode` e qualquer outro). Avise o caminho do arquivo ao usuário.

```markdown
# Relatório de scan {scan_id}

**Tipo** FULL | DIFF | THREAT_MODEL · **Título** {title} · **Início** {started_at} · **Total** {count}

| Severidade | Quantidade |
|---|---|
| CRITICAL | N |
| HIGH | N |
| MEDIUM | N |
| LOW | N |

### 🟣 CRITICAL, {name}
- **ID** {findingId}
- **Risk type** {riskType}
- **Confiança** {confidence}
- **Status** {status}
- **Local** `{filePath}:{lineStart}-{lineEnd}`

{description}

{remediationCode}
```

Em seguida ofereça a correção em uma linha, perguntando se pode aplicar as correções de cima para baixo por severidade. Com o sim, percorra todos os findings de CRITICAL a LOW em sequência, aplicando `remediationCode` nas `codeLocations` e reportando uma linha por correção com nome e `arquivo:linha`. Terminadas as correções, rode `start_diff_scan(path, base_ref="HEAD")` para verificar e acompanhe. Se o usuário escolher findings específicos, corrija apenas esses. Se recusar, indique o arquivo do relatório e encerre o assunto na sessão.

## Problemas comuns

| Sintoma | Ação |
|---|---|
| "Not configured. Run setup first." | `setup_check` e `setup` |
| "S3 access validation failed" | Bucket não registrado no agent space. Repita o scan, que registra sozinho, ou rode `setup` |
| "Agent space no longer exists" | `setup` para criar ou escolher outro |
| Scan demorando | `get_scan_status` e verifique erro ou etapa |
| Código grande demais | Escaneie um subdiretório |
| Caminho fora da raiz permitida | `SECURITY_AGENT_WORKSPACE_ROOT` e reabrir o Claude Code |
| Credencial ou serviço indisponível | `aws sts get-caller-identity` e confira a região (`AWS_REGION`, padrão `us-east-1`) |

Regiões suportadas em https://docs.aws.amazon.com/securityagent/latest/userguide/resilience.html.
