# Beautique Estética & Hair

Website multipágina em HTML, CSS e JavaScript, com integração Supabase Auth/REST opcional. A implantação Sites é privada. A escolha buildless elimina dependências de framework no ambiente atual; não é um projeto Next.js. Serviços, valores e horários não confirmados permanecem para consulta.

## Instalação e implantação

Sirva `dist/` como raiz de um site estático. Localmente: `python -m http.server 8000 --directory dist`. Na Vercel, `vercel.json` define preset estático, build `node scripts/prepare-vercel.mjs` e diretório `dist`. Configure SUPABASE_URL e SUPABASE_ANON_KEY juntas; somente chaves anon/publishable são aceitas. SITE_URL atualiza canonical e sitemap. WHATSAPP_CONFIRMED=true só deve ser ativado após validação do número. As rotas possuem arquivos `index.html`. Atualize canonical, sitemap e robots ao mudar o domínio. `python build.py` regenera as páginas e o CSS a partir deste checkout, preservando `app.js`, `config.js` e as imagens locais. O código principal está em dist/app.js.

## Banco e autenticação

1. O projeto Beautique Project já recebeu as migrações 001 e 002. Em um novo banco dedicado, aplique ambos os arquivos em ordem.
2. Crie a conta administrativa em Supabase Auth, desative cadastro público, configure proteção contra tentativas e senha forte.
3. Cadastre seu UUID real na tabela profiles com role admin utilizando SQL privilegiado.
4. Preencha dist/config.js com URL do projeto e chave **anon/public**. Nunca inclua service_role ou senha nesse arquivo.
5. Teste as políticas RLS antes de disponibilizar dados reais. A autenticação consulta o perfil; o banco autoriza as operações. O token permanece apenas em memória e sai ao recarregar a página. Supabase deve limitar tentativas; nenhuma limitação client-side é alegada.

## Manual do painel

Acesse /admin, faça login. Serviços e profissionais: criar, editar, desativar e excluir. Valores administrativos são informados em centavos. Configure vínculos com UUIDs, jornadas por dia da semana e bloqueios. Agenda: criar reserva pendente com validação de jornada, filtrar por data, confirmar, cancelar, concluir e remarcar. Galeria e depoimentos: cadastrar apenas conteúdo autorizado. Configurações e textos possuem editores JSON. Apenas contas admin acessam dados restritos. Falhas exibem erro sem sucesso falso. Alterações são persistidas no Supabase e auditadas.

O banco contém estrutura adicional para vincular serviços/profissionais, jornada, bloqueios, histórico, galeria, depoimentos, orçamento, seções e configurações. Os registros possuem editores administrativos. Vínculos e jornadas usam UUIDs exibidos na tabela; não há seletores amigáveis para todas as relações. Para substituir o título e descrição de uma página, crie uma seção com slug home, sobre, spa etc. e conteúdo JSON com campos title e description. Na galeria, fotografias autorizadas cadastradas substituem as ilustrações. Configurações genéricas são persistidas, mas não todas aplicadas automaticamente à aparência.

## Agendamento e contato

A versão entregue usa **solicitação de contato**, sem horários fictícios. O formulário valida os campos, prepara mensagem e copia somente após ação da pessoa. Sem WhatsApp confirmado, oferece ligação. Configure whatsappConfirmed=true apenas depois de verificar que o número aceita mensagens. Isso ativa a abertura do WhatsApp com a mensagem; não envia automaticamente nem confirma reserva. Não existem formulários que alegam armazenamento sem gravar.

A função reserve_appointment permite reservas por administradores autenticados com verificação de jornada, vínculo de serviço, bloqueios e exclusão PostgreSQL de intervalos conflitantes. A interface pública de disponibilidade real e as vistas de calendário semanal/mensal não foram implementadas. A agenda administrativa tem lista e filtro por data. Não ativar bookingMode como agenda online: ele é reservado para evolução futura. Antes dessa evolução, implementar endpoint protegido com validação, proteção contra abuso, consentimento e RPC pública restrita. Cancelamento público via token, vistas de calendário semanal/mensal, armazenamento dos pedidos da noiva e upload Storage ainda não foram implementados.

## Conteúdo e SEO

Foram criadas páginas início, sobre, serviços com filtros, cinco categorias individuais, spa, noiva, galeria com lightbox, contato, agendamento, privacidade, termos e admin. Metadados, canonical, sitemap, robots e BeautySalon JSON-LD não incluem preços, horário ou qualificações inventados. Catálogo público apresenta segmentos fornecidos; não lista procedimentos reais ainda. Quando conectado, o catálogo de serviços busca e apresenta os procedimentos reais cadastrados no Supabase, com pesquisa e filtros. As páginas individuais permanecem por segmento.

As fotos do espaço nesta versão foram copiadas do perfil público da Beautique no Google Maps, consultado em 14/10/2026, com autorização de uso informada pela contratante. São imagens reais da recepção e dos ambientes, não registros de procedimentos ou resultados. Google Fonts e Maps continuam sendo serviços de terceiros. A nota 4,9 e as 87 avaliações também foram informadas pela contratante e não são atualizadas automaticamente.

## Pendências comerciais e técnicas

- Fotos/logotipo oficiais, autorização de imagem, identidade aprovada.
- Procedimentos, preços opcionais, duração, profissionais, qualificações, jornada e bloqueios.
- Número WhatsApp validado, horários e pacotes reais.
- Depoimentos autorizados e URL exata do perfil Google.
- Conta de administrador e domínio definitivo (configuração pública Supabase já integrada).
- Aprovação dos textos, termos e política; responsável pelo tratamento, retenção e processo de atendimento a direitos.
- Aplicação automática de todas as configurações visuais, vistas de calendário e formulário com armazenamento e controle contra abuso.
- Analytics/consentimento e eventos de conversão não instalados.
- Imagens locais oficiais, testes de renderização e Lighthouse ainda pendentes.

## Homologação

- [ ] Aprovar identidade, conteúdo e informações cadastrais com a empresa.
- [ ] Verificar desktop, tablet, celular, teclado, contraste, leitor de tela, falhas de rede.
- [ ] Validar mapa, ligação, Instagram e número WhatsApp.
- [ ] Aplicar migração e testar RLS com anon, viewer e admin.
- [ ] Testar autenticação, cadastro, alteração, desativação, auditoria e status.
- [ ] Executar teste concorrente de duas reservas iguais: só uma deve persistir.
- [ ] Confirmar jornadas, bloqueios, fuso São Paulo, intervalos e cancelamento.
- [ ] Revisar privacidade e acesso antes de receber clientes reais.
- [ ] Medir Lighthouse no domínio final; nenhuma nota foi presumida.

Esta entrega é uma base funcional para apresentação privada e evolução. Ainda não está homologada para operação comercial completa.

## Preparação Vercel — 14/10/2026

Configuração de deploy, headers de segurança e geração de configuração pública preparados. A versão está marcada noindex até homologação. Isso não restringe acesso: antes de publicar, habilitar e verificar Deployment Protection também no domínio de produção. Não publicar com dados pessoais nem mudar a audiência sem atender ao pedido de privacidade. Supabase configurado no projeto dedicado existente; Vercel retornou 403 no espaço solicitado e publicação aguarda conexão com acesso a esse espaço.

## Homologação do banco executada

As 15 tabelas estão com RLS. As migrações foram aplicadas e os testes de tests/database_homologation.sql passaram no banco real com rollback de todas as fixtures. Verificaram CRUD, auditoria, conflitos, jornadas, data passada, vínculo, bloqueios, duração, remarcação, histórico e permissões anon/viewer/admin. Não houve teste com duas sessões simultâneas; a restrição de exclusão foi testada por tentativa conflitante. Não existem clientes ou profissionais fictícios persistidos. O advisor de segurança não apontou problemas; o de desempenho mantém apenas informações de índices novos ainda não utilizados. Não há conta Auth persistida: o administrador deverá ser criado no fluxo oficial Supabase Auth com senha escolhida pelo responsável, e ter seu UUID autorizado em profiles. Nunca criar senhas padrão ou divulgar credenciais.
