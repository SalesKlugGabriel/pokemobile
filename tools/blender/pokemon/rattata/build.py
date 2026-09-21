## Gera o Rattata #19 de modo determinístico: fonte Blender + GLB runtime.
import bpy
import os
import sys

PASTA = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(PASTA, "../../../.."))
if PASTA not in sys.path:
    sys.path.insert(0, PASTA)

import animation
import export
import materials
import model
import rig


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    malha = model.criar_rattata(materials.criar_materiais())
    frente = model.normalizar_para_godot(malha, 0.30)
    armature = rig.criar(malha)
    animation.criar(armature)
    fonte, glb = export.salvar_e_exportar(armature, malha, frente, RAIZ)
    print("RATTATA_SOURCE=", fonte)
    print("RATTATA_GLB=", glb)
    print("RATTATA_TRIANGLES=", sum(len(pol.vertices) - 2 for pol in malha.data.polygons))


if __name__ == "__main__":
    main()
