#!/usr/bin/env python3
"""Migração mecânica TILE_SIZE 32 -> 128 (mesma técnica de migrate_tile32.py,
que fez 16->32 — aqui o fator é 4, não 2).

Pedido do Gabriel (03/09): a arte de 32px, mesmo redesenhada, não tem pixels
suficientes pra ter qualidade real — quer 128x128 "em todo o mapa" (chão,
árvores, paredes, janelas, portas, parede de rocha, piso vulcânico, piso de
gelo, Pokémon). Pra ganhar detalhe de verdade (não só "esticar" a arte
pequena), o pitch do MUNDO precisa virar 128 de verdade — só trocar o
tamanho da imagem sem migrar a grade faria o motor redimensionar a textura
grande pra caber no tile pequeno e detalhe nenhum sobreviveria.

Dobra (x4) toda quantidade espacial (posição, raio/altura de colisão,
tamanho de retângulo de colisão, limites de câmera) nas cenas do MUNDO do
jogo (scenes/world, scenes/entities, scenes/combat) e força o zoom da
câmera pra 1.0 — a arte agora nasce no tamanho final (128px = 1 tile em
tela), não precisa mais do "3x na marra" que fizemos em cima da arte de
32px pra ela parecer maior.

Rodar uma vez, revisar o diff, rodar os testes, e só então comitar.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGET_DIRS = [ROOT / "scenes" / "world", ROOT / "scenes" / "entities", ROOT / "scenes" / "combat"]
FACTOR = 4.0

def fmt(n: float) -> str:
    if abs(n - round(n)) < 1e-9:
        return str(int(round(n)))
    s = f"{n:.6f}".rstrip("0").rstrip(".")
    return s

def scale_scalar(m: re.Match) -> str:
    key, val = m.group(1), m.group(2)
    return f"{key} = {fmt(float(val) * FACTOR)}"

def scale_vector2(m: re.Match) -> str:
    key, a, b = m.group(1), m.group(2), m.group(3)
    return f"{key} = Vector2({fmt(float(a) * FACTOR)}, {fmt(float(b) * FACTOR)})"

def process(path: Path) -> bool:
    text = path.read_text()
    original = text

    # position = Vector2(x, y)  — posição de nó (spawn, offset de shape, etc.)
    text = re.sub(r"(position) = Vector2\(([-\d.]+),\s*([-\d.]+)\)", scale_vector2, text)

    # size = Vector2(x, y) — RectangleShape2D (zonas de warp/porta)
    text = re.sub(r"(size) = Vector2\(([-\d.]+),\s*([-\d.]+)\)", scale_vector2, text)

    # radius = N / height = N — CapsuleShape2D / CircleShape2D.
    # (?<!spawn_) exclui spawn_radius (tiles, não pixels) — mesma trava já
    # provada necessária na migração 16->32.
    text = re.sub(r"(?<!spawn_)\b(radius) = ([-\d.]+)", scale_scalar, text)
    text = re.sub(r"\b(height) = ([-\d.]+)", scale_scalar, text)

    # limit_left/top/right/bottom = N (int) — Camera2D
    text = re.sub(r"(limit_left) = (-?\d+)", scale_scalar, text)
    text = re.sub(r"(limit_top) = (-?\d+)", scale_scalar, text)
    text = re.sub(r"(limit_right) = (-?\d+)", scale_scalar, text)
    text = re.sub(r"(limit_bottom) = (-?\d+)", scale_scalar, text)

    # zoom = Vector2(qualquer, qualquer) -> Vector2(1, 1) — a arte agora
    # nasce no tamanho final, não precisa mais do zoom pra parecer maior.
    text = re.sub(r"zoom = Vector2\([-\d.]+,\s*[-\d.]+\)", "zoom = Vector2(1, 1)", text)

    if text != original:
        path.write_text(text)
        return True
    return False

def main() -> None:
    changed = []
    for d in TARGET_DIRS:
        for f in sorted(d.rglob("*.tscn")):
            if process(f):
                changed.append(f)
    print(f"{len(changed)} arquivo(s) alterado(s):")
    for f in changed:
        print(f" - {f.relative_to(ROOT)}")

if __name__ == "__main__":
    main()
