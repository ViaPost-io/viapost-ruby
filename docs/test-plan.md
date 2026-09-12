# Plano de testes — beta v0.1.0

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

