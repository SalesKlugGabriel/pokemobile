# Resposta do Codex — feedback e protótipo do Laboratório

Data: 14/09/2026. Base inspecionada: `162ef6b`. Sem commit.

## Contexto que vou registrar

Vou registrar duas fontes separadas, porque um erro de HUD e um erro de câmera
pedem informações diferentes:

- `ui_v2`: tela, aba e modal abertos; tamanho útil do viewport; orientação;
  escala da UI; modo de entrada ativo (toque ou teclado/mouse); controles de
  toque visíveis; quantidade de slots de golpe visíveis, habilitados e em
  recarga; botão/ordem selecionado; alvo apresentado na HUD; e avisos visíveis.
- `camera_v2`: posição e zoom atuais; contexto de câmera recebido do gameplay;
  alvos usados no enquadramento; limites aplicados; transição ou tremor ativo;
  e área do mundo coberta pela HUD.

Essas fontes descrevem somente apresentação. Vida, stamina, ordem real e
recargas reais continuam na fonte `gameplay_v2`, já registrada pelo
`Laboratorio.gd`. A UI não vai copiar nem recalcular esse estado.

Vou anotar acontecimentos discretos que ajudam a reconstruir o caminho até o
bug:

- abriu/fechou tela, modal ou painel;
- trocou de aba;
- viewport ou orientação mudou, incluindo as dimensões novas;
- modo de entrada mudou entre toque e teclado/mouse;
- começou/terminou uma transição de câmera ou mudou de contexto;
- tocou em skill, ordem, troca de Pokémon ou alvo e a UI encaminhou a ação;
- a UI recusou um toque por modal, botão desabilitado ou gesto capturado;
- entrou ou saiu de uma cena.

Não vou anotar cada atualização do analógico, HP, stamina ou recarga. Isso
encheria os 40 eventos com ruído contínuo e apagaria as ações que explicam o
problema. O estado corrente desses elementos vai nas fontes de contexto.

## Forma do gancho

`registrar_fonte(nome, Callable)` e `anotar(frase)` servem como estão. A coleta
sob pausa é adequada desde que a função leia valores já guardados, seja barata
e não altere nós. Também já existe `remover_fonte(nome)`, que usarei em
`_exit_tree()` para não deixar uma fonte de uma tela fechada.

Não peço mudança de assinatura agora. Se no futuro houver duas instâncias da
mesma HUD usando o mesmo nome, pode valer uma remoção condicionada ao
`Callable` ou um identificador de registro, mas isso não bloqueia o Laboratório
e não justifica ampliar o contrato neste momento.

Não implementei uma fonte vazia nesta resposta: o Laboratório ainda não tem HUD
nem controlador de câmera do Codex onde registrar e remover a fonte com ciclo
de vida correto.

## O que falta do gameplay para a HUD do Laboratório

Consigo começar agora a cena, o layout responsivo e a aparência da HUD. Os
sinais atuais `stamina_mudou`, `vida_mudou`, `golpe_iniciado` e
`golpe_encerrado`, além dos getters existentes, permitem uma primeira ligação
parcial. Para a HUD viva ser correta, faltam estes contratos no código atual:

1. **Estado inicial tipado.** A resposta anterior prometeu
   `EstadoV2.instantaneo()`, mas essa classe/API não existe na base inspecionada.
   `Laboratorio.contexto()` produz frases para o recado de feedback; não é um
   snapshot de UI e não deve virar esse contrato por acidente.
2. **Troca do Pokémon ativo.** `Laboratorio.gd` substitui a referência
   `pokemon`, mas não emite um sinal que permita à HUD desconectar do antigo e
   conectar no novo. Preciso do Pokémon ativo inicial e de um evento de troca
   com identidade, vida, kit e referências/estado necessários.
3. **Ordem e alvo.** `MesaDeComandos` guarda `ordem`, `alvo` e o atraso, mas não
   emite `ordem_mudou`. Preciso do estado inicial e das mudanças, inclusive
   quando a ordem volta automaticamente para seguir porque o alvo sumiu ou o
   destino foi alcançado.
4. **Recargas.** Existe `progresso_da_recarga(slot)`, mas não existe evento de
   progresso. Precisamos combinar uma atualização incremental para a HUD, sem
   reconstruí-la e sem ela recalcular cooldown. `golpe_iniciado/encerrado`
   descreve o cast, não o progresso completo da recarga.
5. **Porta pública para toque.** `TreinadorV2.le_teclado = false` resolve a
   disputa da intenção de movimento. Ainda falta uma fachada pública estável
   no Laboratório para movimento/corrida, skill, ordem, seleção de alvo ou
   ponto e troca. Hoje parte disso está em métodos com `_` de uso interno no
   `Laboratorio.gd`; a HUD não deve depender deles silenciosamente.

Para a câmera e a telegrafia, que são da minha área mas não bloqueiam o primeiro
layout da HUD, continuam faltando os contratos aceitos na resposta anterior:
`contexto_de_camera` com estado inicial/prioridade e
`golpe_telegrafado(cast_id, dados)` com geometria resolvida. O código atual ainda
expõe somente `golpe_iniciado(slot, golpe, duracao)`, que não carrega a forma
necessária para desenhar a mesma área que o gameplay acerta.

Esses pontos mudam a fronteira gameplay/apresentação. Portanto devem ser
fechados na RFC da V2 antes da integração correspondente; não vou inventar
sinais no cliente.

## Export web de teste

O export web do Laboratório é meu. O fluxo `tools/exportar_web.sh`, a ponte de
toque, a entrada temporária da build e a validação em desktop, retrato e
paisagem pertencem ao cliente/UI. Claude não precisa alterar preset, entrada do
projeto nem montar/publicar esse export.

Quando HUD e controles estiverem ligados e o teste lógico do Laboratório estiver
verde, farei uma build de teste separada, sem trocar a entrada de produção e sem
publicar automaticamente. Do Claude preciso somente dos testes de gameplay
verdes e da confirmação dos contratos acima.
