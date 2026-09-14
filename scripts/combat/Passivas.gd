## Passivas.gd — O catálogo das habilidades da Pokédex.
##
## Pedido do Gabriel: *"as passivas conforme a pokedex informa, a ultimate
## somente na última evolução"*.
##
## ── O que mudou no dado ──────────────────────────────────────────────────────
##
## Antes: **19 das 151 espécies** tinham habilidade preenchida; 132 estavam com
## texto vazio, e o campo já era lido em cinco lugares do código (dano, Pokédex,
## batalha). Ou seja, 87% dos Pokémon passavam por um sistema que não tinha o
## que ler — e ninguém via, porque string vazia não dá erro.
##
## Agora: **151 de 151**, com a habilidade que a Pokédex informa, 47 distintas.
##
## ⚠️ **Rattata é exceção declarada.** Ele já estava com `Guts`, que também é
## habilidade legítima dele (a segunda). Trocar por `Run Away` (a primeira)
## deixaria o Rattata mais fraco sem nenhum motivo de jogo, então ficou `Guts`.
##
## ── A regra que este arquivo existe pra cumprir ──────────────────────────────
##
## Padrão de construção nº 7: *"todo número mostrado numa tela tem fonte de
## verdade única e declarada, com o nível de confiança. Nunca transformo palpite
## em fato calado."*
##
## Aplicado aqui: cada habilidade declara se **tem efeito de verdade** ou se
## está só catalogada. Uma passiva catalogada que não faz nada, sem dizer que
## não faz nada, é a mesma armadilha do golpe que sumia calado do kit — o
## jogador acha que tem uma vantagem e não tem.
class_name Passivas
extends RefCounted

## Habilidades com efeito REAL no combate hoje. A lista é curta de propósito:
## vale mais quatro que funcionam do que 47 que o jogador acha que funcionam.
## Implementadas em `DamageCalculator.ability_damage_multiplier()`.
const COM_EFEITO : Array[String] = ["Overgrow", "Blaze", "Torrent", "Guts"]

## O que cada uma faz, em português. Serve pra Pokédex e pro recado de feedback.
##
## Texto de quem ainda não tem efeito descreve **a intenção**, não uma promessa:
## quem lê precisa saber que é catálogo, e `tem_efeito()` é quem responde isso.
const DESCRICAO : Dictionary = {
	"Overgrow": "Golpes de Planta ficam mais fortes quando a vida está baixa.",
	"Blaze": "Golpes de Fogo ficam mais fortes quando a vida está baixa.",
	"Torrent": "Golpes de Água ficam mais fortes quando a vida está baixa.",
	"Guts": "Ataque aumenta quando está com um status negativo.",
	"Intimidate": "Reduz o ataque de quem chega perto.",
	"Static": "Quem encosta pode ficar paralisado.",
	"Flame Body": "Quem encosta pode se queimar.",
	"Poison Point": "Quem encosta pode ser envenenado.",
	"Effect Spore": "Quem encosta pode dormir, se envenenar ou paralisar.",
	"Levitate": "Imune a golpes de Terra.",
	"Water Absorb": "Golpes de Água curam em vez de ferir.",
	"Volt Absorb": "Golpes elétricos curam em vez de ferir.",
	"Flash Fire": "Golpes de Fogo não ferem e deixam o próprio Fogo mais forte.",
	"Lightning Rod": "Puxa os golpes elétricos da área para si.",
	"Rock Head": "Não sofre o dano de recuo dos próprios golpes.",
	"Shield Dust": "Não sofre os efeitos secundários dos golpes.",
	"Shed Skin": "Pode se curar sozinho de um status negativo.",
	"Natural Cure": "Cura os status negativos ao ser recolhido.",
	"Immunity": "Não pode ser envenenado.",
	"Insomnia": "Não pode dormir.",
	"Vital Spirit": "Não pode dormir.",
	"Inner Focus": "Não recua com o susto.",
	"Own Tempo": "Não fica confuso.",
	"Oblivious": "Ignora provocação e encanto.",
	"Limber": "Não pode ser paralisado.",
	"Clear Body": "Ninguém consegue reduzir seus atributos.",
	"Hyper Cutter": "Ninguém consegue reduzir seu ataque.",
	"Keen Eye": "Ninguém consegue reduzir sua precisão.",
	"Compound Eyes": "Aumenta a própria precisão.",
	"Swift Swim": "Fica muito mais rápido na chuva.",
	"Chlorophyll": "Fica muito mais rápido no sol.",
	"Sand Veil": "Mais difícil de acertar na tempestade de areia.",
	"Swarm": "Golpes de Inseto ficam mais fortes quando a vida está baixa.",
	"Thick Fat": "Sofre menos de Fogo e Gelo.",
	"Magnet Pull": "Prende Pokémon do tipo Aço por perto.",
	"Soundproof": "Imune a golpes de som.",
	"Shell Armor": "Não pode receber golpe crítico.",
	"Cute Charm": "Quem encosta pode ficar encantado.",
	"Damp": "Impede autodestruição na área.",
	"Stench": "Pode fazer o alvo recuar.",
	"Pickup": "Às vezes acha um item depois da luta.",
	"Run Away": "Sempre consegue fugir de um selvagem.",
	"Early Bird": "Acorda do sono na metade do tempo.",
	"Synchronize": "Passa o próprio status negativo para quem o causou.",
	"Trace": "Copia a habilidade do adversário.",
	"Illuminate": "Aumenta a chance de encontrar Pokémon.",
	"Pressure": "Faz o adversário gastar mais para agir.",
}

## Esta habilidade muda alguma coisa no jogo hoje?
static func tem_efeito(habilidade: String) -> bool:
	return habilidade in COM_EFEITO

static func descrever(habilidade: String) -> String:
	if habilidade.strip_edges() == "":
		return "Sem habilidade."
	return str(DESCRICAO.get(habilidade, "Habilidade ainda não catalogada."))

## O texto que a tela mostra, **já com o aviso de confiança embutido**.
##
## É aqui que a regra 7 vira comportamento em vez de comentário: a Pokédex não
## precisa lembrar de avisar, porque o aviso vem junto do texto.
static func texto_para_tela(habilidade: String) -> String:
	if habilidade.strip_edges() == "":
		return "Sem habilidade."
	var d := descrever(habilidade)
	if tem_efeito(habilidade):
		return d
	return "%s  (catalogada — ainda sem efeito no jogo)" % d

## Quantas das habilidades catalogadas já funcionam. Serve pro teste travar o
## número: se alguém implementar mais uma e esquecer de tirar o aviso da tela,
## o teste reprova.
static func total_com_efeito() -> int:
	return COM_EFEITO.size()
