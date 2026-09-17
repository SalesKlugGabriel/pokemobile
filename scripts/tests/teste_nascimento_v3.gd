## teste_nascimento_v3.gd — O contrato de nascimento de um Pokémon 3D.
##
## Trava o achado de 17/09, que custou caro pra entender e é trivial de cometer
## de novo.
##
## ── O que aconteceu ─────────────────────────────────────────────────────────
##
## Um `CharacterBody3D` passa **um quadro de física** com o colisor onde nasceu,
## antes de o servidor de física acompanhar uma atribuição de `global_position`
## feita depois do `add_child`. Nesse quadro, quem estiver naquele ponto **pousa
## no bicho novo** — e quando o colisor salta pro lugar certo, o Godot carrega
## quem está em pé nele, porque é assim que plataforma móvel funciona.
##
## ```
## posição definida ANTES  do add_child   deslocamento 0,000 m
## posição definida DEPOIS do add_child   deslocamento 1,265 m
## ```
##
## O Charizard terminava em cima da cabeça de um Rattata a 1,2 m de distância. Eu
## perdi um tempo achando que era colisor, porque as cápsulas não se sobrepõem
## (0,476 + 0,180 = 0,656 < 1,2). Não era geometria: era ordem.
##
## ── Por que isto precisa de teste próprio ───────────────────────────────────
##
## A Fase 11 cria Pokémon selvagem a cada encontro. Um spawner que erre a ordem
## **catapulta o jogador**, e o sintoma (personagem voando) não parece nada com a
## causa (ordem de duas linhas). Nenhum teste de combate pegaria isso: as Fases 3
## a 10 nunca põem dois Pokémon perto e parados.
extends SceneTree

var ok : int = 0
var fail : int = 0
var _quadros : int = 0
var _certo = null
var _errado = null
var _mundo : Node3D = null

func _conf(nome: String, cond: bool, detalhe: String = "") -> void:
	if cond:
		ok += 1
		print("  OK   ", nome)
	else:
		fail += 1
		print("  FALHOU ", nome, "  ", detalhe)

func _initialize() -> void:
	print("=== Contrato de nascimento de um Pokémon 3D ===")

func _chao(pai: Node3D, x: float) -> void:
	var chao := StaticBody3D.new()
	var f := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(40, 1, 40)
	f.shape = bx
	chao.add_child(f)
	chao.position = Vector3(x, -0.5, 0)
	pai.add_child(chao)

func _montar() -> void:
	_mundo = Node3D.new()
	root.add_child(_mundo)
	var P = load("res://scripts/gameplay_v3/entidades/PokemonInstance3D.gd")

	# ⚠️ Os dois casos ficam a 300 m um do outro, e isso NÃO é exagero: o espaço
	# de física é compartilhado, e na primeira versão deste experimento um corpo
	# nascido num caso carregou o Charizard do OUTRO caso por 500 m. Medição
	# contaminada é pior que medição ausente, porque parece resultado.
	_chao(_mundo, 0.0)
	_chao(_mundo, 300.0)

	# 🔴 Achado ao montar este teste, e ele é PIOR do que eu tinha entendido:
	# o corpo com ordem errada não aparece perto do destino dele — aparece na
	# **origem do mundo**, porque é a posição do pai. Então ele catapulta quem
	# estiver na origem, não importa a quantos metros esteja o destino.
	#
	# Na primeira versão deste arquivo, um Rattata destinado a 300 m carregou o
	# Charizard do caso CERTO, que estava na origem, por 300 metros. O caso certo
	# reprovou por culpa do caso errado.
	#
	# Por isso o caso CERTO mora longe da origem, e a vítima do caso errado é
	# quem está NA origem — que é o cenário real de um jogador parado no spawn.

	# CASO CERTO — `nascer()`: posição antes de entrar na árvore, longe da origem.
	_certo = P.nascer(_mundo, 6, 50, Vector3(300, 0, 0), "ground_biped")
	P.nascer(_mundo, 19, 20, Vector3(300, 0, -1.2))

	# CASO ERRADO — reproduzido de propósito, com a vítima na origem.
	_errado = P.nascer(_mundo, 6, 50, Vector3.ZERO, "ground_biped")
	var tardio = P.new()
	_mundo.add_child(tardio)
	tardio.montar(19, 20)
	tardio.global_position = Vector3(0, 0, -1.2)

func _process(_delta: float) -> bool:
	_quadros += 1
	if _quadros == 1:
		_montar()
		return false
	if _quadros < 8:
		return false

	var d_certo : float = Vector3(300, 0, 0).distance_to(_certo.global_position)
	var d_errado : float = Vector3.ZERO.distance_to(_errado.global_position)

	_conf("nascendo pelo `nascer()`, ninguém se desloca",
		d_certo < 0.05, "deslocou %.3f m -> %s" % [d_certo, str(_certo.global_position)])
	# O corpo de ordem errada nasce na ORIGEM do mundo (posição do pai), não perto
	# do destino — e é isso que faz o estrago alcançar qualquer distância. Não há
	# asserção própria pra isso porque ela seria `true` fixo: asserção que sempre
	# passa é comentário disfarçado de teste. Quem prova é a linha abaixo, que
	# mede o deslocamento real de quem estava na origem.

	# A conferência ao contrário importa tanto quanto: se o jeito errado parar de
	# catapultar, o teste de cima passa a provar nada, e ninguém saberia.
	_conf("e o jeito errado AINDA catapulta — o risco é real, não teórico",
		d_errado > 0.5, "deslocou só %.3f m" % d_errado)

	_conf("quem nasceu certo continua no chão, não na cabeça de ninguém",
		_certo.global_position.y < 0.2, "y = %.3f" % _certo.global_position.y)

	print("\n      medido: certo %.3f m · errado %.3f m" % [d_certo, d_errado])
	print("\n=== Resultado: %d ok, %d falhas ===" % [ok, fail])
	quit(1 if fail > 0 else 0)
	return true
