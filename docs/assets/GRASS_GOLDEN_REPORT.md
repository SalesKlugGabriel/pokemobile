# Golden Grass — relatório

**Assets:** `grass_short.glb`, `grass_mid.glb`, `grass_tall.glb`  
**Tipo:** clusters de cards estilizados para instancing  
**Variações:** curta (0,32 m), média (0,58 m) e alta (0,92 m)  
**Estrutura:** seis lâminas radiais por cluster, com frente e verso para leitura em tempo real  
**Materiais:** três paletas PBR de verde  
**Export:** GLB, origem no solo, orientação Godot validada  
**Godot test:** PASS — três GLBs importados via `MultiMesh`  
**Distribuição:** seed determinística; curta/média no terreno e alta concentrada na floresta  
**Performance:** sem Node individual por lâmina; instancing por variante  

## Limitações conhecidas

- Shader de vento por vértice ainda é o próximo refinamento visual.
- Máscaras de caminho e borda de água ainda precisam de ajuste fino na Golden Scene.
