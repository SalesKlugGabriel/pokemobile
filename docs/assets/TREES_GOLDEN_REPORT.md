# Golden Trees — relatório

**Assets:** `tree_a.glb` … `tree_e.glb`  
**Tipo:** árvores stylized/organic para instancing  
**Variantes:** 5 silhuetas determinísticas, com seed de distribuição no Godot  
**Estrutura:** tronco, raízes expostas, 5 ramificações e clusters de folhagem  
**Materiais:** bark, bark-light e três tons de folha em PBR  
**Geometria de referência:** ~2.688 vértices / ~1.028 triângulos por árvore  
**Export:** GLB, malha única por variante, origem no solo  
**Godot test:** PASS — cinco GLBs importados e instanciados via `MultiMesh`  
**Golden Scene:** PASS técnico — floresta oeste com 60 instâncias, sem Nodes por árvore  

## Limitações conhecidas

- A paleta e a iluminação ainda estão em `WIP` no gate da Golden Scene.
- LODs ainda não foram gerados; a arquitetura permite adicionar `tree_*_lod1` posteriormente.
