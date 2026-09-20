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

## Fase 21: um selvagem caiu e deixou corpo. Quem escuta é a HUD (pra desenhar o
## relógio da §28) e o treinador (pra saber em que mirar).
signal corpo_deixado(corpo: Node3D)

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

## Quando cada elite caiu, em segundos. A régua do Gabriel (18/09): a chance de
## Alpha sobe 0,1% **por elite derrotado nas últimas 3 horas**.
##
## ⚠️ É uma `Array`, e Array em GDScript é referência: dois spawners que
## recebam a MESMA lista contam juntos. Hoje só existe um spawner por cena,
## então nada a fazer; quando houver vários, quem os cria passa uma lista só —
## senão cada zona contaria a sua e o bônus sairia menor que o especificado.
##
## ✅ 19/09: isto **sobrevive a salvar e carregar** — `para_o_save()` /
## `do_save()` mais abaixo, guardado em `world.elites_derrotados`. O comentário
## anterior dizia que a V3 não tinha save; tinha (o `SaveManager` da V2).

## RFC-008: por que a última tentativa de nascimento foi recusada. Existe porque
## "o spawn falhou" sem motivo é a mesma classe de silêncio que este projeto
## passou o mês caçando — com isto, medir *onde* o mundo está recusando corpos é
## uma pergunta, não uma escavação. Vazio quando o último nascimento deu certo.
var ultimo_motivo_de_recusa : String = RegraDeHabitabilidade.OK

var derrotas_de_elite : Array = []

var _vivos : Array = []
var _desde_o_ultimo : float = 0.0

## O relógio da janela de 3 horas. Separado pra o teste poder empurrar o tempo
## sem esperar três horas de verdade.
var agora : Callable = _agora_padrao

func _agora_padrao() -> float:
	return float(Time.get_unix_time_from_system())

func _agora() -> float:
	return float(agora.call())

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

	# RFC-008: o arquétipo precisa ser conhecido ANTES de escolher o ponto — é
	# ele que decide se a encosta e a água barram. Lido da mesma fonte que o
	# `montar()` vai ler, pra os dois nunca discordarem sobre o mesmo bicho.
	var arquetipo : String = str(GameData.get_species(id).get(
		"arquetipo", MovementProfile.GROUND_BIPED))

	var ponto := Vector3.ZERO
	var achou : bool = false
	# Tenta alguns pontos antes de desistir. Desistir na primeira recusa faria a
	# densidade de spawn cair perto da costa e da falésia **em silêncio** — o
	# jogador andaria pra praia e o mundo esvaziaria sem nada dizer por quê.
	for _tentativa in RegraDeHabitabilidade.TENTATIVAS:
		var candidato := RegraDeSpawn.ponto_no_anel(
			jogador.global_position, sortear.call(), sortear.call())
		# O chão manda no Y. E a trava do anel é reconferida DEPOIS de o terreno
		# opinar — ver o comentário do cabeçalho sobre travas que só vivem na
		# regra.
		candidato.y = Terreno3D.altura_em(candidato.x, candidato.z)
		if not RegraDeSpawn.distancia_segura(jogador.global_position, candidato):
			continue
		var veredito : Dictionary = RegraDeHabitabilidade.pode_nascer(
			arquetipo,
			Terreno3D.superficie_em(candidato.x, candidato.z),
			rad_to_deg(Terreno3D.inclinacao_em(candidato.x, candidato.z)),
			rad_to_deg(Locomocao3D.ANGULO_MAXIMO_DE_SUBIDA))
		if not bool(veredito["pode"]):
			ultimo_motivo_de_recusa = str(veredito["motivo"])
			continue
		ponto = candidato
		achou = true
		break
	if not achou:
		return null
	ultimo_motivo_de_recusa = RegraDeHabitabilidade.OK

	# Fase 18, régua do Gabriel (18/09): elite e Alpha são **sorteios
	# independentes**. A chance de Alpha cresce com os elites derrotados nas
	# últimas 3 horas, e a curadoria por espécie ainda manda.
	#
	# O perigo da zona multiplica os DOIS pela mesma régua — senão um Alpha
	# nasceria em Pallet Town, onde a chance de elite é zero.
	var alpha : bool = RegraDeAlpha.sortear(
		GameData.get_species(id), sortear.call(),
		derrotas_de_elite, _agora(), PerigoDaZona.perigo(zona))
	var bicho := PokemonInstance3D.nascer(self, id, nivel, ponto, "",
		RegraDeMovePool.CATEGORIA_PADRAO, alpha)
	bicho.elite = elite
	# Fase 21: quem cai deixa corpo. Ligado ao SINAL, e não à varredura de
	# `_limpar_mortos`, de propósito — a varredura roda depois, e até lá o nó já
	# pode ter sido liberado. O corpo tem de nascer onde ele caiu, no instante
	# em que caiu.
	bicho.derrotado.connect(_ao_cair)
	bicho.virar_selvagem(jogador)
	_vivos.append(bicho)
	nasceu.emit(bicho, entrada, elite)
	return bicho

## Fase 21: um selvagem caiu. Nasce o corpo, e o elite entra na janela do Alpha
## **aqui**, não na varredura.
##
## ⚠️ A contagem de elite saiu do `_limpar_mortos` pra cá porque lá ela dependia
## de o nó ainda ser válido quando a varredura passasse: um elite liberado antes
## disso simplesmente não contava, e o bônus que o jogador ganhou sumia sem que
## nada acusasse. Aqui o sinal chega no quadro da queda.
func _ao_cair(quem: Node) -> void:
	if not (quem is PokemonInstance3D):
		return
	var caido : PokemonInstance3D = quem
	if caido.elite:
		registrar_elite_derrotado()
	corpo_deixado.emit(Corpo3D.nascer(get_parent_ou_eu(), caido, sortear.call()))

## O corpo nasce como irmão do spawner, não filho: o spawner despeja quem está
## longe, e um corpo filho iria junto quando isso acontecesse.
func get_parent_ou_eu() -> Node:
	var p := get_parent()
	return p if p != null else self

## Tira da conta quem morreu ou foi liberado. Sem isto a população só cresce no
## contador e a zona para de gerar encontro — um bug que só aparece depois de
## meia hora de jogo, que é o pior tipo.
func _limpar_mortos() -> void:
	var sobrando : Array = []
	for b in _vivos:
		if is_instance_valid(b) and not b.esta_derrotado():
			sobrando.append(b)
			continue
		# ⚠️ A contagem de elite NÃO mora mais aqui — mudou pra `_ao_cair`, que
		# é o sinal da queda. Andar pra longe de um elite continua não sendo
		# derrotá-lo: `_despejar_distantes` nunca emite `derrotado`.
	_vivos = sobrando

## Um elite caiu. Público porque o combate (Fase 12) também pode saber disso
## antes do spawner varrer a lista.
func registrar_elite_derrotado(quando: float = -1.0) -> void:
	derrotas_de_elite.append(_agora() if quando < 0.0 else quando)
	_esquecer_velhas()

## ── Atravessar o salvar/carregar (19/09) ────────────────────────────────────
##
## A janela de 3 h do Alpha é de tempo **real**, não de tempo jogado: os
## carimbos são Unix (`Time.get_unix_time_from_system`). Isso faz a regra do
## Gabriel — *"nas últimas 3 hrs"* — continuar significando três horas de
## relógio mesmo com o jogo fechado no meio, sem nenhum código a mais.
##
## Fosse tempo de sessão, fechar o jogo congelaria a janela e o jogador
## acumularia bônus guardando-o de um dia pro outro.

## O que salvar. Já esquece o que saiu da janela: guardar carimbo morto é
## engordar o save com dado que não influencia nada.
func para_o_save() -> Array:
	_esquecer_velhas()
	return derrotas_de_elite.duplicate()

## Restaurar do save.
##
## ⚠️ **Preenche no lugar**, como `_esquecer_velhas` — e pela mesma razão, que
## já custou um bug aqui: `derrotas_de_elite = lista` faria este spawner apontar
## pra outra lista, e dois spawners que compartilhavam a contagem por referência
## se separariam **em silêncio** no carregar. Carimbo inválido é descartado em
## vez de contaminar a janela.
func do_save(lista) -> void:
	var limpa : Array = []
	if lista is Array:
		for quando in lista:
			if typeof(quando) in [TYPE_FLOAT, TYPE_INT]:
				limpa.append(float(quando))
	derrotas_de_elite.clear()
	derrotas_de_elite.append_array(limpa)
	# Um save antigo pode trazer carimbo já vencido — a janela manda, não o
	# arquivo.
	_esquecer_velhas()

## A lista não cresce pra sempre: o que saiu da janela não influencia mais nada
## e guardar é só memória vazando devagar.
##
## ⚠️ Limpa **no lugar**. Trocar por `derrotas_de_elite = vivas` faria este
## spawner passar a apontar pra outra lista, e dois spawners que compartilhavam
## a contagem se separariam em silêncio na primeira limpeza.
func _esquecer_velhas() -> void:
	var t : float = _agora()
	var vivas : Array = []
	for quando in derrotas_de_elite:
		if t - float(quando) < RegraDeAlpha.JANELA_SEGUNDOS:
			vivas.append(quando)
	derrotas_de_elite.clear()
	derrotas_de_elite.append_array(vivas)

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
