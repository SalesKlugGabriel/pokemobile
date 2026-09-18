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

## 🔴 A PORTA DE ENTRADA. Use isto, não `new()` + `add_child()` + posicionar.
##
## ── O que isto existe pra impedir ───────────────────────────────────────────
##
## Um `CharacterBody3D` passa **um quadro de física** com o colisor na posição
## em que nasceu, antes de o servidor de física acompanhar uma atribuição de
## `global_position` feita depois do `add_child`. Nesse quadro, quem estiver em
## cima daquele ponto **pousa no bicho novo** — e quando o colisor salta pro
## lugar certo, o Godot **carrega** quem está em pé nele, porque é assim que
## plataforma móvel funciona.
##
## Medido em 17/09, determinístico em três execuções:
##
## ```
## posição definida ANTES  do add_child   deslocamento 0,000 m
## posição definida DEPOIS do add_child   deslocamento 1,265 m
## ```
##
## O Charizard terminava **em cima da cabeça** de um Rattata que estava a 1,2 m.
## Passei um bom tempo achando que era bug de colisor porque as cápsulas não se
## sobrepõem (0,476 + 0,180 = 0,656 < 1,2) — e não era: era ordem de nascimento.
##
## A Fase 11 vai criar selvagem a cada encontro. Um spawner que erre a ordem
## catapulta o jogador, e o sintoma (personagem voando) não parece nada com a
## causa (ordem de duas linhas).
static func nascer(pai: Node, id_especie: int, nv: int, posicao: Vector3,
		arquetipo_pedido: String = "",
		categoria_de_encontro: String = RegraDeMovePool.CATEGORIA_PADRAO,
		e_alpha: bool = false) -> PokemonInstance3D:
	var e := PokemonInstance3D.new()
	# A ordem é o ponto: posição ANTES de entrar na árvore.
	e.position = posicao
	pai.add_child(e)
	e.montar(id_especie, nv, arquetipo_pedido, categoria_de_encontro, e_alpha)
	return e

func montar(id_especie: int, nv: int, arquetipo_pedido: String = "",
		categoria_de_encontro: String = RegraDeMovePool.CATEGORIA_PADRAO,
		e_alpha: bool = false) -> void:
	alpha = e_alpha
	# Onde o nó estava quando foi montado — a referência do detector de ordem.
	_pos_ao_nascer = position
	species_id = id_especie
	nivel = maxi(1, nv)

	var esp : Dictionary = GameData.get_species(species_id)
	nome_exibido = str(esp.get("name", "#%d" % species_id))
	tipos = esp.get("types", ["Normal"])

	# As stats vêm da V2, sem adaptação nenhuma.
	stats = StatsDePokemon.conjunto(esp.get("base_stats", {}), nivel)

	# Fase 18 — o Alpha entra AQUI, antes da vida ser derivada do HP: aplicar
	# o multiplicador depois deixaria a barra discordando do stat que a gerou.
	if alpha:
		if not RegraDeAlpha.elegivel(esp):
			push_warning("%s foi marcado como Alpha e a espécie não é elegível (§30)" \
				% nome_exibido)
		stats = RegraDeAlpha.stats(stats)
	vida_maxima = BalanceV2.vida(int(stats.get("hp", 1)))
	vida = vida_maxima

	# A altura real já existia em `heights.json` desde 03/09 — 151 espécies,
	# de 0,2 m (Diglett) a 8,8 m (Onix). Não precisou de dado novo.
	altura_real = PokemonScale.get_height_m(species_id) \
		* (RegraDeAlpha.escala_visual() if alpha else 1.0)
	altura = MovementProfile.altura_jogavel(altura_real)

	arquetipo = arquetipo_pedido if arquetipo_pedido != "" \
		else str(esp.get("arquetipo", MovementProfile.GROUND_BIPED))

	# Alpha manda na categoria: a faixa de golpes dele (5 a 6) já existe no
	# `KitDeCombate` desde a Fase 3 e é o que o faz brigar como miniboss, não
	# só ter números maiores.
	var perfil : Dictionary = RegraDeAlpha.perfil(alpha)
	categoria = str(perfil["categoria"]) if alpha else categoria_de_encontro
	capturavel = bool(perfil["capturavel"])
	_montar_kit()

	_montar_corpo()
	_montar_visual()
	add_to_group("pokemon_v3")
	vida_mudou.emit(vida, vida_maxima)

## Fase 17 — o kit sai do learnset da espécie, não de uma lista escrita à mão.
##
## Antes desta fase, `kit` nascia `[]` **em todo Pokémon do jogo** e ninguém
## preenchia: as quatro teclas não faziam nada, sem erro. Ver o cabeçalho de
## `RegraDeMovePool` pro achado inteiro.
func _montar_kit() -> void:
	if GameData == null:
		return
	var esp : Dictionary = GameData.get_species(species_id)
	var pool : Dictionary = RegraDeMovePool.montar_pool(
		species_id, nivel, GameData.get_learnable_moves(species_id, nivel),
		GameData.moves, tipos, GameData.species, categoria, ensinados)
	conhecidos = pool["conhecidos"]
	kit = pool["ativos"]
	if kit.is_empty():
		push_warning("%s nasceu sem golpe nenhum — learnset vazio?" \
			% str(esp.get("name", "#%d" % species_id)))

## §31: usar uma máquina **ensina e não equipa**. Este é o ponto onde a Fase 16
## e a Fase 17 se encontram — a MT deposita no pool, e o kit ativo só muda
## quando alguém decidir trocar (`TrocaDeKit`, que cobra os 25 níveis quando é
## MO). Devolve `{"golpe": id, "novo": bool}`; `golpe` vazio = a máquina não
## ensina nada.
func aprender_de_maquina(item: Dictionary) -> Dictionary:
	var golpe := str(RegraDeMaquina.efeitos(item).get("golpe", ""))
	if golpe.is_empty():
		return {"golpe": "", "novo": false}
	var r : Dictionary = RegraDeMovePool.aprender(conhecidos, golpe)
	conhecidos = r["conhecidos"]
	if bool(r["novo"]) and not (golpe in ensinados):
		ensinados.append(golpe)
	return {"golpe": golpe, "novo": bool(r["novo"])}

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

## Onde o nó nasceu, e quantos quadros de física ele já viu. Só pro detector
## abaixo — ver `_conferir_ordem_de_nascimento`.
var _pos_ao_nascer : Vector3 = Vector3.ZERO
var _viu_fisica : bool = false

# ──────────────────────────────────────────────────────────────────────────────
# Fase 11 — modo selvagem
# ──────────────────────────────────────────────────────────────────────────────

## Ligado pelo spawner. Um Pokémon de time nunca é selvagem, e um selvagem nunca
## acompanha o treinador — são modos, não graus.
var selvagem : bool = false

## Uma das sete de `ComportamentoSelvagem`. Vem de `species.json: behavior`, que
## já traz as 151 espécies classificadas — nada a inventar aqui.
var personalidade : String = ComportamentoSelvagem.DEFENSIVO

## Onde ele nasceu. É o centro da coleira (§26) e o ponto de volta.
var casa : Vector3 = Vector3.ZERO

## Já apanhou, ou já ouviu o grito do bando. Um defensivo provocado persegue
## mesmo fora do raio curto dele — é o que faz "não mexe comigo" ter consequência.
var provocado : bool = false

## Quem ele considera hostil. O spawner liga no treinador/Pokémon do jogador.
var alvo_hostil : Node3D = null

## O estado da última decisão, em palavra. Existe pra log e pra HUD — e pra o
## teste poder afirmar o COMPORTAMENTO, não só a posição.
var estado_selvagem : String = IASelvagem3D.PARADO

## 🔴 Pega o erro de ordem de nascimento no único quadro em que ele é perigoso.
##
## Reposicionar DEPOIS do `add_child` e ANTES do primeiro quadro de física é a
## janela exata em que o colisor fica pra trás. Um `warp` legítimo dez quadros
## depois não cai aqui, porque aí `_viu_fisica` já é verdadeiro.
##
## Avisa em vez de corrigir: mover o nó por conta própria esconderia o erro do
## chamador, e a próxima vez ele seria cometido em outro lugar. Falta de coisa —
## e erro de uso — tem de ser visível.
func _conferir_ordem_de_nascimento() -> void:
	if _viu_fisica:
		return
	_viu_fisica = true
	if position.distance_to(_pos_ao_nascer) <= 0.01:
		return
	var recado := "%s foi reposicionado DEPOIS de entrar na árvore (%s -> %s). Use PokemonInstance3D.nascer(), senão quem estiver em pé no ponto de nascimento é carregado junto." % [
		nome_exibido, str(_pos_ao_nascer), str(position)]
	push_warning(recado)
	if Engine.has_singleton("PonteDeFeedback") or PonteDeFeedback != null:
		PonteDeFeedback.anotar(recado)

func _physics_process(delta: float) -> void:
	_conferir_ordem_de_nascimento()
	# O aviso de skill corre ANTES da guarda de derrotado, de propósito: quem cai
	# no meio do próprio aviso precisa cancelá-lo, senão o telegrafe fica
	# desenhado no chão pra sempre e o golpe resolve de um morto.
	_tick_cast()

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

	if selvagem:
		# Fase 20 — LOD de lógica. Quem está em jogo pensa todo quadro; quem
		# está ocioso e longe pensa de vez em quando. Ver `RegraDeRitmo`.
		_quadro_de_ritmo += 1
		if not RegraDeRitmo.deve_pensar(_quadro_de_ritmo, _distancia_do_jogador(),
				_protegido_do_ritmo(), int(get_instance_id())):
			_pulados += 1
			return
		var pulados : int = _pulados
		_pulados = 0
		_agir_como_selvagem(RegraDeRitmo.delta_acumulado(delta, pulados), pulados)
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
	_tick_travessia(delta)
	rotation.y = Locomocao3D.girar_para(
		rotation.y, velocity, delta, float(MovementProfile.obter(arquetipo)["giro"]))

# ──────────────────────────────────────────────────────────────────────────────
# Controlado pelo jogador (§17, §18)
# ──────────────────────────────────────────────────────────────────────────────

## Monta a câmera de 1ª pessoa com o perfil DESTA espécie (§19). Um Onix e um
## Rattata não podem ver o mundo da mesma altura.
##
## Fase 16: as permissões de travessia viajam JUNTO com o controle, e não ficam
## penduradas numa chamada separada que dá pra esquecer. Elas são do jogador —
## então entram quando o jogador entra e saem quando ele sai.
func assumir_controle(yaw_herdado: float, permissoes_do_jogador: Array = []) -> void:
	if camera == null:
		camera = CameraPrimeiraPessoa.new()
		camera.name = "CameraPrimeiraPessoa"
		add_child(camera)
	camera.aplicar_perfil(perfil_de_camera())
	camera.definir_yaw(yaw_herdado)
	camera.camera.current = true
	controlado_pelo_jogador = true
	permissoes = permissoes_do_jogador.duplicate()
	# Para de seguir: ele não pode acompanhar o treinador e obedecer o jogador
	# ao mesmo tempo.
	acompanha = null
	intencao = Vector2.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func devolver_controle(volta_a_acompanhar: Node3D = null) -> void:
	controlado_pelo_jogador = false
	# A permissão é do jogador, e ele acabou de sair deste corpo.
	permissoes = []
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
		return
	# §18: LMB é o básico. Eu tinha posto espaço como segunda tecla, e o
	# `teste_pilha_de_telas.gd` reprovou: espaço já é a **pokébola**. Jogar uma
	# bola por engano no lugar de atacar é bem pior que não ter tecla alternativa
	# — e a regra de "nenhuma tecla com dois donos" existe justamente porque é
	# assim que nasce o bug de dois controladores no mesmo botão (§12).
	#
	# A guarda de `controlado_pelo_jogador` acima é o que impede um Pokémon que está só
	# acompanhando o treinador de atacar sozinho ao clique — e o
	# `ControlModeManager` desliga o input de quem não está ativo, então são duas
	# travas independentes pro mesmo erro (§12).
	if evento.is_action_pressed("ataque_basico"):
		atacar()
		return
	# §18: Q E R F são as 4 primeiras skills — e `skill_1..8` no InputMap já
	# mapeiam essas teclas (mais 1-4), depois 5 6 7 8, desde a V2.
	#
	# 🔴 Fase 17: aqui era `for i in 4`, cravado. Um Charizard equipa 8 golpes
	# pela escada do `KitDeCombate` e alcançaria 4 — metade do repertório
	# inalcançável, sem aviso. O laço agora anda o kit que ele de fato tem.
	for i in kit.size():
		var tecla := RegraDeMovePool.tecla_do_slot(i)
		if tecla.is_empty():
			break            # kit maior que o teclado: não há tecla, e tudo bem
		if evento.is_action_pressed(tecla):
			usar_skill(i)
			return

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
	_tick_travessia(delta)
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

## Liga o modo selvagem. Chamado pelo spawner logo depois do `nascer()`.
##
## A personalidade vem do DADO (`species.json: behavior`) — não é parâmetro com
## padrão escondido. Se a espécie não declarar, `ComportamentoSelvagem.normalizar`
## devolve DEFENSIVO, que é o mais inofensivo dos que ainda reagem: um erro de
## digitação no JSON nunca vira um bicho que caça o jogador pelo mapa.
func virar_selvagem(hostil: Node3D = null) -> void:
	selvagem = true
	add_to_group("selvagem_v3")
	acompanha = null
	casa = global_position
	alvo_hostil = hostil
	var esp : Dictionary = GameData.get_species(species_id) if GameData != null else {}
	personalidade = ComportamentoSelvagem.normalizar(str(esp.get("behavior", "")))

## Um quadro de vida de selvagem: decide (regra) e anda (geometria).
##
## A decisão inteira está em `IASelvagem3D.decidir`, que é pura — então o
## comportamento das sete personalidades se prova sem subir mundo, e o que
## sobra aqui é só mover o corpo.
## Fase 20 — o ritmo. Contados por corpo, não globais: dois bichos em distâncias
## diferentes pulam quadros diferentes.
var _quadro_de_ritmo : int = 0
var _pulados : int = 0

## A velocidade de fato entregue ao `move_and_slide` no último passo — já com a
## compensação de quadros pulados.
##
## Existe pra ser **medível**: `move_and_slide()` chamado fora do passo de
## física real (que é o caso de um teste `--script`) não desloca o corpo, então
## deslocamento não serve de prova em headless. Isto serve, e é exatamente o
## número que a compensação decide.
var ultimo_avanco : Vector3 = Vector3.ZERO

## A que distância está o jogador. `alvo_hostil` é quem o spawner apontou como
## hostil no nascimento — é o jogador, e continua sendo mesmo quando o bicho
## ainda não o notou. Sem referência, devolve 0: **na dúvida, pensa todo
## quadro.** Falhar pro lado caro é o único lado seguro aqui; falhar pro lado
## barato seria um bicho congelado sem ninguém entender por quê.
func _distancia_do_jogador() -> float:
	if alvo_hostil == null or not is_instance_valid(alvo_hostil):
		return 0.0
	var d := alvo_hostil.global_position - global_position
	return Vector2(d.x, d.z).length()

## Quem nunca desacelera, por mais longe que esteja.
##
## O critério é **envolve o jogador**, não "está se mexendo". A diferença
## importa, e eu errei nela primeiro: protegendo todo estado ≠ PARADO, a
## economia só alcançaria quem já estava parado — e `VOLTAR`, que é um bicho
## andando pra casa longe da vista, ficaria protegido à toa.
##
## Protegidos: perseguir, atacar, fugir (os três são o jogador), mais provocado
## e quem está no meio de um aviso de golpe. `VOLTAR` e `PARADO` não entram:
## são serviço interno, e é neles que a economia vive.
func _protegido_do_ritmo() -> bool:
	if provocado or esta_anunciando():
		return true
	return estado_selvagem == IASelvagem3D.PERSEGUIR \
		or estado_selvagem == IASelvagem3D.ATACAR \
		or estado_selvagem == IASelvagem3D.FUGIR

func _agir_como_selvagem(delta: float, quadros_pulados: int = 0) -> void:
	# 🔴 REMOVIDO em 18/09, e vale registrar por quê.
	#
	# Aqui existia uma trava que fazia o terceiro selvagem LARGAR o alvo quando
	# ele já estava numa briga — pra sustentar um "1v1 sem arena".
	#
	# **O Gabriel corrigiu a premissa:** *"estamos fazendo um game de mundo
	# aberto, a batalha entre diversos mobs é possível, o aggro de vários mobs
	# também (...) é possível acontecer um 1v5 ou 1v10 dependendo da área do mapa
	# que o player está"*. O 1v1 é a mecânica de **duelo** (PvP), não a regra do
	# mundo.
	#
	# A trava não era só desnecessária: era um bug. Com ela, lutar contra um
	# Rattata fazia **todos os outros que já vinham atrás do jogador esquecerem
	# dele** — o oposto de "entrar despreparado numa região pode terminar muito
	# mal", que é o terceiro pilar do projeto.
	#
	# Quem controla exclusividade agora é quem QUER exclusividade: o
	# `Combate1v1`, via `RegraDeCombate.pode_engajar`, e só quando um duelo
	# estiver acontecendo de propósito.

	var alvo_valido : bool = alvo_hostil != null and is_instance_valid(alvo_hostil)
	var pos_do_alvo : Vector3 = alvo_hostil.global_position if alvo_valido else global_position
	var dist_ao_alvo : float = INF
	if alvo_valido:
		dist_ao_alvo = Vector3(pos_do_alvo.x - global_position.x, 0.0,
								pos_do_alvo.z - global_position.z).length()
	var dist_de_casa : float = Vector3(casa.x - global_position.x, 0.0,
										casa.z - global_position.z).length()
	var fracao : float = float(vida) / float(maxi(1, vida_maxima))

	estado_selvagem = IASelvagem3D.decidir(
		personalidade, dist_ao_alvo, dist_de_casa, fracao, provocado, alcance_basico())

	# Atacar é decisão da IA, mas o cooldown é do ataque — `atacar()` recusa
	# sozinho quando está esfriando, e por isso não há segunda trava aqui.
	if estado_selvagem == IASelvagem3D.ATACAR:
		atacar()

	var dir := IASelvagem3D.direcao(estado_selvagem, global_position, pos_do_alvo, casa)
	# Fugir é mais rápido que perseguir. Não é balanceamento solto: é o que faz a
	# fuga do FUGITIVO ter chance de funcionar, e o §26 pede que ela funcione.
	var pressa : float = 1.25 if estado_selvagem == IASelvagem3D.FUGIR else 1.0
	var alvo_v := dir * velocidade_maxima() * pressa
	velocity = Locomocao3D.avancar(velocity, alvo_v, delta)

	var g := MovementProfile.gravidade(arquetipo)
	if g > 0.0:
		velocity.y = Locomocao3D.aplicar_gravidade(velocity.y, is_on_floor(), delta * g)
	else:
		velocity.y = move_toward(velocity.y, 0.0, delta * 4.0)

	# Fase 20 — quem pulou quadros precisa andar o que deixou de andar.
	# `move_and_slide` usa o passo de física do MOTOR, não o nosso delta, então
	# a compensação vai na velocidade e é desfeita logo depois: deixá-la
	# multiplicada faria o próximo quadro herdar uma velocidade inflada, e o
	# bicho sairia disparado ao se aproximar do jogador.
	var fator : float = RegraDeRitmo.fator_de_avanco(quadros_pulados)
	if fator > 1.0:
		var guardada := velocity
		velocity *= fator
		ultimo_avanco = velocity
		move_and_slide()
		velocity = guardada
	else:
		ultimo_avanco = velocity
		move_and_slide()
	_tick_travessia(delta)
	rotation.y = Locomocao3D.girar_para(rotation.y, velocity, delta)

# ──────────────────────────────────────────────────────────────────────────────
# Fases 14 e 15 — travessia: água e ar
# ──────────────────────────────────────────────────────────────────────────────

## Fôlego, quando submerso. Cheio fora d'água.
var oxigenio : float = Mergulho.OXIGENIO_MAXIMO

## Está com a cabeça debaixo d'água? Quem decide é o jogador (afundar), mas o
## consumo e o afogamento são consequência.
var mergulhando : bool = false

## A zona em que ele está — é dela que sai a regra de voo (§29). Vazia = voo
## livre, que é o padrão mais permissivo e o menos surpreendente.
var zona : Dictionary = {}

signal oxigenio_mudou(atual: float, maximo: float)
signal afogou()

## A superfície embaixo dele, agora. Vem do terreno, que é a fonte única da
## geografia — não de uma segunda tabela pra alguém manter em sincronia.
func superficie_atual() -> String:
	return Terreno3D.superficie_em(global_position.x, global_position.z)

func profundidade_atual() -> String:
	return RegraDeTravessia.profundidade_em(
		Terreno3D.altura_em(global_position.x, global_position.z))

func pode_mergulhar_aqui() -> bool:
	return RegraDeTravessia.pode_mergulhar(
		arquetipo, Terreno3D.altura_em(global_position.x, global_position.z))

## Um quadro de travessia: água que barra quem não nada, oxigênio de quem está
## submerso, e teto pra quem voa.
##
## ⚠️ **Roda DEPOIS do `move_and_slide`**, de propósito: é uma correção do que
## aconteceu, não uma previsão. Prever daria dois lugares decidindo pra onde o
## corpo vai — e dois lugares decidindo é como eles passam a discordar.
func _tick_travessia(delta: float) -> void:
	var sup := superficie_atual()

	# Fase 14: água profunda barra quem não nada. Empurra de volta em vez de
	# travar, porque parede invisível na beira d'água é pior que ser devolvido.
	#
	# 🔴 `_tem_lugar_seco` não é zelo: sem ele, quem **nasce** na água era
	# devolvido pro valor inicial de `_ultima_posicao_seca`, que era
	# `Vector3.ZERO` — ou seja, **teleportado pra origem do mundo**. O
	# `teste_nascimento_v3.gd` pegou na primeira rodada da suíte: um corpo criado
	# a 300 m apareceu em (0, 13.5, 0).
	#
	# É a mesma família do zero silencioso: um valor padrão que parece inofensivo
	# e vira comportamento. Agora o recuo só acontece se houver pra onde recuar.
	# Fase 16: e, se for o JOGADOR, também a permissão da MO (§30). Capacidade e
	# permissão são perguntas diferentes — quem nada, nada; quem atravessa o mar
	# precisa da MO. O selvagem nunca é consultado: exigir carteira de um bicho
	# transformaria o mundo num cartório.
	if not _pode_estar_aqui(sup):
		if _tem_lugar_seco:
			var recuo := Vector3(global_position.x - _ultima_posicao_seca.x, 0.0,
								global_position.z - _ultima_posicao_seca.z)
			if recuo.length() > 0.01:
				global_position.x = _ultima_posicao_seca.x
				global_position.z = _ultima_posicao_seca.z
				velocity.x = 0.0
				velocity.z = 0.0
	elif not RegraDeTravessia.e_agua(sup):
		_ultima_posicao_seca = global_position
		_tem_lugar_seco = true

	# Oxigênio. Só conta submerso — boiar não cansa.
	var antes := oxigenio
	if mergulhando:
		var prof := profundidade_atual()
		if prof == "":
			mergulhando = false
		else:
			oxigenio = Mergulho.consumir(oxigenio, delta, prof, _tem_roupa_de_mergulho)
			if Mergulho.afogou(oxigenio):
				mergulhando = false
				sofrer(int(round(float(vida_maxima) * Mergulho.DANO_AO_AFOGAR)), null)
				afogou.emit()
	else:
		oxigenio = Mergulho.recuperar(oxigenio, delta)
	if not is_equal_approx(antes, oxigenio):
		oxigenio_mudou.emit(oxigenio, Mergulho.OXIGENIO_MAXIMO)

	# Fase 15: teto de voo, relativo ao terreno logo abaixo.
	if MovementProfile.voa(arquetipo):
		var chao := Terreno3D.altura_em(global_position.x, global_position.z)
		var teto := RegraDeTravessia.altitude_maxima(chao, zona)
		if global_position.y > teto:
			global_position.y = teto
			velocity.y = minf(velocity.y, 0.0)

## As travessias que o JOGADOR liberou (Fase 16) — vem da mochila, via
## `RegraDeMaquina.permissoes_de`. Vazio é o padrão e é restritivo de propósito:
## permissão concedida por omissão não é permissão.
##
## Mora no corpo porque é o corpo que se move, mas pertence ao jogador: um
## selvagem carrega a lista vazia e **nunca é perguntado** por ela.
##
## ⚠️ `Array` e não `Array[String]`: array tipado recusa `= []` vindo de fora com
## *"Invalid set index"* em tempo de execução, e essa recusa não reprova teste —
## ela aborta a função e o arquivo ainda sai com sucesso. Foi o que aconteceu ao
## escrever esta fase. Tipo forte num campo que o mundo inteiro atribui troca um
## erro impossível por um erro silencioso.
var permissoes : Array = []

## A pergunta completa da travessia. Selvagem responde só pela capacidade; o
## jogador responde pelas duas.
func _pode_estar_aqui(superficie: String) -> bool:
	if not controlado_pelo_jogador:
		return RegraDeTravessia.pode_estar_em(arquetipo, superficie)
	return bool(RegraDeMaquina.pode_atravessar(arquetipo, superficie, permissoes)["pode"])

## Por que não dá pra ir pra lá — em português, pra tela mostrar.
func por_que_nao_atravessa(superficie: String) -> String:
	return str(RegraDeMaquina.pode_atravessar(arquetipo, superficie, permissoes)["motivo"])

## O último lugar onde ele estava fora da água profunda — o ponto de devolução.
## Só vale depois de ele ter estado em algum lugar seco de verdade.
var _ultima_posicao_seca : Vector3 = Vector3.ZERO
var _tem_lugar_seco : bool = false
var _tem_roupa_de_mergulho : bool = false

## Afunda ou emerge. Devolve `{"pode", "motivo"}` — motivo em português.
func alternar_mergulho() -> Dictionary:
	if mergulhando:
		mergulhando = false
		return {"pode": true, "motivo": ""}
	if not pode_mergulhar_aqui():
		if not RegraDeTravessia.e_agua(superficie_atual()):
			return {"pode": false, "motivo": "Você não está na água."}
		if not MovementProfile.nada(arquetipo):
			return {"pode": false, "motivo": "Este Pokémon não nada."}
		return {"pode": false, "motivo": "A água aqui é rasa demais pra mergulhar."}
	mergulhando = true
	return {"pode": true, "motivo": ""}

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
	_tick_travessia(delta)
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

func sofrer(dano: int, de_quem: Node = null) -> void:
	if _derrotado or dano <= 0:
		return
	vida = maxi(0, vida - dano)

	# §25/§27: apanhar provoca, e quem chama o bando grita UMA vez. A trava de
	# saltos é na origem — quem foi chamado não grita de novo, senão A chama B,
	# B chama C, e em segundos o mapa inteiro está em cima do jogador.
	if selvagem and not provocado:
		provocado = true
		if de_quem is Node3D:
			alvo_hostil = de_quem
		if IASelvagem3D.chama_o_bando(personalidade):
			_gritar_pro_bando()
	vida_mudou.emit(vida, vida_maxima)
	if vida <= 0:
		_derrotado = true
		derrotado.emit(self)

## Chama os vizinhos da mesma espécie. Quem responde fica provocado, mas **não
## grita** — é a quarta trava da §27, e é ela que impede a reação em cadeia.
func _gritar_pro_bando() -> void:
	var candidatos : Array = []
	for no in get_tree().get_nodes_in_group("selvagem_v3"):
		if no == self or not is_instance_valid(no):
			continue
		if not (no is PokemonInstance3D) or no.esta_derrotado():
			continue
		candidatos.append({"quem": no, "posicao": no.global_position, "especie": no.species_id})

	for quem in IASelvagem3D.quem_ouve_o_grito(global_position, species_id, candidatos):
		quem.provocado = true
		if alvo_hostil != null:
			quem.alvo_hostil = alvo_hostil

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

# ──────────────────────────────────────────────────────────────────────────────
# Fase 9 — o ataque básico
# ──────────────────────────────────────────────────────────────────────────────

## Quando o último básico saiu, no relógio do próprio nó. Negativo = nunca.
var _ultimo_basico : float = -1.0

## O básico já esfriou? A HUD pergunta isto; a regra vive em `AtaqueBasico`.
func basico_pronto() -> bool:
	return AtaqueBasico.pronto(_agora(), _ultimo_basico)

func basico_esfriando() -> float:
	return AtaqueBasico.esfriando(_agora(), _ultimo_basico)

func _agora() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

## Bate. Devolve o relatório do acerto, ou `{}` quando não houve golpe — porque
## estava esfriando, porque nada estava no arco, ou porque já foi derrotado.
##
## ── Por que devolve o relatório em vez de só emitir o sinal ─────────────────
##
## O sinal (`EventBus.golpe_resolvido`) é pra a tela. O retorno é pra quem
## chamou: o teste, e mais tarde a IA (Fase 11), que precisa saber se o golpe
## dela conectou pra decidir o próximo passo. Sinal não serve de resposta.
##
## ── Sem RNG (§22) ──────────────────────────────────────────────────────────
##
## Não há rolagem de precisão. Quem está no alcance E no arco é acertado; quem
## não está, não é. `AtaqueBasico.acertou` é a regra inteira, e ela é testável
## sem física porque é geometria pura.
func atacar() -> Dictionary:
	if _derrotado:
		return {}
	if not basico_pronto():
		return {}

	var alvo := _alvo_na_frente()
	# O cooldown conta a TENTATIVA, não o acerto. Se contasse só o acerto, errar
	# não custaria nada e o jogador spammaria o botão sem risco — o oposto do que
	# um combate de ação pede.
	_ultimo_basico = _agora()
	if alvo == null:
		return {}

	var golpe := AtaqueBasico.golpe()
	var detalhe : Dictionary = DanoV2.detalhar(golpe, stats_de_ataque(), alvo.stats_de_defesa())

	# 🔴 A chave é `final`, não `dano`. Eu escrevi `detalhe.get("dano", 0)` na
	# primeira versão e o ataque saiu com relatório completo, sinal emitido,
	# efetividade classificada — e **dano zero**, porque `Dictionary.get` com
	# padrão devolve o padrão sem reclamar de chave errada.
	#
	# O teste da Fase 9 pegou na primeira rodada, e só porque ele exige que a
	# VIDA MUDE em vez de conferir se "não deu erro".
	#
	# Por isso aqui NÃO tem valor padrão: chave errada passa a estourar na hora
	# em vez de virar zero silencioso. `DanoV2` sempre devolve `final` — quando
	# não devolver, quero saber.
	assert(detalhe.has("final"), "DanoV2.detalhar mudou de contrato: sem a chave 'final'")
	var dano : int = int(detalhe["final"])
	alvo.sofrer(dano, self)

	var relatorio := RelatorioDeGolpe.montar_3d(
		golpe, self, alvo, dano, detalhe, alvo.vida, alvo.vida_maxima)
	EventBus.golpe_resolvido.emit(relatorio)
	return relatorio

# ──────────────────────────────────────────────────────────────────────────────
# Fase 10 — as 4 skills
# ──────────────────────────────────────────────────────────────────────────────

## Os golpes nos slots, por id de `moves.json` — a camada **ativa**, a que tem
## tecla. Quem monta é `RegraDeMovePool` (Fase 17), a partir do learnset.
var kit : Array = []

## Tudo que ele sabe, sem teto — a camada **conhecida**. É daqui que a tela de
## troca de kit escolhe, e é aqui que uma MT deposita o que ensinou.
var conhecidos : Array = []

## Golpes vindos de MT/MO. Entram no pool e **não equipam sozinhos** (§31).
var ensinados : Array = []

## Que tipo de encontro este bicho é: muda quantos slots ele carrega.
## `jogador` usa a escada de capacidade; o resto usa a régua de selvagem.
var categoria : String = RegraDeMovePool.CATEGORIA_PADRAO

## Fase 18 — este é um Alpha. Quem decide é `RegraDeAlpha`, no NASCIMENTO:
## virar Alpha depois de nascido mudaria stats e tamanho no meio da luta.
var alpha : bool = false

## §30: Alpha não se captura. Fica exposto aqui pra quem construir a pokébola
## na V3 ler o estado em vez de reimplementar a regra.
var capturavel : bool = true

## Este encontro é **elite** (mais raro, nível acima do topo da faixa da zona).
## Independente de `alpha`: os dois são sorteios separados e podem coincidir.
## Fica no corpo porque a chance de Alpha cresce por **elite derrotado**, e
## depois da briga não haveria como saber se o que caiu era elite.
var elite : bool = false

## Último uso POR GOLPE, não por slot: trocar a ordem das skills não pode zerar
## cooldown. Ver `UsoDeSkill`.
var _cooldowns : Dictionary = {}

## O aviso no ar, quando há. `{}` = nada anunciado.
var _cast : Dictionary = {}

func golpe_do_slot(indice: int) -> Dictionary:
	if indice < 0 or indice >= kit.size():
		return {}
	var id := str(kit[indice])
	var dados = GameData.moves.get(id, null) if GameData != null else null
	return dados if dados is Dictionary else {}

func esta_anunciando() -> bool:
	return not _cast.is_empty()

## Quanto falta esfriar o slot. A HUD pergunta; ela não recalcula.
func skill_esfriando(indice: int) -> float:
	var g := golpe_do_slot(indice)
	if g.is_empty():
		return 0.0
	return UsoDeSkill.esfriando(_agora(), float(_cooldowns.get(str(g.get("id", "?")), -1.0)), g)

## Usa a skill do slot. Devolve:
##
##   `{"recusado": motivo}`  não pôde sair, e por quê
##   `{"anuncio": {...}}`    tem aviso: anunciou agora, resolve depois
##   `{"alvos": [...]}`      instantâneo: já resolveu
##
## Três formas de retorno porque são três coisas diferentes, e achatar as três
## num booleano é como a tela perde a informação de que precisa pra explicar o
## que aconteceu.
func usar_skill(indice: int) -> Dictionary:
	var golpe := golpe_do_slot(indice)
	var agora := _agora()
	var ultimo : float = float(_cooldowns.get(str(golpe.get("id", "?")), -1.0))
	var motivo := UsoDeSkill.por_que_nao(agora, ultimo, golpe, _derrotado, esta_anunciando())
	if motivo != "":
		return {"recusado": motivo}

	var direcao : Vector3 = camera.direcao_de_mira() if camera != null else -global_transform.basis.z
	# O cooldown conta o COMEÇO, não o fim. Um golpe de aviso longo não pode
	# ficar imune a cooldown durante o aviso.
	_cooldowns[str(golpe.get("id", "?"))] = agora

	if not UsoDeSkill.tem_aviso(golpe):
		return {"alvos": _resolver_skill(golpe, direcao)}

	# Direção TRAVADA aqui — ver o porquê em UsoDeSkill.
	_cast = UsoDeSkill.anuncio(golpe, origem_do_golpe(), direcao, agora)
	_cast["_golpe_completo"] = golpe
	EventBus.skill_anunciada.emit(_cast.duplicate(true))
	return {"anuncio": _cast.duplicate(true)}

## Chamado a cada quadro. Resolve o aviso quando a hora chega, e cancela quando
## o dono cai no meio.
func _tick_cast() -> void:
	if _cast.is_empty():
		return
	if _derrotado:
		var id := str(_cast.get("golpe", "?"))
		_cast = {}
		EventBus.skill_cancelada.emit(id)
		return
	if _agora() < float(_cast.get("resolve_em", 0.0)):
		return
	var golpe : Dictionary = _cast.get("_golpe_completo", {})
	var direcao : Vector3 = _cast.get("direcao", -global_transform.basis.z)
	_cast = {}
	_resolver_skill(golpe, direcao)

## Aplica o golpe em quem a forma pegar. Devolve os relatórios, um por alvo.
func _resolver_skill(golpe: Dictionary, direcao: Vector3) -> Array:
	var candidatos := _candidatos_ao_redor(
		maxf(FormaDeArea3D.alcance_em_metros(golpe), FormaDeArea3D.raio_em_metros(golpe)))
	var alvos : Array = FormaDeArea3D.alvos(golpe, origem_do_golpe(), direcao, candidatos)

	var relatorios : Array = []
	var dano_total : int = 0
	for alvo in alvos:
		var detalhe : Dictionary = DanoV2.detalhar(golpe, stats_de_ataque(), alvo.stats_de_defesa())
		assert(detalhe.has("final"), "DanoV2.detalhar mudou de contrato: sem a chave 'final'")
		var dano : int = int(detalhe["final"])
		alvo.sofrer(dano, self)
		dano_total += dano
		var r := RelatorioDeGolpe.montar_3d(
			golpe, self, alvo, dano, detalhe, alvo.vida, alvo.vida_maxima)
		EventBus.golpe_resolvido.emit(r)
		relatorios.append(r)

	_drenar(golpe, dano_total)
	return relatorios

## §20: drenagem cura pelo dano REAL causado, nunca pelo teórico.
##
## A fração vem de `CombatenteV2.fracao_de_drenagem`, a MESMA função da V2 — ela
## é estática e pura, e reescrevê-la aqui seria criar a segunda implementação
## que um dia discorda da primeira. Vale lembrar por que ela existe: a drenagem
## nunca funcionou nem na V1, porque o código lia um campo `drenagem` que nenhum
## dos 192 golpes tem. A codificação real é `effect: "drain_50"`.
func _drenar(golpe: Dictionary, dano_causado: int) -> void:
	if dano_causado <= 0 or _derrotado:
		return
	var fracao : float = CombatenteV2.fracao_de_drenagem(golpe)
	if fracao <= 0.0 or vida >= vida_maxima:
		return
	var cura : int = mini(dano_causado, int(round(float(dano_causado) * fracao)))
	if cura <= 0:
		return
	vida = mini(vida_maxima, vida + cura)
	vida_mudou.emit(vida, vida_maxima)

## Todo Pokémon acertável dentro de `raio`, com posição e raio de corpo — a
## matéria-prima que `FormaDeArea3D` filtra. A física entra só aqui.
func _candidatos_ao_redor(raio: float) -> Array:
	var espaco := get_world_3d().direct_space_state
	if espaco == null:
		return []
	var consulta := PhysicsShapeQueryParameters3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = maxf(0.5, raio)
	consulta.shape = esfera
	consulta.transform = Transform3D(Basis.IDENTITY, origem_do_golpe())
	consulta.collide_with_areas = true
	consulta.collide_with_bodies = false
	consulta.exclude = [get_rid()]
	consulta.collision_mask = 0xFFFFFFFF

	var saida : Array = []
	var vistos : Array = []
	for achado in espaco.intersect_shape(consulta, 32):
		var area = achado.get("collider")
		if area == null:
			continue
		var quem = area.get_parent()
		if quem == self or quem == null or quem in vistos:
			continue
		if not quem.has_method("stats_de_defesa"):
			continue
		if quem.has_method("esta_derrotado") and quem.esta_derrotado():
			continue
		vistos.append(quem)
		var raio_do_corpo : float = 0.0
		if "altura" in quem:
			raio_do_corpo = float(CombatProfile.corpo(float(quem.altura))["raio"])
		saida.append({"quem": quem, "posicao": quem.global_position, "raio": raio_do_corpo})
	return saida

## Quem está no arco à frente, mais perto primeiro.
##
## Procura HURTBOX (Area3D), não corpo: a §22 mantém as duas separadas, e é a
## hurtbox — um pouco maior que o corpo — que define o que é acertável. Consultar
## o corpo faria o golpe passar raspando e não conectar, que é a reclamação
## clássica de combate 3D.
func _alvo_na_frente() -> Node:
	var espaco := get_world_3d().direct_space_state
	if espaco == null:
		return null

	var alcance := alcance_basico()
	var consulta := PhysicsShapeQueryParameters3D.new()
	var esfera := SphereShape3D.new()
	# A esfera cobre o alcance a partir do PEITO, não dos pés: um golpe que sai
	# da altura do corpo não deveria acertar algo atrás de um degrau.
	esfera.radius = alcance
	consulta.shape = esfera
	consulta.transform = Transform3D(Basis.IDENTITY, origem_do_golpe())
	consulta.collide_with_areas = true
	consulta.collide_with_bodies = false
	consulta.exclude = [get_rid()]
	consulta.collision_mask = 0xFFFFFFFF

	var olhar : Vector3 = camera.direcao_de_mira() if camera != null else -global_transform.basis.z

	var melhor : Node = null
	var menor : float = INF
	for achado in espaco.intersect_shape(consulta, 16):
		var area = achado.get("collider")
		if area == null:
			continue
		var quem = area.get_parent()
		# Só Pokémon, e nunca a si mesmo. `has_method` em vez de comparar classe:
		# o alvo pode ser um dublê de teste, e exigir a classe exata tornaria o
		# combate impossível de testar sem subir o mundo inteiro.
		if quem == self or quem == null or not quem.has_method("stats_de_defesa"):
			continue
		if quem.has_method("esta_derrotado") and quem.esta_derrotado():
			continue

		var raio : float = 0.0
		if "altura" in quem:
			raio = float(CombatProfile.corpo(float(quem.altura))["raio"])
		if not AtaqueBasico.acertou(olhar, origem_do_golpe(), quem.global_position, alcance, raio):
			continue

		var d : float = origem_do_golpe().distance_to(quem.global_position)
		if d < menor:
			menor = d
			melhor = quem
	return melhor
