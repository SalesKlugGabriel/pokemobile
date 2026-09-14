## PokemonInstance3D.gd — Um Pokémon no mundo 3D (§14).
##
## *"Não colocar comportamento inteiro dentro de scripts específicos de espécie.
## Preferir: PokemonInstance + PokemonSpeciesData + MovementProfile +
## CombatProfile."*
##
## Composição, não herança por bicho. **Não existe `Charizard.gd`** e nem deve
## existir: 151 arquivos que divergem sozinhos é como um sistema de criaturas
## morre.
##
## ── O que esta classe monta, e de onde tira cada coisa ──────────────────────
##
## ```
## species.json   → nome, tipos, stats base, catch_rate
## heights.json   → altura real em metros          (PokemonScale, já existia)
## MovementProfile→ velocidade, giro, gravidade, se nada, se voa
## CombatProfile  → colisor, hurtbox, alcance
## CameraProfile  → como se vê em 1ª pessoa
## StatsDePokemon → HP e stats no nível            (V2, sem alteração)
## BalanceV2      → a vida da V3                   (V2, sem alteração)
## ```
##
## Nenhum número de combate nasce aqui. Esta classe **monta**; quem calcula é a
## V2, que atravessou o pivô intacta.
extends CharacterBody3D
class_name PokemonInstance3D

signal vida_mudou(atual: int, maximo: int)
signal derrotado(quem: Node)

## 🔴 Decisão do Gabriel (14/09): os Pokémon são **modelos 3D**.
## Enquanto o modelo de uma espécie não existe, ela entra como primitivo — e
## **avisa**. Asset faltando que aparece como cápsula silenciosa é o mesmo zero
## silencioso que já mordeu este projeto três vezes.
const PASTA_DOS_MODELOS : String = "res://assets/models/pokemon/"

var species_id : int = 1
var nivel : int = 5
var nome_exibido : String = "?"
var tipos : Array = ["Normal"]
var stats : Dictionary = {}
var vida : int = 1
var vida_maxima : int = 1

var arquetipo : String = MovementProfile.GROUND_BIPED
var altura_real : float = 1.0
var altura : float = 1.0        ## já com a compressão de gigante (§6)

var tem_modelo : bool = false
var _visual : Node3D = null
var _derrotado : bool = false

# ──────────────────────────────────────────────────────────────────────────────
# Montagem
# ──────────────────────────────────────────────────────────────────────────────

func montar(id_especie: int, nv: int, arquetipo_pedido: String = "") -> void:
	species_id = id_especie
	nivel = maxi(1, nv)

	var esp : Dictionary = GameData.get_species(species_id)
	nome_exibido = str(esp.get("name", "#%d" % species_id))
	tipos = esp.get("types", ["Normal"])

	# As stats vêm da V2, sem adaptação nenhuma.
	stats = StatsDePokemon.conjunto(esp.get("base_stats", {}), nivel)
	vida_maxima = BalanceV2.vida(int(stats.get("hp", 1)))
	vida = vida_maxima

	# A altura real já existia em `heights.json` desde 03/09 — 151 espécies,
	# de 0,2 m (Diglett) a 8,8 m (Onix). Não precisou de dado novo.
	altura_real = PokemonScale.get_height_m(species_id)
	altura = MovementProfile.altura_jogavel(altura_real)

	arquetipo = arquetipo_pedido if arquetipo_pedido != "" \
		else str(esp.get("arquetipo", MovementProfile.GROUND_BIPED))

	_montar_corpo()
	_montar_visual()
	add_to_group("pokemon_v3")
	vida_mudou.emit(vida, vida_maxima)

## Colisor e hurtbox saem do `CombatProfile`, **nunca do modelo** — ver o
## cabeçalho de lá pro motivo.
func _montar_corpo() -> void:
	var c : Dictionary = CombatProfile.corpo(altura)
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = float(c["raio"])
	capsula.height = maxf(float(c["altura"]), capsula.radius * 2.0 + 0.01)
	forma.shape = capsula
	forma.position.y = capsula.height * 0.5
	forma.name = "Colisor"
	add_child(forma)

	# §22: hurtbox SEPARADA da hitbox de ataque, e um pouco maior que o corpo.
	var hb : Dictionary = CombatProfile.hurtbox(altura)
	var area := Area3D.new()
	area.name = "Hurtbox"
	var forma_hb := CollisionShape3D.new()
	var cap_hb := CapsuleShape3D.new()
	cap_hb.radius = float(hb["raio"])
	cap_hb.height = maxf(float(hb["altura"]), cap_hb.radius * 2.0 + 0.01)
	forma_hb.shape = cap_hb
	forma_hb.position.y = cap_hb.height * 0.5
	area.add_child(forma_hb)
	add_child(area)

	floor_max_angle = Locomocao3D.ANGULO_MAXIMO_DE_SUBIDA
	floor_snap_length = 0.3

## O visual. **Carregado por CAMINHO, vindo do dado** — é isto que permite um
## modelo pronto daqui a um mês entrar sem tocar em entidade, combate ou IA.
func _montar_visual() -> void:
	var caminho := "%s%d.glb" % [PASTA_DOS_MODELOS, species_id]
	if ResourceLoader.exists(caminho):
		var cena := load(caminho)
		if cena != null:
			# O modelo entra dentro de um nó próprio, e não direto — é esse nó
			# que recebe a correção de eixo quando o export vem torto.
			var suporte := Node3D.new()
			suporte.name = "Modelo"
			add_child(suporte)
			_visual = (cena as PackedScene).instantiate()
			suporte.add_child(_visual)
			tem_modelo = true
			_validar_modelo(suporte)
			return

	# Sem modelo: primitivo, e o aviso vai pro log E pra linha do tempo do
	# feedback. Se o Gabriel reportar "esse bicho está estranho", o recado dele
	# já vai dizer que o modelo não existia.
	tem_modelo = false
	push_warning("sem modelo 3D para #%d (%s) — usando primitivo. Ver docs/POKEMON_MODEL_PIPELINE.md"
		% [species_id, nome_exibido])
	PonteDeFeedback.anotar("sem modelo 3D: %s (#%d)" % [nome_exibido, species_id])

	var c : Dictionary = CombatProfile.corpo(altura)
	_visual = MeshInstance3D.new()
	var malha := CapsuleMesh.new()
	malha.radius = float(c["raio"])
	malha.height = maxf(float(c["altura"]), malha.radius * 2.0 + 0.01)
	(_visual as MeshInstance3D).mesh = malha
	_visual.position.y = malha.height * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _cor_do_tipo()
	(_visual as MeshInstance3D).material_override = mat
	add_child(_visual)

## 🔴 A régua do modelo (14/09). O primeiro modelo entregue — Charizard, pelo
## Codex — estava **certo em tudo e deitado**: o eixo de altura tinha ido pro −Z
## em vez do +Y, clássico Blender Z-up sem conversão no export. Girando 90° em
## X, a altura batia a Pokédex **exatamente** (1,700 m) e os pés caíam em zero.
##
## Vão chegar 151 modelos ao longo de meses. Um torto entrando em silêncio é um
## Pokémon afundado no chão sem ninguém ligar a causa a um export de semanas
## atrás. Então: **mede, corrige o que é inequívoco, e GRITA.**
##
## A correção automática é deliberadamente estreita — só o giro de 90° em X, que
## tem assinatura própria e não se confunde com "modelo mal feito". Corrigir
## mais que isso transformaria o contrato em ficção, e o próximo modelo, esse
## exportado certo, sairia torto.
func _validar_modelo(suporte: Node3D) -> void:
	var r : Dictionary = ValidadorDeModelo.conferir(suporte, species_id)
	if bool(r["ok"]):
		return

	var texto := ValidadorDeModelo.relatorio(suporte, species_id)
	push_warning(texto)
	PonteDeFeedback.anotar("modelo #%d fora do contrato (ver log)" % species_id)

	var correcao : float = float(r["correcao_x"])
	if not is_zero_approx(correcao):
		suporte.rotation_degrees.x = correcao
		push_warning("modelo #%d girado %+.0f° em X como remendo — CONSERTE O EXPORT, não o jogo"
			% [species_id, correcao])

## Cor pelo tipo primário. Placeholder precisa ser **legível**: um campo de
## cápsulas cinzas idênticas não deixa testar nada de combate.
func _cor_do_tipo() -> Color:
	match str(tipos[0]) if not tipos.is_empty() else "Normal":
		"Fire":     return Color(0.90, 0.35, 0.18)
		"Water":    return Color(0.25, 0.50, 0.90)
		"Grass":    return Color(0.35, 0.75, 0.32)
		"Electric": return Color(0.95, 0.82, 0.22)
		"Rock", "Ground": return Color(0.62, 0.52, 0.36)
		"Psychic":  return Color(0.88, 0.35, 0.65)
		"Ice":      return Color(0.60, 0.85, 0.92)
		"Dragon":   return Color(0.45, 0.35, 0.85)
		_:          return Color(0.72, 0.70, 0.66)

# ──────────────────────────────────────────────────────────────────────────────
# Movimento
# ──────────────────────────────────────────────────────────────────────────────

var intencao : Vector2 = Vector2.ZERO
var quer_correr : bool = false

## §6: quando preenchido, este Pokémon acompanha o treinador. Vazio = ele se
## vira sozinho (selvagem, ou controlado pelo jogador em combate).
var acompanha : Node3D = null

## O que ele está fazendo agora, na palavra que `RegraDeAcompanhar` devolve.
## A HUD e a animação leem daqui em vez de deduzir da velocidade — deduzir é
## como dois lugares passam a discordar sobre o mesmo fato.
var estado_de_acompanhar : String = "parado"

## §17: quando o jogador assume este Pokémon, ele ganha câmera de 1ª pessoa e
## passa a obedecer o input. Só um por vez — quem garante é o ControlModeManager.
var camera : CameraPrimeiraPessoa = null
var controlado_pelo_jogador : bool = false
var le_teclado : bool = true

func velocidade_maxima() -> float:
	return MovementProfile.velocidade(arquetipo, int(stats.get("spe", 50)))

func _physics_process(delta: float) -> void:
	if _derrotado:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if controlado_pelo_jogador:
		_obedecer(delta)
		return

	if acompanha != null and is_instance_valid(acompanha):
		_seguir(delta)
		return

	var base := Basis(Vector3.UP, rotation.y)
	var alvo := Locomocao3D.velocidade_alvo(intencao, quer_correr, base)
	if alvo != Vector3.ZERO:
		alvo = alvo.normalized() * velocidade_maxima() * (1.4 if quer_correr else 1.0)
	velocity = Locomocao3D.avancar(velocity, alvo, delta)

	# A gravidade é do arquétipo: voador não cai, aquático afunda devagar (§15).
	var g := MovementProfile.gravidade(arquetipo)
	if g > 0.0:
		velocity.y = Locomocao3D.aplicar_gravidade(velocity.y, is_on_floor(), delta * g)
	else:
		velocity.y = move_toward(velocity.y, 0.0, delta * 4.0)

	move_and_slide()
	rotation.y = Locomocao3D.girar_para(
		rotation.y, velocity, delta, float(MovementProfile.obter(arquetipo)["giro"]))

# ──────────────────────────────────────────────────────────────────────────────
# Controlado pelo jogador (§17, §18)
# ──────────────────────────────────────────────────────────────────────────────

## Monta a câmera de 1ª pessoa com o perfil DESTA espécie (§19). Um Onix e um
## Rattata não podem ver o mundo da mesma altura.
func assumir_controle(yaw_herdado: float) -> void:
	if camera == null:
		camera = CameraPrimeiraPessoa.new()
		camera.name = "CameraPrimeiraPessoa"
		add_child(camera)
	camera.aplicar_perfil(perfil_de_camera())
	camera.definir_yaw(yaw_herdado)
	camera.camera.current = true
	controlado_pelo_jogador = true
	# Para de seguir: ele não pode acompanhar o treinador e obedecer o jogador
	# ao mesmo tempo.
	acompanha = null
	intencao = Vector2.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func devolver_controle(volta_a_acompanhar: Node3D = null) -> void:
	controlado_pelo_jogador = false
	intencao = Vector2.ZERO
	quer_correr = false
	if camera != null and camera.camera != null:
		camera.camera.current = false
	if volta_a_acompanhar != null:
		acompanha = volta_a_acompanhar

func _unhandled_input(evento: InputEvent) -> void:
	if not controlado_pelo_jogador:
		return
	if evento is InputEventMouseMotion and camera != null:
		camera.girar((evento as InputEventMouseMotion).relative)

## §18: WASD move, mouse olha. O movimento segue o olhar, não o norte do mundo.
func _obedecer(delta: float) -> void:
	if le_teclado:
		intencao = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down"))
		quer_correr = Input.is_action_pressed("run")

	var base : Basis = camera.base_do_movimento() if camera != null \
		else Basis(Vector3.UP, rotation.y)
	var alvo := Locomocao3D.velocidade_alvo(intencao, quer_correr, base)
	if alvo != Vector3.ZERO:
		alvo = alvo.normalized() * velocidade_maxima() * (1.4 if quer_correr else 1.0)
	velocity = Locomocao3D.avancar(velocity, alvo, delta)

	var g := MovementProfile.gravidade(arquetipo)
	if g > 0.0:
		velocity.y = Locomocao3D.aplicar_gravidade(velocity.y, is_on_floor(), delta * g)
	else:
		velocity.y = move_toward(velocity.y, 0.0, delta * 4.0)

	move_and_slide()
	# Em 1ª pessoa o CORPO segue a câmera, e não o movimento: quem olha pra
	# esquerda está virado pra esquerda, mesmo andando de lado. É o contrário
	# da 3ª pessoa, e é o que faz a mira bater com o que se vê (§22).
	if camera != null:
		rotation.y = camera.yaw()

## A porta do toque e do teste, igual à do treinador.
func mover(nova_intencao: Vector2, correndo: bool = false) -> void:
	le_teclado = false
	intencao = nova_intencao
	quer_correr = correndo

func soltar_movimento() -> void:
	intencao = Vector2.ZERO
	quer_correr = false
	le_teclado = true

## Ganchos do ControlModeManager (§12).
func ao_assumir_controle() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func ao_perder_controle() -> void:
	intencao = Vector2.ZERO
	quer_correr = false
	le_teclado = true

## §6: acompanhar o treinador. A DECISÃO é da `RegraDeAcompanhar`; aqui só se
## executa — é o que permite provar o comportamento sem subir física.
func _seguir(delta: float) -> void:
	var meu_raio : float = float(CombatProfile.corpo(altura)["raio"])
	var raio_dele : float = 0.35   # o colisor do treinador
	var repouso : float = RegraDeAcompanhar.distancia_de_repouso(raio_dele, meu_raio)

	var olhar := -acompanha.global_transform.basis.z
	var ideal := RegraDeAcompanhar.ponto_ideal(
		acompanha.global_position, olhar, raio_dele, meu_raio)

	var plano_meu := Vector3(global_position.x, 0.0, global_position.z)
	var plano_dele := Vector3(acompanha.global_position.x, 0.0, acompanha.global_position.z)
	var distancia : float = plano_meu.distance_to(plano_dele)
	estado_de_acompanhar = RegraDeAcompanhar.estado(distancia, repouso)

	var alvo := Vector3.ZERO
	match estado_de_acompanhar:
		"parado":
			alvo = Vector3.ZERO
		"recuar":
			# Afasta-se do treinador, não do ponto ideal: perto demais, o que
			# importa é sair de cima dele (§6).
			var fuga := (plano_meu - plano_dele)
			if fuga.length_squared() < 0.001:
				fuga = Vector3.BACK
			alvo = fuga.normalized() * velocidade_maxima() * 0.6
		_:
			var para_o_ideal := Vector3(ideal.x - global_position.x, 0.0,
										ideal.z - global_position.z)
			var rapido : float = 1.5 if estado_de_acompanhar == "correr" else 1.0
			alvo = para_o_ideal.normalized() * velocidade_maxima() * rapido

	velocity = Locomocao3D.avancar(velocity, alvo, delta)

	# §6: "não deve parecer flutuar". A gravidade é do arquétipo, e o voador
	# ganha uma altura de voo sobre o TERRENO — não sobre a trajetória, senão
	# ele mergulha em qualquer descida.
	var g := MovementProfile.gravidade(arquetipo)
	if g > 0.0:
		velocity.y = Locomocao3D.aplicar_gravidade(velocity.y, is_on_floor(), delta * g)
	else:
		var chao : float = RegraDeAcompanhar.altura_no_terreno(
			global_position.x, global_position.z)
		var altura_de_voo : float = chao + 3.0 + altura
		velocity.y = (altura_de_voo - global_position.y) * 2.0

	move_and_slide()
	rotation.y = Locomocao3D.girar_para(
		rotation.y, velocity, delta, float(MovementProfile.obter(arquetipo)["giro"]))

# ──────────────────────────────────────────────────────────────────────────────
# Combate — tudo delega pra V2
# ──────────────────────────────────────────────────────────────────────────────

func esta_derrotado() -> bool:
	return _derrotado

func stats_de_ataque() -> Dictionary:
	return {"level": nivel, "types": tipos,
			"atk": int(stats.get("atk", 50)), "spa": int(stats.get("spa", 50))}

func stats_de_defesa() -> Dictionary:
	return {"level": nivel, "types": tipos,
			"def": int(stats.get("def", 50)), "spd": int(stats.get("spd", 50)),
			"max_hp": vida_maxima, "hp": vida}

func sofrer(dano: int, _de_quem: Node = null) -> void:
	if _derrotado or dano <= 0:
		return
	vida = maxi(0, vida - dano)
	vida_mudou.emit(vida, vida_maxima)
	if vida <= 0:
		_derrotado = true
		derrotado.emit(self)

## O ponto de onde o golpe sai, e o de onde se enxerga. Os dois vêm de perfil,
## não de posição chutada no código da cena.
func origem_do_golpe() -> Vector3:
	return global_position + Vector3.UP * CombatProfile.origem_do_golpe(altura)

func olhos() -> Vector3:
	return global_position + Vector3.UP * CameraProfile.altura_dos_olhos(altura)

func perfil_de_camera() -> Dictionary:
	return CameraProfile.perfil(altura)

func alcance_basico() -> float:
	return CombatProfile.alcance_basico(altura)
