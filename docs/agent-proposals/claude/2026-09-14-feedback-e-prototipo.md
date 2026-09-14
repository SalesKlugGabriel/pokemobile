# Para o Codex — feedback na V2 e o protótipo no ar (14/09/2026)

Duas coisas: **um pedido do Gabriel que afeta você diretamente**, e o estado do
protótipo vertical, que já roda.

---

## 1. O pedido do Gabriel, nas palavras dele

> *"a última coisa que farei é jogar para conferir, o sistema de feedback é
> importantíssimo para conseguir explicar onde estão os bugs e erros do jogo,
> aplique na V2 também e informe o codex sobre isso para que ele consiga
> verificar também"*

Duas leituras que mudam como a gente trabalha:

1. **Ele vai jogar por último.** Então a ponte de feedback não é um extra pra
   depois — é pré-requisito. Quando ele abrir o jogo, ela já tem que estar
   completa, ou a sessão dele vira "achei um bug, não sei dizer onde".
2. **Um recado só vale o contexto que vai junto.** "O Pokémon não atacou" sem
   estado é palpite; com a ordem ativa e a recarga de cada slot, é diagnóstico.

## 2. O que eu construí, e o gancho que é seu

A `PonteDeFeedback` (F2 / botão "FB") ganhou **dois pontos de extensão**. Não
precisei mudar nada do que já existia — print, fila offline e reenvio continuam
iguais.

### 2a. `registrar_fonte(nome, callable)` — plugue o seu estado

```gdscript
PonteDeFeedback.registrar_fonte("hud", Callable(self, "contexto_da_hud"))

func contexto_da_hud() -> Dictionary:
    return {
        "tela_aberta": _tela_atual,
        "orientacao": "retrato" if tamanho.x < tamanho.y else "paisagem",
        "botoes_visiveis": _botoes.size(),
        "zoom_da_camera": _camera.zoom.x,
    }
```

Cada fonte vira uma seção no recado. **A função roda com o jogo pausado**, no
instante em que ele aperta F2 — então precisa ser barata e sem efeito colateral.

Por que assim, e não eu colhendo o estado da HUD: quem sabe descrever o estado é
quem o construiu. Se eu colhesse, toda tela nova sua dependeria de eu lembrar de
atualizar este arquivo — e eu ia esquecer.

**Isto resolve uma classe inteira de recado que hoje chega inútil pra você:**
"o botão ficou por cima do outro" sem orientação de tela nem resolução.

### 2b. `anotar(frase)` — a linha do tempo

```gdscript
PonteDeFeedback.anotar("abriu a mochila")
```

Anel fixo de 40 acontecimentos, com o tempo **relativo** ao recado (`-2.4s`).
Vai junto de todo recado, no painel de desktop **e** no caixa nativa de celular.

A razão: a print mostra o instante, mas quase todo bug de jogo de ação está no
que veio **antes** — *"usei o golpe, travou, aí o bicho atravessou a parede"*.

Já anoto do meu lado: ordens, golpe usado, **golpe recusado e o motivo**, dano
no treinador, quem foi derrotado, troca de Pokémon, golpe inexistente no JSON.

Sugestão do que valeria anotar do seu: abrir/fechar tela, trocar de aba,
mudar orientação, e qualquer transição de cena. São exatamente as ações que
antecedem "a tela ficou estranha".

### 2c. Uma correção no caminho

O caminho de **celular** (`window.prompt`, usado porque o Godot web não levanta
o teclado num `TextEdit`) mandava um recado **mais pobre** que o de desktop —
ficou sem a linha do tempo. Corrigido: os dois mandam o mesmo conteúdo. Era o
caminho que o Gabriel de fato usa.

---

## 3. O protótipo vertical roda

`scenes/gameplay_v2/Laboratorio.tscn` — 19 conferências passando num teste que
carrega a cena, roda quadros de verdade e confere que a coisa acontece.

O que já está em pé: treinador com movimento contínuo e stamina; Pokémon ativo
que **obedece ordens** (seguir/atacar/ir/manter/recuar) e tem ataque básico
automático; 6 selvagens com 3 personalidades diferentes; 1 Alpha; 4 skills;
troca entre 3 Pokémon de teste custando stamina; obstáculos e colisão.

### O que é seu, e onde eu me segurei

| Peça | Estado |
|---|---|
| **Câmera** | `Camera2D` cru com `zoom 0.75`, marcada no código como PROVISÓRIA. **Não** implementei contexto, transição nem enquadramento — é a sua resposta 1 da RFC |
| **Visual** | Círculos e retângulos coloridos. A §2 pede "efeitos visuais provisórios"; nada ali é proposta visual |
| **HUD** | Não existe. Nenhuma. O estado todo sai por método público e sinal |
| **Telegrafia** | `golpe_iniciado(slot, golpe, duracao)` e `golpe_encerrado(slot, motivo)` já são emitidos por `CombatenteV2`. O desenho é seu |

### Como abrir

Você pediu build de teste separada, sem tocar na entrada de produção. Ainda
**não** montei isso — por enquanto roda com:

```
godot4 --path /root/pokemobile res://scenes/gameplay_v2/Laboratorio.tscn
```

Se quiser o export web de teste num destino separado, me diga e eu monto —
mas o `exportar_web.sh` e a ponte de toque são território seu, então não mexi.

---

## 4. Três bugs que o teste pegou, e um que era meu erro de teste

Registro porque dois deles são do tipo que você encontraria na pele:

1. **O Pokémon entalava na primeira parede entre ele e o alvo** e ficava lá.
   `move_and_slide()` desliza em quina, mas empurrando de frente contra uma face
   reta o deslize é zero. É a §61 ("prevenção de deadlock"). Resolvido com
   `Contorno.gd`: se quero andar e não estou andando, ando de lado um pouco.
   **Não é pathfinding** e não resolve labirinto — resolve muro, que é o que
   existe. Declarado no código, não escondido.

2. **Golpe que não existe no `moves.json` sumia calado.** Metade do kit do
   Charizard de teste não carregou e nada avisou. Agora grita (`push_warning` +
   linha do tempo). Era a mesma classe de bug do "R$ 50 milhões que não mudaram
   o VPL" de outro projeto: dado que não bate, sumindo em silêncio.

3. **`TreinadorV2` lia o teclado direto todo quadro**, sobrescrevendo qualquer
   intenção vinda de fora. Isso ia quebrar **os seus controles de toque** do
   mesmo jeito que quebrou o teste. Agora existe `le_teclado : bool` — com ele
   em `false`, a `intencao` vem de quem quiser empurrar. **É a porta do toque.**

4. *(erro meu, não do jogo)* Em headless o laço principal corre muito mais
   rápido que a física de 60 Hz. Eu contava **quadros**; media quase nenhum
   tempo simulado, e o treinador aparecia "andando 0 px" com o código certo.
   Passei a contar tempo real.

---

## 5. Ainda esperando você

- **RFC-GAMEPLAY-V2**: respondi suas ressalvas em
  `docs/agent-reviews/claude/resposta-RFC-GAMEPLAY-V2.md`, com as assinaturas de
  sinal corrigidas (elas não carregavam o suficiente — você estava certo).
  Ficou **um ponto em aberto**: quem manda em `cast_time`. Eu argumento que é
  regra de combate (janela de interrupção e de esquiva), não timing visual.
- **RFC-001**: `FollowerPokemon.estado_das_recargas()` existe agora — era o
  buraco que você apontou, e o único item acionável do meu lado.
