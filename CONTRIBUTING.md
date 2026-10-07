# Contributing

**English** · [Português](#contribuindo)

1. Branch from `main`.
2. Keep both plugins in sync. A change to a skill in `plugins/aws-security-agent` has its
   counterpart in `plugins/aws-security-agent-pt-br`, and the hook script stays identical
   in both (CI compares them).
3. Run `bash tests/hook-test.sh` before opening a PR.
4. To upgrade the MCP server, bump the version in both `.mcp.json` files after reading the
   `awslabs.security-agent-mcp-server` changelog. CI checks that the 11 tools are still
   exposed.
5. Use conventional commit titles (`feat:`, `fix:`, `docs:`).

Security issues follow [`SECURITY.md`](SECURITY.md).

---

## Contribuindo

1. Crie a branch a partir de `main`.
2. Mantenha os dois plugins em sincronia. Toda mudança numa skill de
   `plugins/aws-security-agent` tem a correspondente em `plugins/aws-security-agent-pt-br`,
   e o script do hook continua idêntico nos dois (o CI compara).
3. Rode `bash tests/hook-test.sh` antes de abrir o PR.
4. Para atualizar o MCP server, troque a versão nos dois `.mcp.json` depois de ler o
   changelog do `awslabs.security-agent-mcp-server`. O CI confere se as 11 ferramentas
   continuam expostas.
5. Use título no padrão conventional commit (`feat:`, `fix:`, `docs:`).

Falha de segurança segue o [`SECURITY.md`](SECURITY.md).
