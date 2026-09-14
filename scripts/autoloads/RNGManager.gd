## RNGManager.gd — RNG centralizado com seed configurável (Autoload/Singleton)
## Todos os sistemas usam este singleton para garantir reprodutibilidade e debug.
extends Node

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed: int = 0

func _ready() -> void:
	# Seed aleatório por padrão; pode ser fixado para debug
	randomize_seed()

## Define seed fixa (útil para testes reproduzíveis)
func set_seed(seed_value: int) -> void:
	_seed = seed_value
	_rng.seed = seed_value

## Gera nova seed aleatória e a registra
func randomize_seed() -> void:
	_rng.randomize()
	_seed = _rng.seed

## Retorna a seed atual (para salvar no SaveManager)
func get_seed() -> int:
	return _seed

## O estado interno agora — para quem precisa consultar o RNG sem MOVER a
## sequência dos outros sorteios (achado do Codex, 14/09).
##
## O caso concreto: `DanoV2` chama `DamageCalculator.detalhar()` só pra pegar os
## componentes da conta, e descarta o crítico e a variação que ela sorteia. O
## dano sai determinístico, mas os dois sorteios já tinham avançado o RNG — e aí
## um golpe deslocava, de lado, os sorteios de status, captura e loot.
##
## Ninguém mais precisa disso: quem sorteia de verdade continua avançando o
## estado normalmente, como sempre.
func get_state() -> int:
	return _rng.state

func set_state(estado: int) -> void:
	_rng.state = estado

## Float entre 0.0 e 1.0
func randf() -> float:
	return _rng.randf()

## Float entre min e max
func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)

## Int entre min e max (inclusive)
func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

## Retorna true com probabilidade 0.0–1.0
func chance(probability: float) -> bool:
	return _rng.randf() < probability

## Escolhe elemento aleatório de um Array
func pick(array: Array) -> Variant:
	if array.is_empty():
		return null
	return array[_rng.randi_range(0, array.size() - 1)]

## Sorteia 'count' elementos únicos de um Array (sem repetição)
func pick_unique(array: Array, count: int) -> Array:
	var copy: Array = array.duplicate()
	var result: Array = []
	count = min(count, copy.size())
	for i in count:
		var idx: int = _rng.randi_range(0, copy.size() - 1)
		result.append(copy[idx])
		copy.remove_at(idx)
	return result

## Embaralha Array in-place e retorna ele
func shuffle(array: Array) -> Array:
	_rng.shuffle(array)
	return array
