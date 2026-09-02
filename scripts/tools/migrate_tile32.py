#!/usr/bin/env python3
"""Migração mecânica TILE_SIZE 16 -> 32.

Dobra toda quantidade espacial (posição, raio/altura de colisão, tamanho de
retângulo de colisão, limites de câmera) nas cenas do MUNDO do jogo
(scenes/world, scenes/entities, scenes/combat) e ajusta o zoom da câmera pra
1.5 (metade de 3.0) pra manter a mesma área visível depois que o tile dobrou
de tamanho física. NÃO toca scenes/ui nem scenes/battle (telas de interface,
espaço de Control, não é espaço de mundo).

Rodar uma vez, revisar o diff, rodar os testes, e só então comitar.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGET_DIRS = [ROOT / "scenes" / "world", ROOT / "scenes" / "entities", ROOT / "scenes" / "combat"]

def fmt(n: float) -> str:
    if abs(n - round(n)) < 1e-9:
        return str(int(round(n)))
    s = f"{n:.6f}".rstrip("0").rstrip(".")
    return s

def double_scalar(m: re.Match) -> str:
    key, val = m.group(1), m.group(2)
    return f"{key} = {fmt(float(val) * 2)}"

def double_vector2(m: re.Match) -> str:
    key, a, b = m.group(1), m.group(2), m.group(3)
    return f"{key} = Vector2({fmt(float(a) * 2)}, {fmt(float(b) * 2)})"

def process(path: Path) -> bool:
    text = path.read_text()
    original = text

    # position = Vector2(x, y)  — posição de nó (spawn, offset de shape, etc.)
    text = re.sub(r"(position) = Vector2\(([-\d.]+),\s*([-\d.]+)\)", double_vector2, text)

    # size = Vector2(x, y) — RectangleShape2D (zonas de warp/porta)
    text = re.sub(r"(size) = Vector2\(([-\d.]+),\s*([-\d.]+)\)", double_vector2, text)

    # radius = N / height = N — CapsuleShape2D / CircleShape2D.
    # (?<!spawn_) exclui spawn_radius (PokemonSpawner), que é em TILES, não
    # pixels — achado ao rodar pela 1a vez: "spawn_radius = 30" tinha virado
    # 60 sem eu perceber, por bater o "radius" como substring.
    text = re.sub(r"(?<!spawn_)\b(radius) = ([-\d.]+)", double_scalar, text)
    text = re.sub(r"\b(height) = ([-\d.]+)", double_scalar, text)

    # limit_left/top/right/bottom = N (int) — Camera2D
    text = re.sub(r"(limit_left) = (-?\d+)", double_scalar, text)
    text = re.sub(r"(limit_top) = (-?\d+)", double_scalar, text)
    text = re.sub(r"(limit_right) = (-?\d+)", double_scalar, text)
    text = re.sub(r"(limit_bottom) = (-?\d+)", double_scalar, text)

    # zoom = Vector2(3, 3) -> Vector2(1.5, 1.5) — compensa o mundo ter dobrado
    text = re.sub(r"zoom = Vector2\(3,\s*3\)", "zoom = Vector2(1.5, 1.5)", text)
    text = re.sub(r"zoom = Vector2\(3\.0,\s*3\.0\)", "zoom = Vector2(1.5, 1.5)", text)

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
