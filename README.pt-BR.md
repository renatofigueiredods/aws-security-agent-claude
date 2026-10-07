<div align="center">

[English](README.md) · **Português**

<br>

<img src="assets/logo.svg" alt="" width="180">

<br>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/pt-br/wordmark-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="assets/pt-br/wordmark-light.svg">
  <img src="assets/pt-br/wordmark-light.svg" alt="AWS SECURITY AGENT para Claude Code" width="420">
</picture>

**Scan, threat model, pentest e remediação, direto da conversa.**

O power do AWS Security Agent para Kiro, reescrito como plugin do Claude Code.
Um MCP server, duas skills e um hook, com os findings fora do git desde o primeiro byte.

<a href="plugins/aws-security-agent-pt-br/.claude-plugin/plugin.json"><img src="assets/badges/release.svg" alt="release: v0.1.0"></a>
<a href="LICENSE"><img src="assets/badges/license.svg" alt="license: Apache-2.0"></a>
<a href="https://github.com/renatofigueiredods/aws-security-agent-claude/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/renatofigueiredods/aws-security-agent-claude/ci.yml?branch=main&label=build&labelColor=232F3E" alt="build"></a>
<a href="https://github.com/renatofigueiredods/aws-security-agent-claude/stargazers"><img src="https://img.shields.io/github/stars/renatofigueiredods/aws-security-agent-claude?label=stars&labelColor=232F3E&color=C42D44" alt="stars"></a>
<a href="plugins/aws-security-agent-pt-br/.mcp.json"><img src="assets/badges/mcp.svg" alt="mcp server: 0.2.1"></a>
<br>
<img src="assets/badges/service.svg" alt="service: AWS Security Agent">
<img src="assets/badges/tools.svg" alt="MCP tools: 11">
<img src="assets/badges/skills.svg" alt="skills: 2">
<img src="assets/badges/hook.svg" alt="hook: Stop">
<img src="assets/badges/agent.svg" alt="agent: Claude Code">
<img src="assets/badges/lang.svg" alt="lang: EN | PT-BR">

<br>

[**Instalação**](#instalação) · [**Como funciona**](#como-funciona) · [**Uso**](#uso) · [**Identidade**](#identidade-visual) · [**Contribuir**](CONTRIBUTING.md)

<br>

<details>
<summary><b>&nbsp;Trocar para a opção 2 da identidade&nbsp;</b></summary>

<br>

<img src="assets/logo-lockup.svg" alt="AWS Security Agent + Claude Code, lado a lado" width="340">

<br><br>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/pt-br/wordmark-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="assets/pt-br/wordmark-light.svg">
  <img src="assets/pt-br/wordmark-light.svg" alt="AWS SECURITY AGENT para Claude Code" width="420">
</picture>

<br><br>

<img src="assets/palette.svg" alt="Paleta, Security Agent #DD344C, Badge Red #C42D44, Squid Ink #232F3E, Claude Clay #D97757, Badge Clay #B5583A, Paper #F2F4F7" width="880">

</details>

<sub>A opção 1 acima é a aplicada. A opção 2 coloca as duas marcas lado a lado.</sub>

</div>

<br>

> [!NOTE]
> **Este plugin é uma adaptação do [aws-security-agent-kiro-power](https://github.com/AWS-Security-Agent/aws-security-agent-kiro-power)**
> no commit `f4c1d88`. As instruções foram reescritas para os mecanismos do Claude Code
> (skills, Stop hook, plan mode) em inglês e em português. O MCP server é o mesmo pacote
> oficial, `awslabs.security-agent-mcp-server`, fixado na versão `0.2.1`.

> [!IMPORTANT]
> Cada scan e cada pentest gera cobrança na sua conta AWS. Consulte o
> [pricing do AWS Security Agent](https://aws.amazon.com/security-agent/pricing/). O plugin
> só inicia um job quando você pede ou confirma.

<br>

---

## Por que um plugin

O power do Kiro junta quatro peças num pacote só. O Claude Code tem um equivalente nativo
para cada uma, e o plugin é o formato que instala as quatro juntas.

| No power do Kiro | No plugin do Claude Code | O que faz |
| --- | --- | --- |
| `mcp.json` | [`.mcp.json`](plugins/aws-security-agent-pt-br/.mcp.json) | Sobe o MCP `security-agent` via `uvx` |
| `POWER.md` | skill [`aws-security-agent`](plugins/aws-security-agent-pt-br/skills/aws-security-agent/SKILL.md) | Setup, scan completo, diff scan, threat model, pentest e apresentação dos findings |
| `steering/security-agent-remediation.md` | skill [`security-agent-remediation`](plugins/aws-security-agent-pt-br/skills/security-agent-remediation/SKILL.md) | Exporta, tria e conduz a correção dos findings |
| `.kiro.hook` criado no setup | [`hooks.json`](plugins/aws-security-agent-pt-br/hooks/hooks.json) e [`diff-scan-suggester.sh`](plugins/aws-security-agent-pt-br/hooks/diff-scan-suggester.sh) | Sugere diff scan quando uma mudança de código termina |

Na reescrita, quatro comportamentos mudaram de propósito.

| Comportamento | Kiro | Claude Code | Motivo |
| --- | --- | --- | --- |
| Versão do MCP | `@latest` | `@0.2.1` | Uma versão nova roda com a sua credencial AWS, então a atualização passa por revisão |
| Hook de diff scan | Avaliado em todo turno, roda o scan sem perguntar | Só acorda o agente com código novo em projeto ativado, e sugere o scan | Cada scan é cobrado, e um turno extra em todo repo custa contexto |
| Correção de findings | Spec session do Kiro | Plano de correção em plan mode | Mecanismo equivalente do Claude Code |
| Espera entre consultas | `sleep` em primeiro plano | `sleep` em background | O Claude Code bloqueia `sleep` longo em primeiro plano |

<br>

---

## Como funciona

```mermaid
flowchart LR
    subgraph pedido["Pedido na conversa"]
        A["Scan completo<br/>ou diff scan"]
        B["Threat model<br/>de design.md"]
        C["Pentest de<br/>app publicada"]
        D["Corrigir<br/>findings"]
    end

    SK1{{"skill<br/>aws-security-agent"}}
    SK2{{"skill<br/>security-agent-remediation"}}
    MCP["MCP security-agent<br/><i>uvx awslabs.security-agent-mcp-server@0.2.1</i>"]

    subgraph aws["AWS Security Agent · região das credenciais"]
        AS[("Agent Space")]
        J1["Code review job"]
        J2["Threat model job"]
        J3["Pentest job"]
    end

    subgraph repo["Seu repositório"]
        F[(".security-agent/<br/>gitignore com *")]
        P["Plano de correção<br/>em plan mode"]
    end

    H(["Stop hook<br/>diff-scan-suggester.sh"])

    A --> SK1
    B --> SK1
    C --> SK1
    D --> SK2
    SK1 <--> MCP
    SK2 <--> MCP
    MCP <--> AS
    AS --- J1
    AS --- J2
    AS --- J3
    SK1 ==> F
    SK2 ==> F
    F ==> P
    P -. "diff scan de verificação" .-> SK1
    H -. "código novo no turno" .-> SK1

    classDef src fill:#232F3E,stroke:#5A6B82,stroke-width:1px,color:#F2F4F7
    classDef core fill:#C42D44,stroke:#DD344C,stroke-width:2px,color:#FFFFFF
    classDef mcp fill:#B5583A,stroke:#D97757,stroke-width:1px,color:#FFFFFF
    classDef store fill:#1B2738,stroke:#DD344C,stroke-width:1px,color:#F2F4F7
    classDef out fill:#3A4A5E,stroke:#9AA8BA,stroke-width:1px,color:#F2F4F7
    class A,B,C,D src
    class SK1,SK2 core
    class MCP mcp
    class AS,J1,J2,J3,F store
    class P,H out
```

Da esquerda para a direita, o pedido em linguagem natural ativa uma das duas skills, a
skill chama o MCP, e o MCP envia código e documentos para o AWS Security Agent na conta e
região das suas credenciais. O job roda na AWS e a skill acompanha até o fim. Os findings
voltam como resumo no chat e como relatório completo em `.security-agent/`, que recebe um
`.gitignore` com `*` antes de qualquer escrita, porque finding traz script de ataque e
passos de reprodução.

O plugin tem três peças.

1. **O MCP server.** O pacote oficial `awslabs.security-agent-mcp-server` expõe 11
   ferramentas (`setup_check`, `setup`, `start_security_scan`, `start_diff_scan`,
   `start_threat_model_review`, `get_scan_status`, `get_scan_findings`, `list_scans`,
   `stop_scan`, `call_api`, `get_api_guide`). Ele guarda estado local em
   `~/.securityagent/`.
2. **As skills.** `aws-security-agent` roteia o pedido para o workflow certo e acompanha
   o job a cada 300 s (scan completo e threat model), 120 s (diff scan) ou 900 s (pentest).
   `security-agent-remediation` exporta os findings, ordena por risk level, risk score e
   confiança, e abre um plano de correção por finding.
3. **O hook.** Ao fim de cada turno, verifica se o projeto tem `.security-agent/diff-hook`
   e arquivos de código alterados desde a última avaliação. Só nesse caso devolve o turno
   ao agente para decidir se a mudança é sensível e está concluída.

> [!TIP]
> Sem `WORKSPACE_ROOT`, o MCP só escaneia o diretório onde o Claude Code foi aberto e seus
> subdiretórios. Isso impede que um caminho como `~/.aws` seja compactado e enviado por
> engano. Para liberar outro diretório, exporte `SECURITY_AGENT_WORKSPACE_ROOT` antes de
> abrir o Claude Code.

<br>

---

## Instalação

<div align="center">

<img src="assets/badges/os-linux.svg" alt="os: Linux">
<img src="assets/badges/os-macos.svg" alt="os: macOS">
<img src="assets/badges/os-windows.svg" alt="os: Windows">
<br>
<img src="assets/badges/service.svg" alt="service: AWS Security Agent">
<img src="assets/badges/region.svg" alt="default region: us-east-1">
<img src="assets/badges/tested-linux.svg" alt="hook tested: Linux 6/6">

</div>

O Claude Code instala o plugin direto deste repositório. O marketplace traz o mesmo plugin
em dois idiomas, então escolha um.

| Idioma | Plugin | Comando de instalação |
| --- | --- | --- |
| **English** (padrão) | `aws-security-agent` | `/plugin install aws-security-agent@aws-security-agent-claude` |
| **Português** | `aws-security-agent-pt-br` | `/plugin install aws-security-agent-pt-br@aws-security-agent-claude` |

Os dois trazem o mesmo MCP server e o mesmo hook, por isso instale só um. O que muda por
sistema são as dependências do MCP (`uv`) e do hook (`bash`, `git`, `jq`).

| | Linux | macOS | Windows |
| --- | --- | --- | --- |
| `uv` | instalador oficial | `brew install uv` | instalador oficial |
| Shell do hook | bash | bash | Git Bash |
| Hash do diff | `sha256sum` | `shasum -a 256` | `sha256sum` do Git Bash |
| Status | testado | não testado | não testado |

### Escolha o seu sistema

<details>
<summary>&nbsp;<img src="assets/badges/os-linux.svg" alt="os: Linux" align="top"></summary>

<br>

**1. Instale as dependências**

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
sudo apt install jq git        # Debian, Ubuntu
sudo dnf install jq git        # Fedora, RHEL
```

**2. Autentique na AWS**

As credenciais vêm do ambiente em que o Claude Code é aberto.

```bash
aws sso login --profile <seu-profile>
export AWS_PROFILE=<seu-profile>
export AWS_REGION=us-east-1    # opcional, este é o padrão
```

**3. Instale o plugin**

Dentro do Claude Code.

```
/plugin marketplace add renatofigueiredods/aws-security-agent-claude
/plugin install aws-security-agent-pt-br@aws-security-agent-claude
```

Reinicie a sessão para o MCP `security-agent` subir.

**4. Confira**

```
/mcp
```

O servidor `security-agent` aparece conectado. Depois peça o setup na conversa, por
exemplo *"faz o setup do security agent"*.

</details>

<details>
<summary>&nbsp;<img src="assets/badges/os-macos.svg" alt="os: macOS" align="top"></summary>

<br>

**1. Instale as dependências**

```bash
brew install uv jq git
```

**2. Autentique na AWS**

```bash
aws sso login --profile <seu-profile>
export AWS_PROFILE=<seu-profile>
```

**3. Instale o plugin**

```
/plugin marketplace add renatofigueiredods/aws-security-agent-claude
/plugin install aws-security-agent-pt-br@aws-security-agent-claude
```

**4. Confira**

```
/mcp
```

> [!NOTE]
> O macOS não traz `sha256sum`, e o hook usa `shasum -a 256` nesse caso. Ainda não foi
> validado em macOS.

</details>

<details>
<summary>&nbsp;<img src="assets/badges/os-windows.svg" alt="os: Windows" align="top"></summary>

<br>

**1. Instale as dependências**

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
winget install Git.Git
winget install jqlang.jq
```

**2. Autentique na AWS**

```powershell
aws sso login --profile <seu-profile>
$env:AWS_PROFILE = "<seu-profile>"
```

**3. Instale o plugin**

```
/plugin marketplace add renatofigueiredods/aws-security-agent-claude
/plugin install aws-security-agent-pt-br@aws-security-agent-claude
```

**4. Confira**

```
/mcp
```

> [!NOTE]
> O hook é um script bash e depende do Git Bash. Ainda não foi validado em Windows.

</details>

> [!IMPORTANT]
> O `.gitignore` com `*` dentro de `.security-agent/` impede que os findings entrem no
> repositório. Confirme também que o `.gitignore` da raiz não força a inclusão desse
> diretório, porque o relatório contém script de ataque funcional e às vezes segredo vazado.

<br>

---

## Uso

Você conversa, a skill escolhe o workflow.

```
> faz o setup do security agent
> roda um diff scan das minhas mudanças antes do PR
> faz um scan completo do repositório
> roda o threat model no requirements.md e no design.md
> faz um pentest na aplicação de homologação
> como está o scan?
> traz os findings do último pentest e me ajuda a corrigir
```

Para desligar a sugestão automática de diff scan num projeto, apague
`.security-agent/diff-hook`.

<br>

---

## Popularidade

<div align="center">

<a href="https://star-history.com/#renatofigueiredods/aws-security-agent-claude&Date">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=renatofigueiredods/aws-security-agent-claude&type=Date&theme=dark">
  <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=renatofigueiredods/aws-security-agent-claude&type=Date">
  <img src="https://api.star-history.com/svg?repos=renatofigueiredods/aws-security-agent-claude&type=Date" alt="Histórico de stars do aws-security-agent-claude" width="820">
</picture>
</a>

</div>

<br>

---

## Convenções essenciais

| Regra | Por quê |
| --- | --- |
| Findings só em `.security-agent/`, com `.gitignore` criado antes | Finding traz script de ataque, passos de reprodução e às vezes segredo |
| No chat, só título, contagem e uma linha de impacto | O detalhe de exploração fica no arquivo, fora do histórico da conversa |
| Job só começa com pedido ou confirmação | Cada scan e pentest é cobrado na conta AWS |
| Confiança `HIGH` e `MEDIUM` por padrão | As faixas abaixo trazem mais ruído, e ampliar fica a pedido |
| Triagem ordenada por risk level, risk score e confiança | Ordenação determinística, sem leitura a olho |
| Um plano de correção por finding ou por causa raiz | Cada correção de segurança fica revisável isoladamente |
| MCP com versão fixa | Atualizar é trocar a versão no `.mcp.json` depois de ler o changelog do pacote |

<br>

---

## Identidade visual

<div align="center">

<img src="assets/palette.svg" alt="Paleta, Security Agent #DD344C, Badge Red #C42D44, Squid Ink #232F3E, Claude Clay #D97757, Badge Clay #B5583A, Paper #F2F4F7" width="880">

</div>

A logo junta o ícone oficial do AWS Architecture Icons para o AWS Security Agent, em
destaque, com a marca do Claude no canto, sem perder a identidade de nenhum dos dois. A
paleta sai direto das duas marcas, o vermelho do Security Agent e o terracota do Claude,
sobre o Squid Ink da AWS. Os badges usam as mesmas cores, vermelho para dado do plugin e
terracota para plataforma.

<br>

---

## Roadmap

- [x] MCP, skills e hook reescritos a partir do power `f4c1d88`
- [x] Plugins em inglês e em português no mesmo marketplace
- [x] CI validando manifestos, comportamento do hook nos dois plugins e as 11 ferramentas do MCP `0.2.1`
- [ ] Validar instalação e hook em macOS
- [ ] Validar instalação e hook em Windows com Git Bash
- [ ] Acompanhar novas versões do `awslabs.security-agent-mcp-server` e do power original

<br>

---

## Contribuir

Leia o [`CONTRIBUTING.md`](CONTRIBUTING.md). Em resumo, branch a partir de `main`, mantenha
os dois plugins em sincronia (o script do hook é idêntico nos dois e o CI confere) e rode
`bash tests/hook-test.sh` antes de abrir o PR.

Para falha de segurança, siga o [`SECURITY.md`](SECURITY.md) e reporte de forma privada, sem
abrir issue pública.

<br>

---

<div align="center">

<img src="assets/logo.svg" alt="" width="64">

**AWS Security Agent para Claude Code** · adaptado pela [DreamSquad](https://dreamsquad.com.br)

Distribuído sob a [Apache License 2.0](LICENSE).

<sub>AWS, AWS Security Agent e os AWS Architecture Icons são marcas da Amazon.com, Inc. ou de suas afiliadas.
Claude e Claude Code são marcas da Anthropic, PBC. Este projeto não é afiliado nem endossado por nenhuma das duas empresas.</sub>

</div>
