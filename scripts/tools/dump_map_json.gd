## dump_map_json.gd — Exporta o grid de um mapa (MapLayouts) pra JSON, uso
## pelo Editor Visual (poke.workprog.pro/editor — /root/pokemobile-editor,
## repositório à parte). O editor não reimplementa a geração procedural em
## JS; ele lê o resultado já pronto daqui pra saber o que existe no mapa
## antes de deixar o Gabriel editar em cima. Rodar de novo só se a geração
## procedural de um mapa aqui mudar (senão o editor mostra um grid velho).
## Roda com: godot4 --headless --script res://scripts/tools/dump_map_json.gd
extends SceneTree

func _initialize() -> void:
	var out_dir := "/root/pokemobile-editor-data/maps"
	DirAccess.make_dir_recursive_absolute(out_dir)

	for map_id in ["world_map"]:
		var layout : Dictionary = MapLayouts.get_layout(map_id)
		var tiles : Array = layout.get("tiles", [])
		var data := {
			"map_id": map_id,
			"width": layout.get("width", 0),
			"height": layout.get("height", 0),
			"rows": tiles,
		}
		var path := "%s/%s.json" % [out_dir, map_id]
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(data))
		f.close()
		print("Exportado: %s (%d linhas)" % [map_id, tiles.size()])

	quit()
