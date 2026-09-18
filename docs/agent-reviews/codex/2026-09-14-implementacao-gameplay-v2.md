# Revisão Codex — primeira implementação da Gameplay V2

**Data:** 14/09/2026

**Branch revisada:** `main`

**Commit:** `9837cee`
**Resultado dos testes focados:** 70 verificações, 0 falhas

## Veredito

Os componentes puros de locomoção, stamina e dano foram implementados e o teste
focado passa. Os passos 1 e 2 do plano ainda não podem ser chamados de jogáveis:
não existe `Laboratorio.tscn`, `CorpoLivre` e `Stamina` ainda não têm consumidor,
e os contratos de estado prometidos para a apresentação ainda não existem.

O Codex pode avançar câmera, HUD e telegrafia como componentes isolados. A
integração real fica bloqueada até o gameplay publicar os sinais e o snapshot
aceitos na D-001.

## Conferência do que foi entregue

| Item atribuído ao Claude | Estado medido | Evidência |
|---|---|---|
| Plano e RFC antes do código | concluído | commits `5a97226` e `9837cee` |
| Movimento contínuo | componente puro concluído; não jogável | `Locomocao.gd` e `CorpoLivre.gd`; nenhuma cena/entrada V2 |
| Stamina e exaustão | regra pura concluída; não integrada | `Stamina.gd`; nenhum consumidor ou `stamina_mudou` |
| Dano determinístico | saída repetível no teste; duas ressalvas abaixo | `DanoV2.gd`, teste com 1.000 repetições |
| Estado inicial das recargas | concluído | `FollowerPokemon.estado_das_recargas()` |
| Estado inicial completo da V2 | ausente | não existe `EstadoV2` nem `instantaneo()` |
| Cena de laboratório | ausente | não existe `scenes/gameplay_v2/` |
| Contratos de câmera/telegrafia/corpo | acordados, não implementados | nenhum dos sinais da D-001 existe no runtime |

## Correções necessárias no domínio de gameplay

1. **Speed e cooldown.** O plano marca a redução universal por Speed como
   compatível, mas a especificação diz que Speed não reduz universalmente o
   cooldown das skills. A V2 precisa separar frequência do ataque básico,
   aproximação de TARGET e cooldown de skill.
2. **Teto de dano.** `DanoV2` conserva o teto universal de 90% do HP. A decisão
   ainda estava aberta no próprio plano e conflita com a exigência de manter 4x
   literalmente 4x, inclusive contra Alpha/boss.
3. **RNG colateral.** `DanoV2` chama `DamageCalculator.detalhar()` e descarta
   crítico/variância depois. A saída fica repetível, mas os sorteios ainda
   avançam o RNG global e podem mudar status, captura ou loot. A V2 precisa de
   um caminho de cálculo que não consuma sorte.
4. **Interrupção.** O cast atual espera um timer e só confere validade/morte.
   Sleep e locks de Paralysis aplicados durante a janela não cancelam o golpe;
   Freeze hoje bloqueia todas as skills, inclusive as usáveis parado.
5. **Captura.** O diagnóstico deve ser atualizado: a V1 já exige alvo derrotado
   e já mantém corpo. A diferença da V2 é a janela de 10–15 s e uma única
   tentativa. Alpha também precisa ser explicitamente não capturável.
6. **Estado para apresentação.** Implementar `EstadoV2.instantaneo()` e os
   sinais aceitos para stamina, ordem, contexto de câmera, cast e corpo. Sinal
   de mudança sozinho não reconstrói uma HUD aberta no meio de uma ação.

## Correções documentais necessárias

- Atualizar o plano de “proposta, nada implementado” para o estado real.
- Consolidar na RFC as assinaturas aceitas hoje terceirizadas para a resposta.
- Alterar o status da RFC para `IMPLEMENTING` e remover “aguardando revisão”.
- Trocar o rollback literal “apagar duas pastas” por rollback por commits e uma
  lista de exceções compartilhadas. O commit já alterou `FollowerPokemon.gd` e
  colocou teste fora de `gameplay_v2/`.
- Registrar custos e o teto de 60% de Efficiency como parâmetros provisórios
  data-driven. Esses números não estavam especificados pelo Gabriel.
- Fechar `cast_time` como tempo mecânico do gameplay; o Codex controla apenas a
  linguagem visual dentro dessa janela.

## Divisão desta rodada

**Claude:** cena/base jogável, entrada, integração de stamina, estado/sinais,
ordens, IA, combate, captura, loot, progressão, derrota e testes lógicos.

**Codex:** `CameraDeCombate`, HUD V2, renderer de telegrafia, feedback visual e
cena isolada de apresentação. A cena visual usa dados de demonstração somente
para validar apresentação; não declara o vertical slice concluído.

Arquivos compartilhados (`EventBus.gd`, `project.godot`, cena raiz do
Laboratório e documentos de decisão) só entram por commit integrado e revisão
cruzada.
