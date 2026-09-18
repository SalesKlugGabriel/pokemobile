# Charizard Golden Asset — relatório

**Asset:** `assets/models/pokemon/6.glb`  
**Tipo:** Pokémon 3D estilizado, voador/terrestre  
**Escala:** 1,70 m de altura validada no Godot 4.x  
**Geometria:** 6.976 vértices / 3.382 triângulos  
**Materiais:** 7 slots PBR estilizados (corpo, olhos, barriga, asas, garras e chama)  
**Rig:** sim — armature anatômico com 14 bones e Armature Modifier  
**Animações:** `PKM_CHARIZARD_IDLE`, `WALK`, `RUN`, `ATTACK_01`, `HIT`, `FAINT`, `FLY`  
**Root motion:** in-place; posição e colisão pertencem ao Godot  
**LOD:** não criado ainda; arquitetura preserva um único mesh para futura geração de LODs  
**Export:** GLB, mesh + armature + materiais + Actions/NLA  
**Godot test:** PASS — orientação, AABB e lista de animações importadas sem erro de script  
**State machine:** PASS — locomoção seleciona `IDLE/WALK/RUN`; combate dispara `ATTACK_01/HIT/FAINT` sem mover o root físico  

## Limitações conhecidas

- O asset é o primeiro golden pass estilizado, ainda não um modelo cinematográfico.
- Pesos são rígidos por componente desconectado; a próxima etapa é refinar deformações de asa, cauda, mandíbula e quadril.
- A Golden Test Scene ainda está em construção; este asset foi validado isoladamente.
