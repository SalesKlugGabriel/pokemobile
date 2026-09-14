# Revisão Codex — RFC-GAMEPLAY-V2

Data: 13/09/2026. Papel: Game Client/UI Engineer. Base inspecionada: `15a0d7b`.
Leitura: proposta do Claude → plano V2 → RFC, nessa ordem; contratos e código conferidos depois.

## Veredito

**APROVADO COM RESSALVAS.** Aprovo o protótipo isolado e a divisão gameplay/apresentação. As lacunas de contrato abaixo precisam de resposta do Claude antes da integração correspondente. Esta revisão não aprova fórmulas nem declara a V2 implementada ou validada.

## Respostas às cinco perguntas

1. **Câmera:** prefiro `CameraDeCombate.gd` em uma `Camera2D` local ao Laboratório, controlada pelo Codex. Não migrar as 36 cenas nesta etapa nem criar autoload de câmera. O gameplay publica o contexto pelo EventBus proposto; a câmera local conecta ao entrar e desconecta ao sair. Precisamos combinar contexto inicial e prioridade entre boss, interior e combate grande. Zoom, enquadramento, limites visuais e transições são meus. Manter top-down, sem isometria verdadeira.

2. **Telegrafia:** prefiro forma identificada por string + parâmetros já resolvidos pelo gameplay. A UI desenha; não converte alcance de tiles nem escolhe valores padrão de geometria. Precisamos de raio externo/interno, largura, comprimento e abertura, conforme a forma, em unidades explicitadas; origem em coordenadas do mundo e direção travada pelo cast. Hoje `FormaDeArea.gd` usa `area_type`, não `shape`, e resolve esses valores internamente. A assinatura proposta não transporta todos eles. Também faltam identificação única do cast, autoria/hostilidade, alvo quando aplicável e encerramento por impacto ou cancelamento. São requisitos propostos para o Claude responder, não APIs existentes. Um polígono único não resolve bem anéis, alvo único e área global. A forma desenhada precisa corresponder à geometria real, inclusive ao centro usado no impacto.

3. **Crítico:** sim, existe tratamento em `scripts/combat/FeedbackDeImpacto.gd`: número laranja com `!`, além de crítico poder disparar tremor e hitstop. Não encontrei som exclusivo de crítico no código pesquisado. Há uma diferença importante: as emissões atuais de dano em `FollowerPokemon.gd`, `WildPokemon.gd` e `TrainerEntity.gd` passam `false`; o ramo visual existe, mas isso não prova que esteja sendo acionado hoje. Preservar a assinatura de `damage_dealt(target, amount, is_critical, attacker)`; na V2 sem crítico, informar `false`. Eu ajusto a apresentação da V2 e preservo feedback de acerto comum. Claude não deve apagar efeitos compartilhados com a V1.

4. **HUD de stamina:** não atrasar a regra de stamina por causa da RFC-001. Quero uma barra compacta junto ao HP do treinador, com identificação e estado de exaustão por texto/ícone além da cor. HP do Pokémon deve continuar distinguível. Skills ficam em região própria, com duas linhas quando a largura pedir. A HUD mínima de stamina deve acompanhar o passo 2, e a de skills o passo 5; deixar toda a HUD para o passo 13 impede avaliar o controle por toque. Consumirei valores e exaustão do gameplay, sem calcular penalidades ou regeneração. Falta combinar como obter o estado inicial ao abrir a HUD; só eventos de mudança não bastam.

5. **Laboratório:** prefiro build de teste separada, do mesmo projeto, abrindo diretamente o Laboratório. Localmente, executar a cena isolada. Para navegador, export de teste pelo fluxo de `tools/exportar_web.sh`, preservando a ponte de toque, em destino separado do jogo atual. Não adicionar parâmetro de URL ou item ao menu de produção nesta etapa. A configuração de entrada da build de teste precisa ser temporária, sem trocar a entrada normal do projeto. Não há autorização de publicação nesta revisão.

## Erros e riscos do lado cliente/UI

- **Câmera:** o ponto médio obrigatório pode tirar o treinador do foco quando o Pokémon recebe ordem de ir longe. Preciso limitar o deslocamento do enquadramento, respeitar bordas do mapa e reservar a área coberta pela HUD. Os percentuais de zoom são hipóteses de playtest; afastar demais prejudica silhuetas e texto. Alternância rápida de contexto não pode provocar zoom oscilando. Tremor existente também precisa ser integrado para não disputar o controle da câmera.
- **Telegrafia e tempo:** ter o campo `cast_time` não garante janela legível. `moves.json` contém valores `0.0` e `0.3`; logo, exigir aviso de pelo menos `0.4 s` para todo golpe com cast não cabe em todos os tempos atuais. Não vou atrasar o dano nem alterar cast para satisfazer uma animação. Claude deve esclarecer o critério. Interrupção precisa remover o aviso imediatamente; expirar por um timer visual apenas pode mostrar ataque que já foi cancelado.
- **HUD e toque:** a barra atual usa botões mínimos de `52×30` em fila única; oito somam pelo menos 458 unidades de largura com os intervalos. Isso não comprova usabilidade em portrait. Stamina, ordens, skills e captura precisam caber sem cobrir o campo de luta ou disputar gestos. Entrada V2 cruza os dois domínios: intenção, prioridade entre UI e mundo e remapeamento precisam de acordo antes da integração.
- **Escala dos Pokémon:** já existe `scripts/combat/PokemonScale.gd`, usado pelo seguidor e pelos selvagens, com apoio na base do sprite e sombra. Reutilizar essa fonte, sem criar tabela por nome de espécie. Compressão visual de gigantes é minha; não resolve por si só bloqueio físico. Colisão, distância do seguidor e travessia do treinador são de gameplay. Não escalar o corpo físico para corrigir a arte. Precisamos conferir pivô, contato dos pés, sombra e animação com movimento real para evitar flutuação.
- **Legibilidade:** terreno, alvo, aliado e área perigosa precisam continuar distinguíveis com criaturas grandes e efeitos sobrepostos. Usar contorno/forma além de cor; efeitos decorativos não podem esconder aviso de ataque. Limitar efeitos simultâneos e atualizar HUD por sinais, sem reconstrução a cada frame.
- **Estado de captura:** `corpo_apareceu(id, segundos)` e `corpo_expirou(id)` não bastam para mostrar tentativa em andamento, resultado, remoção por captura ou estado inicial ao reabrir a UI. Claude precisa expor o estado real. A UI não decide se ainda é permitido capturar com base no próprio contador.
- **Isolamento:** o plano promete classes compartilhadas intactas e rollback por apagar duas pastas, mas também prevê editar `DamageCalculator` e `CombatBalance`, adicionar sinais e ajustar export. Essas promessas são incompatíveis sem delimitar exceções. Claude deve corrigir o plano de isolamento e regressão; eu não escolho uma nova fórmula nem considero essas alterações invisíveis à V1.
- **Validação:** 50 FPS no cenário de estresse proposto não substitui a meta de 60 FPS em gameplay normal. Medir ambiente, resolução e carga no navegador, com desktop, portrait e landscape. Esta rodada é documental; não houve playtest nem medição de FPS.

## O que Claude não deve fazer

- Não redesenhar HUD, posições, tamanho de botões, ícones, tipografia ou menus para acomodar a V2.
- Não substituir câmeras das cenas, escolher zoom final, tremor, curva ou duração de transição.
- Não alterar escala, pivô, sombra, sprites, animações ou timing exclusivamente visual, mesmo em arquivos dentro de `scripts/combat/`.
- Não implementar desenho de telegrafia, efeitos de crítico, tela de corpo/loot ou acesso visual ao Laboratório por conta própria.
- Não fechar sozinho sinais, estrutura compartilhada de cenas ou interação de toque. Expor estado e responder às lacunas acima antes da implementação cruzada.

## Alcance desta entrega

Somente revisão gravada. Por pedido expresso do Gabriel, não alterei a RFC original, decisões, handoff, código, dados ou cenas. Os sinais novos continuam propostos; este arquivo não declara acordo bilateral sobre os acréscimos pedidos aqui. Sem commit.
