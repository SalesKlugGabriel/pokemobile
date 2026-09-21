# RFC-009 — Orientação do corpo em terceira pessoa

**Status:** IMPLEMENTED · decisão direta do Gabriel em 21/09/2026
**Owner:** Codex (apresentação/integração 3D)
**Reviewer:** Gabriel (direção de produto)

## Decisão

O corpo visual do treinador gira para a direção real de deslocamento. A câmera
continua sendo a fonte de mira para pokébola e ataques; ela não força mais o
yaw do modelo.

## Motivo

Atrelar `rotation.y` ao yaw da câmera mantinha o personagem voltado ao
observador e fazia a caminhada parecer de costas. W permanece relativo à frente
da câmera; A/D precisa demonstrar que o corpo acompanha a própria velocidade,
não a câmera.

## Verificação

`teste_controles_v3.gd` cobre W, câmera independente e uma passada lateral:
movimento existe, frente do corpo alinha ao deslocamento e o yaw diverge do da
câmera quando necessário.
