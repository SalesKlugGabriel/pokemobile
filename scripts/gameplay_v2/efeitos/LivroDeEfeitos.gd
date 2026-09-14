## LivroDeEfeitos.gd — Buffs, debuffs e status (§16, §17, §18, §23, §24).
##
## ── Por que é um LIVRO e não um punhado de variáveis ─────────────────────────
##
## A tentação é guardar `ataque_modificado` e ir somando. Isso morre no primeiro
## caso da §16: dois efeitos opostos que se compensam **mas continuam correndo**,
## e quando um acaba o outro volta a valer sozinho. Um número guardado não sabe
## voltar; um livro-razão sabe, porque o valor é sempre uma soma recalculada.
##
## Cada linha tem autor, atributo, intensidade, duração e origem. O valor de um
## atributo é **sempre** a soma das linhas vivas — nunca um campo.
##
## ── As regras, na ordem em que o Gabriel escreveu ────────────────────────────
##
## §16  skills diferentes somam; a MESMA skill reaplicada não empilha (fica a
##      maior intensidade E a maior duração); opostos se compensam no saldo, mas
##      os dois timers continuam.
## §17  DoT reaplicado: vence a maior intensidade, depois a maior duração —
##      e nunca se reduz o que já estava melhor. Status sem dano (sono, gelo,
##      paralisia) não tem intensidade: só duração, e fica a maior.
## §18  Depois que um status negativo acaba, 1 segundo de imunidade **àquele**
##      status. O golpe continua dando dano; só a aplicação do status falha.
## §23  Saldo além do limite funcional trava no limite, e o excedente vira
##      duração: cada 10% de excedente = +1 s, **no último efeito que empurrou
##      além do limite**, uma vez por instância.
## §24  Efeito que expira e outro que entra no mesmo quadro: expira primeiro,
##      recalcula, aí aplica o novo.
##
## ── Por que classe pura ──────────────────────────────────────────────────────
##
## É tudo conta. Ficando aqui, os quatro casos da especificação viram teste com
## número esperado — e foi assim que eu descobri que tinha entendido errado o
## §23 na primeira escrita (ver `teste_efeitos_v2.gd`).
class_name LivroDeEfeitos
extends RefCounted

## §23: cada 10% de excedente vira 1 segundo.
const EXCEDENTE_POR_SEGUNDO : float = 0.10

## §18: quanto dura a imunidade ao mesmo status logo depois dele acabar.
const IMUNIDADE_APOS_STATUS : float = 1.0

## Status sem intensidade variável (§17): só a duração importa.
const SEM_INTENSIDADE : Array[String] = ["sleep", "freeze", "paralysis", "confusion"]

# ──────────────────────────────────────────────────────────────────────────────
# Estado
# ──────────────────────────────────────────────────────────────────────────────

## Cada linha: {skill, atributo, intensidade, restante, de_item, ganhou_bonus}
var linhas : Array[Dictionary] = []

## Status ativos: nome → {restante, intensidade}
var status : Dictionary = {}

## §18: nome → segundos de imunidade restantes.
var _imunidade : Dictionary = {}

# ──────────────────────────────────────────────────────────────────────────────
# Buffs e debuffs (§16, §23)
# ──────────────────────────────────────────────────────────────────────────────

## Aplica um efeito sobre um atributo.
##
## `intensidade` é fração com sinal: 0.15 = +15%, -0.10 = −10%.
## `limite` é o teto funcional daquele atributo AGORA (§22: é dinâmico, quem
## chama calcula). Zero ou negativo significa "sem teto".
## `de_item` marca efeito de Held, que `limpar()` nunca remove (§21, §49).
##
## Devolve o que aconteceu, pra quem chamou poder avisar na tela:
## {"novo": bool, "bonus_de_duracao": float, "saldo": float}
func aplicar(skill: String, atributo: String, intensidade: float,
		duracao: float, limite: float = 0.0, de_item: bool = false) -> Dictionary:
	var saldo_antes := saldo(atributo)

	# §16: a MESMA skill reaplicada não cria linha nova. Fica a maior
	# intensidade **e** a maior duração — as duas escolhidas em separado, então
	# um golpe fraco e longo não rouba a intensidade de um forte e curto.
	var existente := _achar(skill, atributo)
	var e_nova := existente < 0
	if not e_nova:
		var l : Dictionary = linhas[existente]
		if absf(intensidade) > absf(float(l["intensidade"])):
			l["intensidade"] = intensidade
		l["restante"] = maxf(float(l["restante"]), duracao)
		linhas[existente] = l
	else:
		linhas.append({
			"skill": skill, "atributo": atributo, "intensidade": intensidade,
			"restante": duracao, "de_item": de_item, "ganhou_bonus": false,
		})

	var bonus := _excedente_vira_duracao(atributo, limite, saldo_antes)
	return {"novo": e_nova, "bonus_de_duracao": bonus, "saldo": saldo(atributo)}

## §23. O excedente além do limite vira duração **no último efeito que
## contribuiu pra passar do limite** — que é sempre o que acabou de entrar,
## porque é ele que mudou o saldo.
##
## Três sutilezas que a especificação exige e que é fácil perder:
##  - vale pro excesso negativo também (debuff empilhado além do piso);
##  - o tempo extra **não some** se depois outro efeito compensar o saldo;
##  - só uma vez por instância viva da mesma skill (`ganhou_bonus`).
func _excedente_vira_duracao(atributo: String, limite: float, saldo_antes: float) -> float:
	if limite <= 0.0 or linhas.is_empty():
		return 0.0
	var agora := saldo(atributo)
	var excedente := absf(agora) - limite
	if excedente <= 0.0:
		return 0.0
	# Só conta como "empurrou além" se o saldo de fato piorou nesta direção.
	if absf(agora) <= absf(saldo_antes):
		return 0.0

	var i := _ultima_linha(atributo)
	if i < 0:
		return 0.0
	var l : Dictionary = linhas[i]
	if bool(l["ganhou_bonus"]):
		return 0.0

	var bonus := floorf(excedente / EXCEDENTE_POR_SEGUNDO)
	if bonus <= 0.0:
		return 0.0
	l["restante"] = float(l["restante"]) + bonus
	l["ganhou_bonus"] = true
	linhas[i] = l
	return bonus

## A soma crua das linhas vivas deste atributo. Pode passar do limite — é o
## §16 ("os dois continuam ativos com seus próprios timers").
func saldo(atributo: String) -> float:
	var s := 0.0
	for l in linhas:
		if str(l["atributo"]) == atributo:
			s += float(l["intensidade"])
	return s

## O valor que o combate realmente usa: o saldo travado no limite (§23).
func valor_efetivo(atributo: String, limite: float = 0.0) -> float:
	var s := saldo(atributo)
	if limite <= 0.0:
		return s
	return clampf(s, -limite, limite)

## O multiplicador pronto pra multiplicar uma stat. 1.0 = sem efeito.
func multiplicador(atributo: String, limite: float = 0.0) -> float:
	return 1.0 + valor_efetivo(atributo, limite)

# ──────────────────────────────────────────────────────────────────────────────
# Status (§17, §18)
# ──────────────────────────────────────────────────────────────────────────────

## Tenta aplicar um status. Devolve false quando a imunidade da §18 barrou —
## e nesse caso **o dano do golpe continua valendo**, quem chama é que decide.
func aplicar_status(nome: String, duracao: float, intensidade: float = 0.0) -> bool:
	if float(_imunidade.get(nome, 0.0)) > 0.0:
		return false

	if not status.has(nome):
		status[nome] = {"restante": duracao, "intensidade": intensidade}
		return true

	var s : Dictionary = status[nome]
	# §17: nunca reduzir o que já está melhor. Intensidade e duração são
	# escolhidas SEPARADAMENTE — é isso que produz o exemplo do Gabriel
	# (20/tick por 8 s + 30/tick por 5 s = 30/tick por 8 s).
	if not (nome in SEM_INTENSIDADE):
		s["intensidade"] = maxf(float(s["intensidade"]), intensidade)
	s["restante"] = maxf(float(s["restante"]), duracao)
	status[nome] = s
	return true

func tem_status(nome: String) -> bool:
	return status.has(nome)

func intensidade_do_status(nome: String) -> float:
	return float(status[nome]["intensidade"]) if status.has(nome) else 0.0

func imune_a(nome: String) -> bool:
	return float(_imunidade.get(nome, 0.0)) > 0.0

# ──────────────────────────────────────────────────────────────────────────────
# O tick (§24)
# ──────────────────────────────────────────────────────────────────────────────

## Um passo de tempo. A ordem aqui É a §24: **primeiro tudo que expira**, depois
## quem quiser aplicar aplica — por isso `passo()` não aplica nada, só remove.
##
## Devolve a lista de status que acabaram neste quadro, pra quem chamou avisar.
func passo(delta: float) -> Array[String]:
	for nome in _imunidade.keys():
		var t : float = float(_imunidade[nome]) - delta
		if t <= 0.0:
			_imunidade.erase(nome)
		else:
			_imunidade[nome] = t

	var vivas : Array[Dictionary] = []
	for l in linhas:
		l["restante"] = float(l["restante"]) - delta
		if float(l["restante"]) > 0.0:
			vivas.append(l)
	linhas = vivas

	var acabaram : Array[String] = []
	for nome in status.keys():
		var s : Dictionary = status[nome]
		s["restante"] = float(s["restante"]) - delta
		if float(s["restante"]) <= 0.0:
			acabaram.append(nome)
		else:
			status[nome] = s
	for nome in acabaram:
		status.erase(nome)
		# §18: a imunidade nasce no instante em que o status morre.
		_imunidade[nome] = IMUNIDADE_APOS_STATUS
	return acabaram

# ──────────────────────────────────────────────────────────────────────────────
# Cleanse / dispel (§21)
# ──────────────────────────────────────────────────────────────────────────────

## Remove tudo que é temporário de uma vez.
##
## §21/§49: efeito de **Held Item nunca sai**. Por isso a linha guarda `de_item`
## — sem essa marca, um cleanse limparia o item do próprio Pokémon, que é o
## oposto do que a especificação manda.
##
## `so_negativos` serve pro cleanse que tira só o ruim (limpar os próprios
## buffs junto seria punir quem usou a skill).
func limpar(so_negativos: bool = false) -> int:
	var antes := linhas.size() + status.size()
	var vivas : Array[Dictionary] = []
	for l in linhas:
		if bool(l["de_item"]):
			vivas.append(l)
		elif so_negativos and float(l["intensidade"]) > 0.0:
			vivas.append(l)
	linhas = vivas
	# Status é sempre ruim: sai inteiro. E NÃO gera imunidade — cleanse não é o
	# status acabando sozinho, e dar 1 s de imunidade de brinde transformaria
	# cleanse em escudo.
	status.clear()
	return antes - (linhas.size() + status.size())

# ──────────────────────────────────────────────────────────────────────────────
# Leitura
# ──────────────────────────────────────────────────────────────────────────────

## O que está ativo, pra HUD e pro recado de feedback.
func resumo() -> Array:
	var out : Array = []
	for l in linhas:
		out.append({
			"skill": str(l["skill"]), "atributo": str(l["atributo"]),
			"intensidade": float(l["intensidade"]),
			"restante": float(l["restante"]), "de_item": bool(l["de_item"]),
		})
	for nome in status.keys():
		out.append({
			"skill": str(nome), "atributo": "status",
			"intensidade": float(status[nome]["intensidade"]),
			"restante": float(status[nome]["restante"]), "de_item": false,
		})
	return out

func _achar(skill: String, atributo: String) -> int:
	for i in linhas.size():
		if str(linhas[i]["skill"]) == skill and str(linhas[i]["atributo"]) == atributo:
			return i
	return -1

## A última linha adicionada deste atributo — a que a §23 premia com duração.
func _ultima_linha(atributo: String) -> int:
	for i in range(linhas.size() - 1, -1, -1):
		if str(linhas[i]["atributo"]) == atributo:
			return i
	return -1
