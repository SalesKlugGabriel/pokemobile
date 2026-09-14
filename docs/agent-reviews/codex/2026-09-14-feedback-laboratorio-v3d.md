# Feedback do Laboratório V3D — 14/09/2026

## Observado no teste web

- A cena abre e o fluxo 3D funciona.
- O movimento para frente é percebido como movimento em direção à câmera; a
  relação entre `W`, o yaw e a posição da câmera precisa de uma prova visual.
- O ponteiro é capturado sem indicador de mira/foco e a rotação parece caótica.
- O treinador ainda é uma cápsula amarela de placeholder.
- O primeiro Charizard tinha silhueta genérica de urso com asas.

## Entregas visuais do Codex

- `assets/models/pokemon/6.glb`: Charizard refinado, com olhos, sobrancelhas,
  narinas, asas mais abertas e leitura frontal em -Z.
- `assets/models/trainer/player.glb`: treinador low-poly com cabeça, boné,
  torso, mochila, braços, botas e dois materiais.

## Correções de controle sugeridas ao Claude

1. Desenhar um gizmo temporário no laboratório: uma seta verde para `frente`,
   uma vermelha para `direita` e um retículo no centro da viewport. Isso torna
   impossível confundir o sinal do eixo com a posição da câmera.
2. Capturar o mouse somente após clique no canvas; liberar com `Esc` e mostrar
   um pequeno retículo enquanto capturado. Sem foco/captura, ignorar movimento
   relativo do ponteiro.
3. Validar no teste automatizado: yaw 0 + `W` deve mover no vetor que o jogador
   chama de frente; yaw 90° + `W` deve girar esse vetor exatamente 90°; `S`
   deve ser o oposto. Não corrigir apenas invertendo um sinal sem esse teste.
4. Integrar `player.glb` como visual do `TrainerController3D`, mantendo a
   cápsula exclusivamente como colisor.

## Commits

- `7f4f577` — Charizard refinado.
- `d7ac5e3` — modelo visual do treinador.
