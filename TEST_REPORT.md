# Verificação executada — 14/10/2026

- PASS: node --check dist/app.js.
- PASS: python verify.py — 16 arquivos HTML, links internos do cabeçalho/rodapé, título, canonical e idioma; ausência de chave privilegiada em config.js.
- Banco: migração revisada estaticamente, não aplicada nem executada sem projeto Supabase.
- Autenticação e CRUD: implementação pronta para configuração; não testados de ponta a ponta sem credenciais.
- Reserva concorrente: restrição PostgreSQL implementada; não testada contra banco real.
- PASS: validação no navegador local da página inicial, fotos locais, galeria e formulário de solicitação; a solicitação prepara uma mensagem sem enviá-la ou reservar horário.
- Lighthouse: não executado.
- Fotos reais do perfil da Beautique no Google Maps estão armazenadas localmente; Google Fonts e o mapa continuam sendo recursos de terceiros.
- Não foram atribuídas notas de desempenho, certificações de acessibilidade ou conformidade jurídica.

## Preparação da Vercel

- PASS: sintaxe do script prepare-vercel.mjs.
- PASS: preparação estática sem credenciais, preservando modo de consulta.
- PASS: verificação das 16 páginas após preparação.
- Vercel/Supabase: publicação e homologação externas aguardam conexão; não executadas.

## Supabase conectado — verificações efetivamente executadas

- PASS: duas migrações aplicadas ao banco Beautique Project.
- PASS: 15 tabelas com RLS.
- PASS: testes SQL em transação com rollback: CRUD e auditoria, reserva válida, conflito, jornada, data passada, elegibilidade, bloqueio, duração adulterada, remarcação, histórico, cancelamento/liberação, reativação conflitante, visibilidade de inativos, restrição de cliente e escalada de privilégio para viewer, acessos/escritas/RPC anônimos.
- PASS: ausência de fixtures persistidas verificada por consulta de contagem.
- PASS: advisor de segurança sem alertas; desempenho sem warnings, somente índices novos ainda não utilizados.
- Chave publishable conectada ao frontend; nenhuma chave secret/service_role foi obtida ou incorporada.
- Autenticação real por email/senha ainda não homologada: não há usuário administrador persistido.
- Vercel: 403 no espaço daniel-pupos-projects; CLI indisponível; nenhum deploy realizado nessa conta.

- PASS: smoke test HTTP real: categorias e serviços 200; agendamentos e perfis 401 para cliente anônimo.
