# Plano de testes — beta v0.2.0

Os comportamentos abaixo orientam os ciclos Red → Green → Refactor do SDK:

1. configuração exige API key, usa HTTPS por padrão e só aceita HTTP em loopback;
2. autenticação, JSON, user-agent e timeouts são enviados sem cookies ou redirects;
3. respostas JSON viram hashes com chaves simbólicas; 204 vira `nil`;
4. respostas maiores que 8 MiB, JSON inválido, timeout e conexão falha geram erros tipados;
5. erros HTTP preservam código, request ID e Retry-After sem expor a API key;
6. GET/HEAD repetem no máximo o configurado em 429/5xx, respeitando Retry-After;
7. POST/PATCH/DELETE nunca são repetidos;
8. `send` aceita idempotency key e valida limites do contrato antes de tocar a rede;
9. resources cobrem messages, domains, templates, webhooks, automations e usage;
10. paginação e filtros são codificados sem mutar hashes do consumidor;
11. webhooks e templates aplicam as restrições críticas do OpenAPI localmente;
12. o OpenAPI vendorizado mantém o SHA esperado e as rotas públicas do beta;
13. tag de release equivale exatamente à versão e aponta para commit contido em `main`;
14. o `.gem` instala e carrega em um consumidor isolado.
15. downloads RFC 5322 e exportações CSV preservam bytes sem decodificação JSON;
16. importações CSV usam `text/csv`, respeitam 2 MiB e nunca são repetidas;
17. operações de webhook exigem versões e chaves idempotentes válidas;
18. secrets retornados por criação ou rotação não aparecem em inspect/JSON;
19. o monitor compara semanticamente a cópia local com a URL pública oficial.
20. respostas JSON e erros mantêm 8 MiB enquanto RFC 5322/CSV usam limite bruto independente;
21. o limite bruto padrão é 40 MiB, é configurável e rejeita valores acima de 128 MiB;
22. cabeçalhos extras não substituem autenticação, host, user-agent, compressão ou hop-by-hop;
23. webhooks exigem HTTPS público e o downloader só segue redirects HTTPS na mesma origem.
