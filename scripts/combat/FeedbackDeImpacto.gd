## FeedbackDeImpacto.gd — A pancada tem que SER SENTIDA (05/09).
##
## Primeiro item do MVP das Dungeons Elementais. O combate em tempo real já
## funcionava e já calculava o dano certo, mas na tela não acontecia nada: dois
## bonecos encostados um no outro e uma barrinha diminuindo. Sem retorno visual,
## o jogador não sabe se acertou, se errou, se levou — e um chefe de dungeon
## fica impossível de ler.
##
## Cinco camadas, todas código, nenhuma arte nova:
##
## 1. RECUO — quem leva é empurrado pra trás e volta. É o que diz "veio dali".
## 2. PISCAR BRANCO — 0,1s. É o que diz "acertou AGORA", separando dois golpes
##    seguidos que sem isso viram um borrão só.
## 3. NÚMERO DE DANO — quanto. Reaproveita o FloatingText que já existia.
## 4. TREMOR DE CÂMERA — só quando é o SEU lado que apanha, e proporcional ao
##    tamanho da mordida. Se todo Rattata sacudisse a tela, o tremor pararia de
##    significar perigo.
## 5. HITSTOP (60 ms) — a pausa que faz o golpe pesar. Também só nos golpes
##    grandes: aplicado em tudo, o jogo inteiro engasga.
##
## Por que é um ouvinte de `EventBus.damage_dealt` e não uma chamada dentro do
## combate: dano é calculado em 3 lugares diferentes (selvagem, follower,
## treinador) e os três já emitiam esse sinal — que até hoje ninguém escutava.
## Assim a camada visual não encosta na lógica de dano, e um lugar novo que
## cause dano amanhã já nasce com impacto de graça.
extends Node

const RECUO_PX        : float = 16.0   ## mundo; com zoom 0,5 dá 8 px de tela
const FLASH_SEG       : float = 0.10
const TREMOR_MAX_PX   : float = 10.0
const HITSTOP_SEG     : float = 0.06
const HITSTOP_ESCALA  : float = 0.05   ## quase parado, mas não zero
const FRACAO_GOLPE_FORTE : float = 0.18  ## 18% da vida máxima já é "golpe grande"

## Shader de piscar: multiplica a cor do pixel em direção ao branco sem mexer
## na transparência (`modulate` sozinho não clareia — só escurece ou tinge).
const CODIGO_FLASH : String = """
shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 cor = texture(TEXTURE, UV);
	cor.rgb = mix(cor.rgb, vec3(1.0), flash * cor.a);
	COLOR = cor * COLOR;
}
"""

var _shader : Shader = null
var _hitstop_ate : int = 0   ## msec; evita hitstops empilhados virando câmera lenta

func _ready() -> void:
	# Precisa rodar durante o hitstop, que mexe em Engine.time_scale.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shader = Shader.new()
	_shader.code = CODIGO_FLASH
	EventBus.damage_dealt.connect(_ao_receber_dano)

func _ao_receber_dano(alvo: Node, dano: int, critico: bool, atacante: Node) -> void:
	if alvo == null or not is_instance_valid(alvo) or dano <= 0:
		return
	if not (alvo is Node2D):
		return

	var fracao := _fracao_da_vida(alvo, dano)
	var do_jogador := _e_do_time_do_jogador(alvo)

	_recuar(alvo as Node2D, atacante)
	_piscar(alvo)
	_numero_de_dano(alvo as Node2D, dano, critico, do_jogador)

	# Tremor e hitstop são os dois caros em atenção — só saem quando o golpe
	# realmente importa, senão perdem o significado.
	if do_jogador or critico or fracao >= FRACAO_GOLPE_FORTE:
		tremer_camera(clampf(fracao / FRACAO_GOLPE_FORTE, 0.35, 1.0))
	if critico or fracao >= FRACAO_GOLPE_FORTE:
		_hitstop()

# ──────────────────────────────────────────────────────────────────────────
# As cinco camadas
# ──────────────────────────────────────────────────────────────────────────
func _recuar(alvo: Node2D, atacante: Node) -> void:
	var sprite := alvo.get_node_or_null("Sprite") as Node2D
	if sprite == null:
		return
	var direcao := Vector2.UP
	if atacante != null and is_instance_valid(atacante) and atacante is Node2D:
		var d : Vector2 = alvo.global_position - (atacante as Node2D).global_position
		if d.length_squared() > 1.0:
			direcao = d.normalized()
	var repouso : Vector2 = sprite.position
	# Se um golpe chega no meio do recuo do anterior, a posição de repouso
	# tem que ser a ORIGINAL, senão o sprite vai andando pra longe do dono.
	if sprite.has_meta("repouso"):
		repouso = sprite.get_meta("repouso")
	else:
		sprite.set_meta("repouso", repouso)
	var t := alvo.create_tween()
	t.tween_property(sprite, "position", repouso + direcao * RECUO_PX, 0.06)
	t.tween_property(sprite, "position", repouso, 0.12).set_trans(Tween.TRANS_BACK)

func _piscar(alvo: Node) -> void:
	var sprite := alvo.get_node_or_null("Sprite") as CanvasItem
	if sprite == null:
		return
	var mat := sprite.material as ShaderMaterial
	if mat == null or mat.shader != _shader:
		mat = ShaderMaterial.new()
		mat.shader = _shader
		sprite.material = mat
	mat.set_shader_parameter("flash", 1.0)
	var t := alvo.create_tween()
	t.tween_method(
		func(v: float): mat.set_shader_parameter("flash", v),
		1.0, 0.0, FLASH_SEG
	)

func _numero_de_dano(alvo: Node2D, dano: int, critico: bool, do_jogador: bool) -> void:
	var cena := alvo.get_tree().current_scene
	if cena == null:
		return
	# Vermelho = você apanhou. Branco = você acertou. Laranja = crítico.
	# Cor é a leitura mais rápida que existe: dá pra saber de quem é o número
	# sem ler o número.
	var cor := Color(1, 1, 1)
	if do_jogador:
		cor = Color(1, 0.35, 0.3)
	if critico:
		cor = Color(1, 0.72, 0.15)
	var texto := str(dano)
	if critico:
		texto = str(dano) + "!"
	# Espalha um pouco na horizontal pra dois números do mesmo instante não
	# nascerem exatamente por cima um do outro e virarem um borrão.
	var origem : Vector2 = alvo.global_position + Vector2(randf_range(-24.0, 24.0), -96.0)
	FloatingText.show_text(cena, origem, texto, cor)

## Pública: o telegraph de área e o chefe também vão querer sacudir a tela.
func tremer_camera(intensidade: float = 1.0) -> void:
	var cam := _camera_ativa()
	if cam == null:
		return
	var forca : float = TREMOR_MAX_PX * clampf(intensidade, 0.0, 1.0)
	var t := cam.create_tween()
	for i in 4:
		t.tween_property(
			cam, "offset",
			Vector2(randf_range(-forca, forca), randf_range(-forca, forca)),
			0.035
		)
	t.tween_property(cam, "offset", Vector2.ZERO, 0.05)

func _hitstop() -> void:
	var agora := Time.get_ticks_msec()
	if agora < _hitstop_ate:
		return
	_hitstop_ate = agora + int(HITSTOP_SEG * 1000.0) + 40
	Engine.time_scale = HITSTOP_ESCALA
	# Espera em tempo REAL: um timer normal também ficaria lento junto do
	# jogo, e o hitstop de 60 ms viraria 1,2 segundo.
	await get_tree().create_timer(HITSTOP_SEG, true, false, true).timeout
	Engine.time_scale = 1.0

# ──────────────────────────────────────────────────────────────────────────
# Ajuda
# ──────────────────────────────────────────────────────────────────────────
func _fracao_da_vida(alvo: Node, dano: int) -> float:
	if "max_hp" in alvo:
		var maximo : int = int(alvo.max_hp)
		if maximo > 0:
			return float(dano) / float(maximo)
	return 0.0

func _e_do_time_do_jogador(alvo: Node) -> bool:
	return alvo.is_in_group("player") or alvo.is_in_group("follower_pokemon")

func _camera_ativa() -> Camera2D:
	var arvore := get_tree()
	if arvore == null:
		return null
	var jogadores := arvore.get_nodes_in_group("player")
	if jogadores.is_empty():
		return null
	return jogadores[0].get_node_or_null("Camera2D") as Camera2D
