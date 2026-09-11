## StatsDePokemon.gd — A ÚNICA fórmula de stat e HP do jogo.
##
## 🔴 Por que este arquivo existe (achado da auditoria de 11/09/2026):
## o projeto tinha TRÊS fórmulas diferentes para a mesma coisa —
##
##   `DamageCalculator.calculate_stat`  base + floor(base × nível/60)
##   `SaveManager._calc_stat`           Gen 3 com IV
##   `BattlePokemon._calc_stat`         Gen 3 com IV + EV + nature
##
## — e elas discordavam. Pikachu Lv20 tinha **72 de vida** no combate real e
## **47** no menu do time. O HP que o jogador via não era o HP com que ele
## lutava. Era isso que o Gabriel descreveu como "as estatísticas não têm
## impacto consistente".
##
## Agora as três chamam AQUI. Um número, um lugar.
##
## É classe pura (`RefCounted`, sem autoload) de propósito: autoload não é
## identificador em teste headless, e a fórmula que decide todo o combate
## precisa ser justamente a mais testável do projeto.
class_name StatsDePokemon
extends RefCounted

## As chaves internas de stat. "hp" nunca é afetado por nature (regra da série).
const CHAVES : Array[String] = ["hp", "atk", "def", "spa", "spd", "spe"]

## Como cada chave interna se chama dentro de `species.json`.
const CHAVE_NA_ESPECIE : Dictionary = {
	"hp": "hp", "atk": "attack", "def": "defense",
	"spa": "sp_atk", "spd": "sp_def", "spe": "speed",
}

## As 25 natures. Cada uma sobe 10% de uma stat e desce 10% de outra; as 5 em
## que sobe e desce a MESMA stat são as neutras (Hardy, Docile, Serious,
## Bashful, Quirky), sem efeito líquido.
##
## Mora aqui, e não em `GameData`, pelo mesmo motivo da fórmula: `GameData` é
## autoload. `GameData.get_nature_multiplier()` continua existindo e passou a
## delegar pra cá, então nada que já chamava por lá precisou mudar.
const NATURES : Dictionary = {
	"hardy":   {"boost": "atk", "cut": "atk"},
	"lonely":  {"boost": "atk", "cut": "def"},
	"brave":   {"boost": "atk", "cut": "spe"},
	"adamant": {"boost": "atk", "cut": "spa"},
	"naughty": {"boost": "atk", "cut": "spd"},
	"bold":    {"boost": "def", "cut": "atk"},
	"docile":  {"boost": "def", "cut": "def"},
	"relaxed": {"boost": "def", "cut": "spe"},
	"impish":  {"boost": "def", "cut": "spa"},
	"lax":     {"boost": "def", "cut": "spd"},
	"timid":   {"boost": "spe", "cut": "atk"},
	"hasty":   {"boost": "spe", "cut": "def"},
	"serious": {"boost": "spe", "cut": "spe"},
	"jolly":   {"boost": "spe", "cut": "spa"},
	"naive":   {"boost": "spe", "cut": "spd"},
	"modest":  {"boost": "spa", "cut": "atk"},
	"mild":    {"boost": "spa", "cut": "def"},
	"quiet":   {"boost": "spa", "cut": "spe"},
	"bashful": {"boost": "spa", "cut": "spa"},
	"rash":    {"boost": "spa", "cut": "spd"},
	"calm":    {"boost": "spd", "cut": "atk"},
	"gentle":  {"boost": "spd", "cut": "def"},
	"sassy":   {"boost": "spd", "cut": "spe"},
	"careful": {"boost": "spd", "cut": "spa"},
	"quirky":  {"boost": "spd", "cut": "spd"},
}

# ──────────────────────────────────────────────────────────────────────────────
# As duas fórmulas
# ──────────────────────────────────────────────────────────────────────────────

## HP máximo (fórmula Gen 3, a mesma que o save já usava).
##
##   HP = floor((2×base + IV + floor(EV/4)) × nível / 100 × HP_SCALE) + nível + 10
##
## O `+ nível + 10` é o que garante que nenhum Pokémon tenha vida ridícula no
## começo. O `HP_SCALE` (2.5) é o que dá tempo de reagir num combate de tempo
## real — sem ele, a fórmula pura da série entrega lutas de 4 golpes, que é
## ritmo de turno, não de MMO.
static func hp_maximo(base: int, nivel: int, iv: int = 31, ev: int = 0) -> int:
	var n := clampi(nivel, 1, CombatBalance.NIVEL_MAXIMO)
	var cru : float = (2.0 * base + iv + floor(ev / 4.0)) * n / 100.0 * CombatBalance.HP_SCALE
	return int(floor(cru)) + n + 10

## Qualquer outra stat (atk/def/spa/spd/spe).
##
##   stat = (floor((2×base + IV + floor(EV/4)) × nível / 100) + 5) × nature
##
## `chave` é "atk"/"def"/"spa"/"spd"/"spe" — serve só pra saber se a nature
## sobe ou desce ESTA stat. Passar "" desliga a nature.
static func stat(base: int, nivel: int, chave: String = "", nature: String = "",
		iv: int = 31, ev: int = 0) -> int:
	var n := clampi(nivel, 1, CombatBalance.NIVEL_MAXIMO)
	var cru := int(floor((2.0 * base + iv + floor(ev / 4.0)) * n / 100.0)) + 5
	return maxi(1, int(floor(cru * multiplicador_de_nature(nature, chave))))

## 1.10 se a nature sobe esta stat, 0.90 se desce, 1.00 nos outros casos
## (nature neutra, nature desconhecida, chave vazia ou "hp").
static func multiplicador_de_nature(nature: String, chave: String) -> float:
	if nature.is_empty() or chave.is_empty() or chave == "hp":
		return 1.0
	var entrada : Dictionary = NATURES.get(nature.to_lower(), {})
	if entrada.is_empty() or entrada["boost"] == entrada["cut"]:
		return 1.0
	if entrada["boost"] == chave:
		return CombatBalance.NATURE_BOOST
	if entrada["cut"] == chave:
		return CombatBalance.NATURE_CUT
	return 1.0

# ──────────────────────────────────────────────────────────────────────────────
# Conveniência: o conjunto inteiro de uma vez
# ──────────────────────────────────────────────────────────────────────────────

## Os 6 stats de um Pokémon, prontos pra usar.
##
## `base_stats` é o bloco `base_stats` de `species.json` (chaves hp/attack/
## defense/sp_atk/sp_def/speed). `ivs`/`evs` usam as chaves INTERNAS
## (hp/atk/def/spa/spd/spe) — é o formato que o save já grava.
##
## Devolve: {"hp": int, "atk": int, "def": int, "spa": int, "spd": int, "spe": int}
static func conjunto(base_stats: Dictionary, nivel: int, nature: String = "",
		ivs: Dictionary = {}, evs: Dictionary = {}) -> Dictionary:
	var saida : Dictionary = {}
	for chave in CHAVES:
		var base : int = int(base_stats.get(CHAVE_NA_ESPECIE[chave], 45))
		var iv : int = int(ivs.get(chave, CombatBalance.IV_MAX))
		var ev : int = int(evs.get(chave, 0))
		if chave == "hp":
			saida[chave] = hp_maximo(base, nivel, iv, ev)
		else:
			saida[chave] = stat(base, nivel, chave, nature, iv, ev)
	return saida

## Sorteia um conjunto de IVs (0-31 em cada stat), o "talento natural" que
## nasce com o bicho e nunca muda.
static func sortear_ivs() -> Dictionary:
	var ivs : Dictionary = {}
	for chave in CHAVES:
		ivs[chave] = RNGManager.randi_range(CombatBalance.IV_MIN, CombatBalance.IV_MAX)
	return ivs

# ──────────────────────────────────────────────────────────────────────────────
# Migração do save (11/09)
# ──────────────────────────────────────────────────────────────────────────────

## Converte o HP atual gravado quando o HP MÁXIMO muda de fórmula.
##
## Existe porque unificar as três fórmulas muda o HP máximo de todo Pokémon já
## salvo. Zerar a vida de quem estava machucado, ou curar todo mundo de graça,
## seriam os dois errados — então o que se preserva é a FRAÇÃO: quem estava com
## metade da vida continua com metade da vida.
##
## Um Pokémon desmaiado (hp 0) continua desmaiado; um com vida cheia continua
## cheio (sem depender de arredondamento).
static func migrar_hp(hp_atual: int, max_antigo: int, max_novo: int) -> int:
	if max_antigo <= 0:
		return max_novo
	if hp_atual <= 0:
		return 0
	if hp_atual >= max_antigo:
		return max_novo
	var fracao := float(hp_atual) / float(max_antigo)
	return clampi(int(round(fracao * max_novo)), 1, max_novo)
