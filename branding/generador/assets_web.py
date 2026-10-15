"""Archivos del logo que usa la web (public/): imagen para compartir y logo para los mails."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from final_logo import (mark, svg, text_path, anton, dm, WORD_D, WORD_W, SLOG_D, SLOG_W, CAP, SLOG_CAP,
                        VIOLETA, BLANCO, main)

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)

# Imagen al compartir el link (1200 x 630): logo blanco con el slogan, centrado sobre violeta.
W, H = 1200, 630
s = 1.75
ih = 100 * s
gap = 52
sl = 1.55
block_w = ih + gap + WORD_W * 1.3
x0 = (W - block_w) / 2
top = (H - ih) / 2 - 20
body = f'<rect width="{W}" height="{H}" fill="{VIOLETA}"/>' + mark(BLANCO, x0, top, s, 'og')
wx = x0 + ih + gap
body += f'<path transform="translate({wx:.2f} {top + 20 + CAP * 1.3:.2f}) scale(1.3)" d="{WORD_D}" fill="{BLANCO}"/>'
sw = SLOG_W * sl
body += (f'<path transform="translate({(W - sw) / 2:.2f} {top + ih + 70:.2f}) scale({sl})" '
         f'd="{SLOG_D}" fill="{BLANCO}" fill-opacity="0.85"/>')
open(os.path.join(OUT, 'og-asiste.svg'), 'w', encoding='utf-8').write(svg(W, H, body))
print('ok')
