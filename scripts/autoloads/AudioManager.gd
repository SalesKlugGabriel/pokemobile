## AudioManager.gd — Gerenciador centralizado de áudio: BGM com crossfade e SFX polyfônico.
## Uso: AudioManager.play_bgm("overworld") | AudioManager.play_sfx("hit") | AudioManager.stop_bgm()
extends Node

const BGM_PATH := "res://assets/audio/bgm/"
const SFX_PATH := "res://assets/audio/sfx/"
const SFX_POOL_SIZE := 8
const BGM_FADE_OUT := 0.5
const BGM_FADE_IN  := 0.6

# Nomes de tracks e SFX esperados (arquivos .ogg em assets/audio/)
# BGM: title, overworld, battle
# SFX: select, confirm, cancel, step, attack_physical, attack_special, hit,
#       faint, catch_throw, catch_success, catch_fail, level_up, heal, flee

var _bgm_a   : AudioStreamPlayer
var _bgm_b   : AudioStreamPlayer
var _sfx_pool : Array[AudioStreamPlayer] = []
var _sfx_idx  : int = 0
var _current_bgm : String = ""
var _bgm_active : AudioStreamPlayer  # qual player está tocando agora

# Buses criados via AudioServer (Master > BGM, Master > SFX)
# Se os buses não existirem, AudioManager usa volume linear no player.
var _bgm_bus_idx : int = 0
var _sfx_bus_idx : int = 0

func _ready() -> void:
	_setup_buses()
	_bgm_a = _make_bgm_player("BGM_A")
	_bgm_b = _make_bgm_player("BGM_B")
	_bgm_active = _bgm_a
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.volume_db = 0.0
		add_child(p)
		_sfx_pool.append(p)

func _setup_buses() -> void:
	# Garante que os buses BGM e SFX existem
	_ensure_bus("BGM")
	_ensure_bus("SFX")
	_bgm_bus_idx = AudioServer.get_bus_index("BGM")
	_sfx_bus_idx = AudioServer.get_bus_index("SFX")

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")

func _make_bgm_player(node_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.bus = "BGM"
	p.volume_db = 0.0
	add_child(p)
	return p

# ── BGM ─────────────────────────────────────────────────────────────────────

## Toca uma trilha BGM. Se já está tocando a mesma, não faz nada.
## track: nome do arquivo sem extensão (ex: "overworld", "battle", "title")
func play_bgm(track: String) -> void:
	if track == _current_bgm:
		return
	_current_bgm = track
	var path := BGM_PATH + track + ".ogg"
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: BGM não encontrado: %s" % path)
		return
	var stream : AudioStream = load(path)
	# Crossfade: novo player entra, antigo sai
	var next := _bgm_b if _bgm_active == _bgm_a else _bgm_a
	next.stream = stream
	next.volume_db = -80.0
	next.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_bgm_active, "volume_db", -80.0, BGM_FADE_OUT)
	tw.tween_property(next,        "volume_db",   0.0, BGM_FADE_IN)
	await tw.finished
	_bgm_active.stop()
	_bgm_active = next

## Para o BGM com fade.
func stop_bgm(fade: float = BGM_FADE_OUT) -> void:
	_current_bgm = ""
	if not _bgm_active.playing:
		return
	var tw := create_tween()
	tw.tween_property(_bgm_active, "volume_db", -80.0, fade)
	await tw.finished
	_bgm_active.stop()

## Para o BGM instantaneamente (usado antes de fade de cena).
func stop_bgm_instant() -> void:
	_current_bgm = ""
	_bgm_a.stop()
	_bgm_b.stop()

# ── SFX ─────────────────────────────────────────────────────────────────────

## Toca um SFX one-shot. sfx: nome sem extensão (ex: "hit", "level_up").
func play_sfx(sfx: String) -> void:
	var path := SFX_PATH + sfx + ".ogg"
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: SFX não encontrado: %s" % path)
		return
	var player := _sfx_pool[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % SFX_POOL_SIZE
	player.stream = load(path)
	player.play()

# ── Volume ───────────────────────────────────────────────────────────────────

## volume: 0.0 a 1.0
func set_master_volume(volume: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),
		linear_to_db(clampf(volume, 0.0, 1.0)))

func set_bgm_volume(volume: float) -> void:
	AudioServer.set_bus_volume_db(_bgm_bus_idx,
		linear_to_db(clampf(volume, 0.0, 1.0)))

func set_sfx_volume(volume: float) -> void:
	AudioServer.set_bus_volume_db(_sfx_bus_idx,
		linear_to_db(clampf(volume, 0.0, 1.0)))

func get_bgm_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(_bgm_bus_idx))

func get_sfx_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(_sfx_bus_idx))
