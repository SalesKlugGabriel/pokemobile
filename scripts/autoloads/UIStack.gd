## UIStack.gd — Pilha de telas abertas (04/09).
##
## Por que existe: no teste de gameplay de 04/09, a criança que "jogou" ficou
## presa duas vezes. Abrir a Pokédex e apertar Esc não fazia nada (o painel só
## escutava a própria tecla), e apertar Esc com o Time aberto abria o menu de
## Pausa POR CIMA dele, em vez de fechar o de cima. Os menus empilhavam.
##
## A causa comum era não haver NOÇÃO de "tela do topo" em lugar nenhum: cada
## painel cuidava da própria tecla e ninguém sabia o que mais estava aberto.
## Consertar painel por painel resolveria os dois casos de hoje e deixaria o
## próximo painel novo nascer com o mesmo defeito — então a correção é aqui,
## uma vez só, e todo painel passa a se registrar.
##
## Contrato pra qualquer painel novo:
##   ao abrir  -> UIStack.empilhar(self, Callable(self, "minha_funcao_de_fechar"))
##   ao fechar -> UIStack.desempilhar(self)
## Quem fecha na tecla Esc é o menu de Pausa, chamando `fechar_topo()` antes de
## decidir abrir a si mesmo.
extends Node

## Cada item: { "no": Node, "fechar": Callable }
var _pilha : Array[Dictionary] = []

## Registra um painel como aberto. Se ele já estava na pilha, sobe pro topo
## (abrir duas vezes não pode criar duas entradas).
func empilhar(no: Node, fechar: Callable) -> void:
	desempilhar(no)
	_pilha.append({"no": no, "fechar": fechar})

## Tira um painel da pilha. Seguro chamar mesmo que ele não esteja lá.
func desempilhar(no: Node) -> void:
	for i in range(_pilha.size() - 1, -1, -1):
		if _pilha[i]["no"] == no:
			_pilha.remove_at(i)

## Fecha o painel do topo. Devolve true se havia algo pra fechar — quem chamou
## usa isso pra saber se ainda deve tratar a tecla (ex: abrir o menu de Pausa).
func fechar_topo() -> bool:
	_limpar_orfaos()
	if _pilha.is_empty():
		return false
	var topo : Dictionary = _pilha[_pilha.size() - 1]
	_pilha.remove_at(_pilha.size() - 1)
	var fechar : Callable = topo["fechar"]
	if fechar.is_valid():
		fechar.call()
	return true

## Fecha tudo, de cima pra baixo. Usado na troca de mapa/cena, pra nenhum painel
## sobreviver invisível a uma transição e voltar depois sem dono.
func fechar_tudo() -> void:
	while fechar_topo():
		pass

func tem_aberto() -> bool:
	_limpar_orfaos()
	return not _pilha.is_empty()

func quantidade() -> int:
	_limpar_orfaos()
	return _pilha.size()

## Painel do topo, ou null. Serve pra teste e pra depuração.
func topo() -> Node:
	_limpar_orfaos()
	if _pilha.is_empty():
		return null
	return _pilha[_pilha.size() - 1]["no"]

## Painéis instanciados dentro do MAPA (Pausa, Time) morrem na troca de cena;
## os de GlobalUI (Pokédex) não. Sem esta limpeza a pilha guardaria referência
## pra nó liberado e `fechar_topo()` chamaria um Callable morto.
func _limpar_orfaos() -> void:
	for i in range(_pilha.size() - 1, -1, -1):
		# Sem tipo explícito de propósito: atribuir uma instância JÁ LIBERADA a
		# uma variável `: Node` levanta erro em tempo de execução no Godot 4
		# (achado pelo próprio teste desta peça). O objeto liberado só pode ser
		# tocado como Variant, e só por is_instance_valid().
		var no = _pilha[i]["no"]
		if not is_instance_valid(no):
			_pilha.remove_at(i)
			continue
		if not (no as Node).is_inside_tree():
			_pilha.remove_at(i)
