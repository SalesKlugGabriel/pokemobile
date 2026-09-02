#!/usr/bin/env python3
"""Fase 3 do motor de combate em tempo real: acrescenta cooldown/target_type/
radius em data/moves/moves.json, sem mudar nada mais (mesma ordem, mesmo
formato — só append de campos novos por golpe).

FollowerPokemon.gd/WildPokemon.gd já liam "cooldown" com fallback 2.0s e
sempre trataram todo golpe como corpo-a-corpo/alvo único — golpes não
migrados continuam caindo nesse mesmo fallback, então rodar de novo com uma
lista de área maior no futuro é seguro (idempotente pros que já têm o campo).

Golpes de área: lista curada à mão (canonicamente multi-alvo no Pokémon de
verdade) — só os que existem de fato neste moves.json (158 golpes, geração 1).
Raio em pixels, calibrado por poder/alcance esperado do golpe.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MOVES_PATH = ROOT / "data" / "moves" / "moves.json"

AREA_MOVES = {
    "earthquake":   160.0,
    "surf":         160.0,
    "blizzard":     160.0,
    "rock_slide":   140.0,
    "self_destruct": 200.0,
    "explosion":    220.0,
}

def cooldown_for(power: int) -> float:
    # Golpe mais forte = cooldown maior (evita spam de golpe forte sem custo).
    return round(max(1.0, min(6.0, power / 20.0)), 1)

def main() -> None:
    with open(MOVES_PATH, encoding="utf-8") as f:
        data = json.load(f)

    changed = 0
    for move_id, move in data.items():
        if "cooldown" not in move:
            move["cooldown"] = cooldown_for(int(move.get("power", 40)))
            changed += 1
        if "target_type" not in move:
            move["target_type"] = "area" if move_id in AREA_MOVES else "single"
        if move_id in AREA_MOVES and "radius" not in move:
            move["radius"] = AREA_MOVES[move_id]

    with open(MOVES_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print(f"{changed} golpe(s) atualizado(s) de {len(data)} no total.")
    print(f"Golpes de área: {sorted(AREA_MOVES.keys())}")

if __name__ == "__main__":
    main()
