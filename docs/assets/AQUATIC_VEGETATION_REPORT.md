# Vegetação aquática — relatório

**Escopo:** Golden Test Scene 100 × 100 m  
**Algas:** 90 instâncias `MultiMesh`, exclusivas de água rasa/profunda  
**Corais:** 55 instâncias `MultiMesh`, exclusivas de água rasa  
**Árvores na água:** proibidas por filtro explícito de superfície (`agua_rasa`/`agua_profunda`) com tentativas múltiplas de reposicionamento  
**Colisão:** nenhuma; a decoração não cria paredes de gameplay  
**Godot test:** PASS — exportação Web sem erros de script  

## Próximos refinamentos

- substituir o coral placeholder por variantes orgânicas exportadas do Blender;
- adicionar shader de movimento às algas;
- criar cavernas como módulo separado depois dos gates da Golden Scene.
