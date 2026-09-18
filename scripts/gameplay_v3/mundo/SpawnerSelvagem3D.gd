## SpawnerSelvagem3D.gd — Quem põe selvagem no mundo (Fase 11).
##
## Executor. **Nenhuma regra mora aqui**: quando, o quê e onde vêm de
## `RegraDeSpawn`, e o perigo da zona de `PerigoDaZona`. O que sobra é o que só o
## nó pode fazer — achar o chão, criar o corpo, e limpar quem ficou longe.
##
## ── As três coisas que este arquivo existe pra garantir ─────────────────────
##
## 1. **Todo nascimento passa por `PokemonInstance3D.nascer()`.** É o contrato de
##    17/09: posicionar depois do `add_child` catapulta quem estiver na origem do
##    mundo. Um spawner é justamente o lugar onde esse erro aconteceria mil vezes.
##
## 2. **Ninguém nasce em cima do jogador.** O anel de `RegraDeSpawn` já impede,
##    e aqui a trava é conferida de novo antes de criar — porque o terreno pode
##    empurrar o ponto, e uma trava que só existe na regra não protege o executor.
##
## 3. **O chão é do terreno, não chutado.** `Terreno3D.altura_em(x, z)` é a fonte
##    única de verdade geográfica. Nascer num Y fixo põe bicho dentro da montanha
##    ou flutuando sobre o vale, e as duas coisas parecem bug de física.
class_name SpawnerSelvagem3D
extends Node3D

signal nasceu(quem: Node3D, entrada: Dictionary, elite: bool)
signal desapareceu(quem: Node3D)

## A zona em que este spawner atua — o dicionário de `zones.json`, inteiro. Não
## uma cópia com "só os campos que preciso": `PerigoDaZona` lê a tabela de
## `wild_pokemon` pra calcular o perigo, e uma cópia parcial mentiria pra ele.
var zona : Dictionary = {}

## Quem os selvagens consideram hostil (o treinador, ou o Pokémon que o jogador
## está controlando).
var jogador : Node3D = null

## Se falso, nada nasce. Existe pro combate poder congelar o mundo (Fase 12) sem
## o spawner encher a briga de espectadores.
var ativo : bool = true

## Sorteio injetável. O padrão usa o `RNGManager`, que é o RNG do jogo inteiro —
## o teste troca por uma função própria pra forçar o primeiro e o último da
## tabela em vez de rodar mil vezes e torcer.
##
## ⚠️ O padrão NÃO pode citar `RNGManager` direto: autoload não é identificador
## quando o script é compilado num teste `--script`, e o valor padrão de uma
## variável é resolvido na carga da classe. A primeira versão citava, e a suíte
## imprimia `Compile Error: Identifier not found: RNGManager` **e passava mesmo
## assim**, porque o teste ainda produzia a linha de resultado. Erro de compilação
## que não reprova é o pior tipo: ele ensina a ignorar vermelho.
##
## Resolvendo por caminho, em tempo de chamada, funciona nos dois mundos.
var sortear : Callable = _sorteio_padrao

func _sorteio_padrao() -> float:
	var rng := get_node_or_null("/root/RNGManager")
	return rng.randf() if rng != null else randf()

var _vivos : Array = []
var _desde_o_ultimo : float = 0.0

func _ready() -> void:
	add_to_group("spawner_selvagem_v3")

func _process(delta: float) -> void:
	_limpar_mortos()
	_despejar_distantes()
	if not ativo or jogador == null or not is_instance_valid(jogador):
		return
	_desde_o_ultimo += delta
	if not RegraDeSpawn.pode_nascer(zona, _vivos.size(), _desde_o_ultimo):
		return
	_desde_o_ultimo = 0.0
	tentar_nascer()

## Quantos selvagens deste spawner estão vivos agora. A HUD e o teste perguntam;
## ninguém recalcula contando nós na árvore.
func vivos() -> int:
	return _vivos.size()

func populacao_maxima() -> int:
	return RegraDeSpawn.populacao_maxima(zona)

## Faz nascer um, se der. Devolve o nó, ou `null` — e `null` **não é erro**: zona
## sem tabela de encontro (uma cidade) é caso normal, e ponto ruim de nascimento
## também.
func tentar_nascer() -> Node3D:
	var entrada : Dictionary = RegraDeSpawn.sortear_especie(zona, sortear.call())
	if entrada.is_empty():
		return null

	var elite : bool = RegraDeSpawn.e_elite(zona, sortear.call())
	var nivel : int = RegraDeSpawn.nivel(entrada, elite, sortear.call())
	var id : int = int(entrada.get("id", 0))
	if id <= 0:
		return null

	var ponto := RegraDeSpawn.ponto_no_anel(
		jogador.global_position, sortear.call(), sortear.call())
	# O chão manda no Y. E a trava do anel é reconferida DEPOIS de o terreno
	# opinar — ver o comentário do cabeçalho sobre travas que só vivem na regra.
	ponto.y = Terreno3D.altura_em(ponto.x, ponto.z)
	if not RegraDeSpawn.distancia_segura(jogador.global_position, ponto):
		return null

	# Fase 18: o fio que a Fase 17 deixou solto. Elite e Alpha eram conceitos
	# que se pareciam e não são o mesmo — Alpha é **subconjunto** de elite, e
	# ainda depende da curadoria por espécie (`is_alpha_eligible`), que até
	# hoje nenhuma linha do jogo lia.
	var alpha : bool = RegraDeAlpha.sortear(
		GameData.get_species(id), elite, sortear.call())
	var bicho := PokemonInstance3D.nascer(self, id, nivel, ponto, "",
		RegraDeMovePool.CATEGORIA_PADRAO, alpha)
	bicho.virar_selvagem(jogador)
	_vivos.append(bicho)
	nasceu.emit(bicho, entrada, elite)
	return bicho

## Tira da conta quem morreu ou foi liberado. Sem isto a população só cresce no
## contador e a zona para de gerar encontro — um bug que só aparece depois de
## meia hora de jogo, que é o pior tipo.
func _limpar_mortos() -> void:
	var sobrando : Array = []
	for b in _vivos:
		if is_instance_valid(b) and not b.esta_derrotado():
			sobrando.append(b)
	_vivos = sobrando

## Quem ficou longe desaparece. **Nunca quem está provocado**: um bicho que te
## persegue sumindo no meio da perseguição é pior que um bicho a mais no mundo —
## o jogador lê isso como o jogo desistindo.
func _despejar_distantes() -> void:
	if jogador == null or not is_instance_valid(jogador):
		return
	var sobrando : Array = []
	for b in _vivos:
		if not is_instance_valid(b):
			continue
		var d : float = Vector3(b.global_position.x - jogador.global_position.x, 0.0,
								b.global_position.z - jogador.global_position.z).length()
		if RegraDeSpawn.deve_desaparecer(d) and not b.provocado:
			desapareceu.emit(b)
			b.queue_free()
			continue
		sobrando.append(b)
	_vivos = sobrando
