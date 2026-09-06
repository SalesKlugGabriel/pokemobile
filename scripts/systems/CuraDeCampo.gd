## CuraDeCampo.gd — Usar remédio fora de batalha (06/09).
##
## 🔴 Este arquivo existe por causa de um buraco grande, achado ao começar a
## Etapa 2 das Dungeons Elementais: **nenhum dos 17 remédios do jogo podia ser
## usado fora de uma batalha por turno**. A Mochila respondia "só pode ser usado
## numa batalha por enquanto" — e desde o corte do combate por turno (02/09) a
## batalha por turno só existe na Zona Safari. Ou seja: na prática o jogo
## inteiro estava sem cura, e ninguém tinha percebido porque o dano do Follower
## também sumia sozinho a cada troca de mapa (corrigido no mesmo lote).
##
## Era isso que tornava o plano de "risco real" impossível: não adianta pôr
## cooldown de 8 segundos numa cura que não existe.
##
## Regras de quem cura o quê (as do jogo clássico, e é o que o jogador espera):
##   · Poção não ressuscita — em Pokémon desmaiado ela não funciona, e dizer
##     isso é melhor que gastar o item à toa.
##   · Reviver só funciona em desmaiado, nunca como cura comum.
##   · Curar HP num Pokémon já cheio não gasta o item.
##
## Dentro de uma dungeon, quem manda é RegrasDeCovil (espera de 8 s, mochila
## lacrada, 3 usos na arena). Fora dela, a cura é livre — de propósito: lá o
## teste é economia de recurso, aqui é execução.
class_name CuraDeCampo
extends RefCounted

## Aplica o item no Pokémon do índice. Não mexe no inventário — quem chama é
## que decide remover, depois de ver que deu certo.
## Devolve `{ok: bool, texto: String}`; o texto é escrito pro jogador.
static func aplicar(item_id: String, indice: int) -> Dictionary:
	var raiz = Engine.get_main_loop().root if Engine.get_main_loop() else null
	if raiz == null:
		return {"ok": false, "texto": "Não deu pra usar agora."}
	var salvar = raiz.get_node_or_null("SaveManager")
	var dados_jogo = raiz.get_node_or_null("GameData")
	if salvar == null or dados_jogo == null:
		return {"ok": false, "texto": "Não deu pra usar agora."}

	var item : Dictionary = dados_jogo.get_item(item_id)
	if item.is_empty():
		return {"ok": false, "texto": "Item desconhecido."}

	var time : Array = salvar.get_team()
	if indice < 0 or indice >= time.size():
		return {"ok": false, "texto": "Pokémon inválido."}
	var poke : Dictionary = time[indice]

	var vida : int = int(poke.get("hp_current", 0))
	var vida_max : int = maxi(1, int(poke.get("hp_max", 1)))
	var desmaiado := vida <= 0
	var mudou := false
	var texto := ""

	# ── Reviver ────────────────────────────────────────────────────────────
	if item.has("revive_hp"):
		if not desmaiado:
			return {"ok": false, "texto": "Esse Pokémon não está desmaiado."}
		var fracao : float = float(item.get("revive_hp", 0.5))
		# -1 no JSON quer dizer "vida cheia" (Max Revive).
		var nova : int = vida_max if fracao < 0.0 else maxi(1, int(round(vida_max * fracao)))
		poke["hp_current"] = mini(nova, vida_max)
		poke["status"] = "none"
		mudou = true
		texto = "Voltou com %d de HP!" % poke["hp_current"]

	# ── Curar HP ───────────────────────────────────────────────────────────
	elif item.has("heal_hp"):
		if desmaiado:
			return {"ok": false, "texto": "Não funciona em Pokémon desmaiado — use um Reviver."}
		if vida >= vida_max:
			return {"ok": false, "texto": "Esse Pokémon já está com a vida cheia."}
		var quanto : int = int(item.get("heal_hp", 0))
		# -1 quer dizer "tudo" (Full Restore).
		var alvo : int = vida_max if quanto < 0 else mini(vida_max, vida + quanto)
		var curou : int = alvo - vida
		poke["hp_current"] = alvo
		mudou = true
		texto = "Recuperou %d de HP!" % curou
		if bool(item.get("heal_status", false)) and str(poke.get("status", "none")) != "none":
			poke["status"] = "none"
			texto += " E o status foi curado."

	# ── Curar status ───────────────────────────────────────────────────────
	elif item.has("cures"):
		var estado : String = str(poke.get("status", "none"))
		if estado == "none":
			return {"ok": false, "texto": "Esse Pokémon não tem nenhum status pra curar."}
		var lista : Array = item.get("cures", [])
		if not ("all" in lista or estado in lista):
			return {"ok": false, "texto": "Esse remédio não cura esse status."}
		poke["status"] = "none"
		mudou = true
		texto = "O status foi curado!"

	# ── Restaurar PP ───────────────────────────────────────────────────────
	elif item.has("restore_pp"):
		var golpes : Array = poke.get("moves", [])
		if golpes.is_empty():
			return {"ok": false, "texto": "Esse Pokémon não tem golpes."}
		var quanto_pp : int = int(item.get("restore_pp", 0))
		var todos : bool = str(item.get("target", "")) == "all_moves"
		var recuperou := 0
		for i in golpes.size():
			var g : Dictionary = golpes[i]
			var pp : int = int(g.get("pp", 0))
			var pp_max : int = int(g.get("pp_max", 0))
			if pp >= pp_max:
				continue
			g["pp"] = pp_max if quanto_pp < 0 else mini(pp_max, pp + quanto_pp)
			recuperou += int(g["pp"]) - pp
			golpes[i] = g
			if not todos:
				break
		if recuperou <= 0:
			return {"ok": false, "texto": "Os golpes já estão com PP cheio."}
		poke["moves"] = golpes
		mudou = true
		texto = "Recuperou %d de PP!" % recuperou
	else:
		return {"ok": false, "texto": "Esse item não é um remédio."}

	if not mudou:
		return {"ok": false, "texto": "Não teve efeito."}

	salvar.update_team_pokemon(indice, poke)
	salvar.save_game()
	# O Pokémon do slot 0 é o que está no mapa: curar no save sem curar o que
	# está lutando seria curar um número, não o Pokémon.
	if indice == 0:
		sincronizar_follower(int(poke.get("hp_current", 0)))
	return {"ok": true, "texto": texto}

## Empurra o HP do save pro Follower que está em cena.
static func sincronizar_follower(vida: int) -> void:
	var laco := Engine.get_main_loop()
	if laco == null or not (laco is SceneTree):
		return
	for f in (laco as SceneTree).get_nodes_in_group("follower_pokemon"):
		if not is_instance_valid(f):
			continue
		if "current_hp" in f and "max_hp" in f:
			f.current_hp = clampi(vida, 0, int(f.max_hp))
			if f.current_hp > 0 and ("_is_fainted" in f):
				f._is_fainted = false
				if f.sprite:
					f.sprite.modulate = Color(1, 1, 1, 1)
			# Pelo nó, não pelo identificador global: `class_name` que cita
			# autoload direto não carrega em teste headless.
			var barramento = (laco as SceneTree).root.get_node_or_null("EventBus")
			if barramento != null:
				barramento.follower_hp_changed.emit(f.current_hp, f.max_hp)
		break
