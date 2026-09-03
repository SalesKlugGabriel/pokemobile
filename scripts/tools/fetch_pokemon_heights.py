#!/usr/bin/env python3
"""Baixa a altura oficial (Pokédex) das 151 espécies da PokeAPI (mesma fonte
já usada pra baixar as sprites, 02/09) e guarda num JSON local — pedido do
Gabriel (03/09, prompt de sistema de escala): "o tamanho visual deve
respeitar a altura oficial registrada na Pokédex". Guardado localmente (em
vez de buscar em tempo real) pelo mesmo motivo que as sprites já são
baixadas uma vez e commitadas: o jogo não pode depender de internet pra
carregar uma espécie.

Unidade: PokeAPI devolve altura em DECÍMETROS (ex: 4 = 0,4m = Pikachu) —
convertido aqui direto pra METROS, que é a unidade que o resto do sistema
(PokemonScale) vai usar.
"""
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "data" / "pokemon" / "heights.json"


def fetch_height_m(species_id: int) -> float | None:
    url = f"https://pokeapi.co/api/v2/pokemon/{species_id}"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (PokeMobile dev script)"})
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read())
        return round(data["height"] / 10.0, 2)
    except Exception as e:
        print(f"  aviso: falhou id {species_id}: {e}")
        return None


def main() -> None:
    start = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    end = int(sys.argv[2]) if len(sys.argv) > 2 else 151
    heights = {}
    if OUT.exists():
        heights = json.loads(OUT.read_text())
    ok, fail = 0, 0
    for sid in range(start, end + 1):
        h = fetch_height_m(sid)
        if h is not None:
            heights[str(sid)] = h
            ok += 1
        else:
            fail += 1
        if sid % 25 == 0:
            print(f"[{sid}/151] ...")
    ordered = {k: heights[k] for k in sorted(heights, key=int)}
    OUT.write_text(json.dumps(ordered, separators=(",", ":")))
    print(f"\nConcluído: {ok} espécie(s), {fail} falharam. Salvo em {OUT}")


if __name__ == "__main__":
    main()
