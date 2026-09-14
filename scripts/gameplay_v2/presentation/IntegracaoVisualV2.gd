## Liga os componentes visuais do Codex aos contratos reais do Laboratório.
## Não calcula estado de gameplay: nasce de `Laboratorio.estado()` e depois
## atualiza somente pelos sinais das entidades V2.
class_name IntegracaoVisualV2
extends Node

const AJUDA_PADRAO := "1–4 SKILLS  •  CLIQUE: ALVO/MOVER  •  Q: TROCAR"

@onready var laboratorio : Node = get_parent()
@onready var camera : CameraDeCombate = $"../CameraDeCombate"
@onready var hud : HudV2 = $"../HudV2"
@onready var telegraph : TelegraphV2 = $"../TelegraphV2"

var _pokemon : Node = null
var _alvo_id : int = 0
var _inimigos : Dictionary = {}
var _aviso_versao : int = 0

func _ready() -> void:
	call_deferred("_integrar")

func _exit_tree() -> void:
	var ponte := get_node_or_null("/root/PonteDeFeedback")
	if ponte != null:
		ponte.remover_fonte("ui_v2")
		ponte.remover_fonte("camera_v2")

func _integrar() -> void:
	if not laboratorio.has_method("estado"):
		push_error("IntegracaoVisualV2 requer Laboratorio.estado()")
		return

	var snapshot : Dictionary = laboratorio.estado()
	hud.aplicar_estado_inicial(snapshot)
	hud.definir_ajuda(AJUDA_PADRAO)
	_indexar_inimigos()

	var pokemon_estado : Dictionary = snapshot.get("pokemon", {})
	_alvo_id = int(pokemon_estado.get("alvo_id", 0))
	_conectar_treinador(laboratorio.get("treinador"))
	_conectar_pokemon(laboratorio.get("pokemon"))
	_conectar_se_existe(laboratorio, "pokemon_ativo_mudou", Callable(self, "_ao_pokemon_trocou"))
	_conectar_se_existe(laboratorio, "contexto_de_camera", Callable(self, "_ao_contexto_camera"))
	_conectar_se_existe(hud, "skill_solicitada", Callable(self, "_ao_skill_solicitada"))

	var ponte := get_node_or_null("/root/PonteDeFeedback")
	if ponte != null:
		ponte.registrar_fonte("ui_v2", Callable(hud, "contexto_feedback"))
		ponte.registrar_fonte("camera_v2", Callable(camera, "contexto_feedback"))
		ponte.anotar("interface visual V2 conectada")

func _conectar_treinador(treinador: Node) -> void:
	if treinador == null:
		return
	_conectar_se_existe(treinador, "vida_mudou", Callable(hud, "atualizar_vida_treinador"))
	_conectar_se_existe(treinador, "stamina_mudou", Callable(hud, "atualizar_stamina"))

func _conectar_pokemon(novo: Node) -> void:
	if novo == null or not is_instance_valid(novo):
		return
	if is_instance_valid(_pokemon) and _pokemon != novo:
		_desconectar_combatente(_pokemon)
		_desconectar_se_existe(_pokemon, "vida_mudou", Callable(hud, "atualizar_vida_pokemon"))
		_desconectar_se_existe(_pokemon, "recarga_mudou", Callable(hud, "atualizar_recarga"))
		_desconectar_se_existe(_pokemon, "ordem_mudou", Callable(self, "_ao_ordem_mudou"))
	_pokemon = novo
	_conectar_se_existe(novo, "vida_mudou", Callable(hud, "atualizar_vida_pokemon"))
	_conectar_se_existe(novo, "recarga_mudou", Callable(hud, "atualizar_recarga"))
	_conectar_se_existe(novo, "ordem_mudou", Callable(self, "_ao_ordem_mudou"))
	_conectar_combatente(novo)
	camera.definir_alvos(laboratorio.get("treinador") as Node2D, novo as Node2D)

func _indexar_inimigos() -> void:
	_inimigos.clear()
	for inimigo in get_tree().get_nodes_in_group("selvagem_v2"):
		if not inimigo is Node:
			continue
		var id := int(inimigo.get_instance_id())
		_inimigos[id] = inimigo
		_conectar_combatente(inimigo)
		_conectar_se_existe(inimigo, "vida_mudou", Callable(self, "_ao_vida_inimigo").bind(id))
		_conectar_se_existe(inimigo, "derrotado", Callable(self, "_ao_inimigo_derrotado").bind(id))

func _conectar_combatente(combatente: Node) -> void:
	_conectar_se_existe(combatente, "golpe_telegrafado", Callable(telegraph, "mostrar_golpe"))
	_conectar_se_existe(combatente, "telegrafia_encerrada", Callable(telegraph, "encerrar_golpe"))

func _desconectar_combatente(combatente: Node) -> void:
	_desconectar_se_existe(combatente, "golpe_telegrafado", Callable(telegraph, "mostrar_golpe"))
	_desconectar_se_existe(combatente, "telegrafia_encerrada", Callable(telegraph, "encerrar_golpe"))

func _ao_pokemon_trocou(estado: Dictionary) -> void:
	_conectar_pokemon(laboratorio.get("pokemon"))
	hud.atualizar_pokemon(estado)
	var kit : Array = estado.get("kit", [])
	hud.atualizar_skills(kit, int(estado.get("capacidade", kit.size())))
	_ao_ordem_mudou(str(estado.get("ordem", "seguir")), int(estado.get("alvo_id", 0)))
	_anotar("UI V2 recebeu troca para %s" % str(estado.get("nome", "Pokémon")))

func _ao_ordem_mudou(tipo: String, alvo_id: int) -> void:
	_alvo_id = alvo_id
	var alvo := _dados_do_alvo(alvo_id)
	hud.atualizar_ordem(tipo, str(alvo.get("nome", "")))
	hud.atualizar_alvo(alvo)

func _ao_vida_inimigo(_atual: int, _maximo: int, id: int) -> void:
	if id == _alvo_id:
		hud.atualizar_alvo(_dados_do_alvo(id))

func _ao_inimigo_derrotado(_quem: Node, id: int) -> void:
	if id == _alvo_id:
		hud.atualizar_alvo({})

func _dados_do_alvo(id: int) -> Dictionary:
	if id == 0:
		return {}
	var snapshot : Dictionary = laboratorio.estado()
	for candidato in snapshot.get("inimigos", []):
		if candidato is Dictionary and int(candidato.get("id", 0)) == id:
			var dados : Dictionary = candidato.duplicate(true)
			var no : Node = _inimigos.get(id)
			dados["categoria"] = "ALPHA" if no != null and String(no.name).ends_with("_ALPHA") else "SELVAGEM"
			return dados
	return {}

func _ao_contexto_camera(nome: String, prioridade: int) -> void:
	camera.ao_contexto_de_camera(nome, prioridade)
	_anotar("câmera V2: %s" % nome)

func _ao_skill_solicitada(slot: int) -> void:
	var motivo := str(laboratorio.usar_skill(slot))
	_anotar("UI V2 encaminhou golpe %d%s" % [slot + 1,
		"" if motivo.is_empty() else " (%s)" % motivo])
	if not motivo.is_empty():
		_mostrar_aviso(motivo.to_upper())

func _mostrar_aviso(texto: String) -> void:
	_aviso_versao += 1
	var versao := _aviso_versao
	hud.definir_ajuda(texto)
	await get_tree().create_timer(1.6).timeout
	if versao == _aviso_versao and is_instance_valid(hud):
		hud.definir_ajuda(AJUDA_PADRAO)

func _anotar(texto: String) -> void:
	var ponte := get_node_or_null("/root/PonteDeFeedback")
	if ponte != null:
		ponte.anotar(texto)

func _conectar_se_existe(no: Node, sinal: StringName, callback: Callable) -> void:
	if no != null and no.has_signal(sinal) and not no.is_connected(sinal, callback):
		no.connect(sinal, callback)

func _desconectar_se_existe(no: Node, sinal: StringName, callback: Callable) -> void:
	if no != null and is_instance_valid(no) and no.has_signal(sinal) and no.is_connected(sinal, callback):
		no.disconnect(sinal, callback)
