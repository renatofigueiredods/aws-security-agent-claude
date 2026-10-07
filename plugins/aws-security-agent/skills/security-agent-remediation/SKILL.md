---
name: security-agent-remediation
description: Traz os findings do AWS Security Agent (pentest e code review) para .security-agent/ fora do git, monta a triagem priorizada e conduz a correção. Use quando pedirem para corrigir, triar ou priorizar findings, resultados de pentest ou code review do Security Agent, ou vulnerabilidades reportadas na conta AWS, mesmo sem nomear o serviço.
---

# Remediação de findings do AWS Security Agent

Leva de "tenho findings em algum lugar da AWS" a "estou corrigindo os mais importantes", em quatro etapas e nesta ordem: descobrir, exportar, triar, remediar.

Finding traz script de ataque funcional, passos de reprodução, caminhos de arquivo e às vezes segredo vazado. Por isso o detalhe vive só em `.security-agent/`, que recebe um `.gitignore` com `*` antes de qualquer escrita, e no chat aparecem apenas título, contagem e uma linha de impacto. Confira também se o `.gitignore` da raiz do repositório cobre `.security-agent/`.

Prefira `call_api` do MCP `security-agent`, porque a chamada fica visível e auditada. Operação em PascalCase e `params` em camelCase (`agentSpaceId`, `pentestJobId`, `findingIds`). Use `get_api_guide` para descobrir nomes de operação. O AWS CLI (`aws securityagent ...`) é o plano B quando o MCP não estiver disponível.

## 1. Descobrir, só leitura

A hierarquia é Application (conta e região), Agent Space, e dentro dele Penetration test, Pentest job e Findings, ou Code review, Code review job e Findings. Desça por ela com `ListAgentSpaces`, `ListPentests`, `ListCodeReviews`, `ListPentestJobsForPentest` e `ListCodeReviewJobsForCodeReview`.

Status de job é `IN_PROGRESS`, `STOPPING`, `STOPPED`, `FAILED` ou `COMPLETED`. Somente `COMPLETED` tem o conjunto de findings estável e completo.

Agent spaces e scans levam o nome da aplicação alvo. Antes de mostrar a lista crua, deduza qual corresponde ao repositório aberto a partir do nome do diretório, do `git remote -v`, do `name` em `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml` ou `*.csproj`, e do título do README. Compare sem diferenciar maiúsculas e aceitando correspondência parcial. Apresente o palpite com o sinal que o sustenta e as alternativas, por exemplo "Este repo parece ser o **X** (pelo `git remote`), que bate com o agent space **Y**. Uso esse ou outro?". Sem correspondência confiável, mostre a lista completa. Exporte somente depois da confirmação do usuário e passe os ids confirmados explicitamente.

## 2. Exportar para `.security-agent/`

1. Crie `.security-agent/.gitignore` com `*`.
2. Liste os jobs do scan confirmado, paginando com `nextToken` até ele sumir. Filtre `status == "COMPLETED"` e escolha o de maior `createdAt`. Sem job concluído, pare e diga ao usuário que não há job concluído e que vale aguardar ou conferir o status.
3. `ListFindings` com `agentSpaceId` e `pentestJobId` ou `codeReviewJobId`, paginando até o fim. A confiança vai de `FALSE_POSITIVE`, `UNCONFIRMED`, `LOW`, `MEDIUM` a `HIGH`. Mantenha `HIGH` e `MEDIUM`, e amplie só a pedido do usuário.
4. `BatchGetFindings` aceita até 25 ids por chamada. Divida em lotes de 25, concatene os arrays `findings` e marque cada um com `"source": "pentest"` ou `"source": "code-review"`.
5. Para cada job, grave `.security-agent/findings_<jobId>.md` com a resposta completa do `BatchGetFindings`, todos os campos.

Sem agent space, scan ou job concluído, reporte ao usuário em vez de repetir chamadas, porque geralmente o scan não terminou ou a credencial aponta para outra conta. Em erro de credencial, confira com `aws sts get-caller-identity` e a região (padrão `us-east-1`, o serviço é regional).

## 3. Triar

Leia os `findings_*.md` e ordene de forma determinística pela chave composta, do mais urgente ao menos urgente.

1. **Risk level**, `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`, `INFORMATIONAL`, e por último `UNKNOWN` ou ausente.
2. **Risk score**, maior primeiro. `riskScore` é string numérica em pentest (`"10.0"`) e costuma faltar em code review. Converta para float e trate ausente como o menor valor possível.
3. **Confidence**, `HIGH`, `MEDIUM`, `LOW`, `UNCONFIRMED`, `FALSE_POSITIVE`.

Para o local de cada finding, use `filePath` quando existir. Senão, use `codeLocations[0].filePath` sem o prefixo de sandbox do scanner (ou só o nome do arquivo, se o prefixo não aparecer) e acrescente `:<lineStart>`. Pentest muitas vezes não tem arquivo, e aí a linha de impacto descreve o endpoint ou a cadeia de ataque.

Resumo para o usuário.

```
## Triagem Security Agent, <agent space>

<N> findings (<P> pentest, <C> code review) · confiança <níveis> · severidade <2 CRITICAL · 5 HIGH · 3 MEDIUM>

### Prioridade
1. [CRITICAL · score 10.0 · confiança HIGH] <nome>
   - Tipo <riskType> · Origem <pentest|code-review>
   - Onde <arquivo:linha ou endpoint>
   - Impacto <uma linha em linguagem simples>

### Ordem recomendada
<o que corrigir primeiro e por quê>
```

Com mais de uns 10 findings, ou quando o usuário pedir só os N primeiros, detalhe os N e resuma o resto como contagem por severidade. `description`, `reasoning` e `attackScript` ficam nos arquivos. Destaque o `suggestedFix` dos findings de code review, que vira mudança direta no repo, e relacione os de pentest ao código responsável quando possível. Pentest e code review apontando a mesma causa raiz é o sinal mais forte de prioridade.

## 4. Remediar

Correção de segurança muda comportamento (autenticação, validação, parsing), então começa por um plano, com a edição de código vindo depois da aprovação. Pergunte se pode começar pelo primeiro da lista, citando o nome. Com o sim, entre em plan mode e monte o plano de correção a partir do título, local, impacto e `suggestedFix` do finding, referenciando o `findingId` e deixando os passos de exploração no arquivo. Para vários findings, um plano por finding ou por grupo de findings com a mesma causa, seguindo a ordem da triagem.
