#!/usr/bin/env bash
# exportar_web.sh — Exporta o jogo pra web E injeta a ponte de toque (09/09).
#
# 🔴 Por que este script existe, e por que o export não pode mais ser feito
# direto pelo godot4:
#
# O Gabriel não conseguia jogar no celular. Medi num iPhone 13 emulado,
# espionando os eventos que chegam ao <canvas>:
#
#   toque  -> pointerdown, touchstart, touchend        (e o jogo NÃO reage)
#   mouse  -> pointerdown, mousedown, mouseup, click   (e o jogo reage)
#
# Ou seja: o toque CHEGA no canvas, mas a camada web do Godot 4.2 não o
# transforma em input de jogo — nem como toque, nem como mouse emulado. Não é
# mira, não é foco, não é a tarja preta: é o motor não escutando.
#
# A ponte abaixo resolve isso onde o problema está: no navegador. Cada toque
# vira o evento de mouse equivalente, no mesmo ponto — e mouse, está provado,
# funciona. É pequena, não depende de versão do Godot, e some sozinha no dia
# em que o motor passar a escutar toque (aí seria só apagar este bloco).
#
# Roda com:  ./tools/exportar_web.sh
set -e
cd "$(dirname "$0")/.."

godot4 --headless --export-release "Web" builds/web/index.html

PONTE='<script>
/* Ponte de toque (tools/exportar_web.sh) — o Godot 4.2 web não transforma
   toque em input; o mouse ele escuta. Então todo toque vira mouse. */
(function () {
  function ligar() {
    var c = document.getElementById("canvas") || document.querySelector("canvas");
    if (!c) { return setTimeout(ligar, 200); }
    if (c.__ponteDeToque) { return; }
    c.__ponteDeToque = true;
    /* Dispara PointerEvent (pointerType "mouse") E MouseEvent. Medido no
       navegador: o clique real gera pointerdown+mousedown e o jogo reage; o
       toque gera pointerdown com pointerType "touch" e o jogo NÃO reage. Ou
       seja, o motor escuta pointer e ignora o que vem de dedo. A ponte mente
       pra ele: diz que veio de mouse. */
    function envia(tipoPtr, tipoMouse, t, botoes) {
      var comum = {
        bubbles: true, cancelable: true, view: window,
        clientX: t.clientX, clientY: t.clientY, screenX: t.screenX, screenY: t.screenY,
        button: 0, buttons: botoes
      };
      if (tipoPtr && window.PointerEvent) {
        var p = {}; for (var k in comum) { p[k] = comum[k]; }
        p.pointerId = 1; p.pointerType = "mouse"; p.isPrimary = true;
        c.dispatchEvent(new PointerEvent(tipoPtr, p));
        window.dispatchEvent(new PointerEvent(tipoPtr, p));
      }
      c.dispatchEvent(new MouseEvent(tipoMouse, comum));
      /* Também na janela: não está claro onde o motor pendura o listener, e
         disparar nos dois lugares custa nada. */
      window.dispatchEvent(new MouseEvent(tipoMouse, comum));
    }
    c.addEventListener("touchstart", function (e) {
      var t = e.changedTouches[0]; envia("pointerdown", "mousedown", t, 1); e.preventDefault();
    }, { passive: false });
    c.addEventListener("touchmove", function (e) {
      var t = e.changedTouches[0]; envia("pointermove", "mousemove", t, 1); e.preventDefault();
    }, { passive: false });
    c.addEventListener("touchend", function (e) {
      var t = e.changedTouches[0]; envia("pointerup", "mouseup", t, 0); envia(null, "click", t, 0); e.preventDefault();
    }, { passive: false });
  }
  ligar();
})();
</script>'

if grep -q "__ponteDeToque" builds/web/index.html; then
  echo "ponte de toque: já estava no HTML"
else
  python3 - "$PONTE" <<'PY'
import io, sys
ponte = sys.argv[1]
p = "builds/web/index.html"
t = io.open(p, encoding="utf-8").read()
assert "</body>" in t, "index.html sem </body> — o modelo do export mudou"
io.open(p, "w", encoding="utf-8").write(t.replace("</body>", ponte + "\n</body>", 1))
print("ponte de toque injetada no index.html")
PY
fi
