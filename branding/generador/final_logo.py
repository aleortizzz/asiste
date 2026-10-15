"""Logo final de Asiste (idea 4: lista de invitados + ✓). Genera todas las versiones en SVG."""
import os, sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.varLib.instancer import instantiateVariableFont

HERE = os.path.dirname(os.path.abspath(__file__))

VIOLETA, HUESO, BLANCO, NEGRO = '#4E1F6E', '#F7F6F2', '#FFFFFF', '#070607'
SLOGAN = 'Tu fiesta empieza con un sí.'

anton = TTFont(os.path.join(HERE, 'fonts/Anton-Regular.ttf'))
dm = instantiateVariableFont(TTFont(os.path.join(HERE, 'fonts/DMSans.ttf')), {'wght': 500, 'opsz': 14})


def text_path(font, text, cap_px, tracking_em=0.0):
    upm, cap = font['head'].unitsPerEm, font['OS/2'].sCapHeight
    s = cap_px / cap
    cmap, gs, hmtx = font.getBestCmap(), font.getGlyphSet(), font['hmtx']
    pen = SVGPathPen(gs)
    x = 0
    for i, ch in enumerate(text):
        g = cmap[ord(ch)]
        gs[g].draw(TransformPen(pen, (s, 0, 0, -s, x, 0)))
        x += hmtx[g][0] * s + (tracking_em * upm * s if i < len(text) - 1 else 0)
    return pen.getCommands(), x


# ---------- Isotipo: lista de invitados + insignia de confirmado (grilla 100 x 100) ----------
def _ln(d, w):
    return f'<path d="{d}" fill="none" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>'


CARD = '<rect x="0" y="0" width="76" height="90" rx="12"/>'
BADGE = '<circle cx="78" cy="78" r="22"/>'
CUTS = (''.join(f'<circle cx="16" cy="{y}" r="5"/>' for y in (20, 39, 58))
        + _ln('M28,20 H60', 6) + _ln('M28,39 H60', 6) + _ln('M28,58 H44', 6)
        + '<circle cx="78" cy="78" r="27.5"/>')
CHECK = _ln('M67.5,78 L74.5,85 L88.5,71', 8.5)


def mark(color, x, y, s, uid):
    return (f'<defs><mask id="{uid}" maskUnits="userSpaceOnUse" x="-10" y="-10" width="120" height="120">'
            f'<rect x="-10" y="-10" width="120" height="120" fill="#fff"/>'
            f'<g fill="#000" stroke="#000">{CUTS}</g><circle cx="78" cy="78" r="22" fill="#fff"/>'
            f'<g fill="#000" stroke="#000">{CHECK}</g></mask></defs>'
            f'<g transform="translate({x:.2f} {y:.2f}) scale({s:.4f})">'
            f'<g fill="{color}" mask="url(#{uid})">{CARD}{BADGE}</g></g>')


def svg(w, h, body, bg=None):
    rect = f'<rect width="{w:.0f}" height="{h:.0f}" fill="{bg}"/>' if bg else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.0f} {h:.0f}" width="{w:.0f}" height="{h:.0f}" '
            f'role="img" aria-label="Asiste"><title>Asiste</title>{rect}{body}</svg>\n')


CAP = 100
WORD_D, WORD_W = text_path(anton, 'ASISTE', CAP, 0.035)
SLOG_CAP = 19
SLOG_D, SLOG_W = text_path(dm, SLOGAN, SLOG_CAP)
PAD, GAP = 30, 28


def horizontal(color, bg, uid, slogan=False):
    if slogan:
        block = CAP + 26 + SLOG_CAP + 6          # nombre + aire + slogan (con descendentes)
        s = CAP / 100                            # el ícono acompaña al nombre, no al bloque
    else:
        block = CAP
        s = CAP / 100
    ih = 100 * s
    h = max(ih, block) + 2 * PAD
    top_text = (h - block) / 2
    wx = PAD + ih + GAP
    body = mark(color, PAD, top_text, s, uid)
    body += f'<path transform="translate({wx:.2f} {top_text + CAP:.2f})" d="{WORD_D}" fill="{color}"/>'
    w = wx + WORD_W + PAD
    if slogan:
        sc = min(1, WORD_W / SLOG_W)
        body += (f'<path transform="translate({wx:.2f} {top_text + CAP + 26 + SLOG_CAP:.2f}) scale({sc:.4f})" '
                 f'd="{SLOG_D}" fill="{color}"/>')
    return svg(w, h, body, bg)


def vertical(color, bg, uid):
    s = 1.55
    ih = 100 * s
    sl = 1.2
    w = max(WORD_W, SLOG_W * sl, ih) + 2 * PAD + 20
    body = mark(color, (w - ih) / 2, PAD, s, uid)
    wy = PAD + ih + 36 + CAP
    body += f'<path transform="translate({(w - WORD_W) / 2:.2f} {wy:.2f})" d="{WORD_D}" fill="{color}"/>'
    sy = wy + 30 + SLOG_CAP * sl
    body += (f'<path transform="translate({(w - SLOG_W * sl) / 2:.2f} {sy:.2f}) scale({sl})" '
             f'd="{SLOG_D}" fill="{color}"/>')
    return svg(w, sy + PAD + 8, body, bg)


def isotipo(color, bg, uid):
    s = 3.2
    return svg(100 * s + 2 * PAD, 100 * s + 2 * PAD, mark(color, PAD, PAD, s, uid), bg)


def app_icon(tile, fg, uid, size=1024):
    s = size * 0.6 / 100
    off = (size - 100 * s) / 2
    return svg(size, size, f'<rect width="{size}" height="{size}" rx="{size * 0.225:.0f}" fill="{tile}"/>'
               + mark(fg, off, off, s, uid))


def app_icon_full(tile, fg, uid, size=1024):
    """Cuadrado sin redondear: Android e iOS recortan la forma solos."""
    s = size * 0.6 / 100
    off = (size - 100 * s) / 2
    return svg(size, size, f'<rect width="{size}" height="{size}" fill="{tile}"/>' + mark(fg, off, off, s, uid))


def main(out):
    os.makedirs(out, exist_ok=True)
    VERSIONES = {
        'violeta': (VIOLETA, None),
        'violeta-sobre-hueso': (VIOLETA, HUESO),
        'blanco': (BLANCO, None),
        'blanco-sobre-violeta': (BLANCO, VIOLETA),
        'negro': (NEGRO, None),
    }
    files = {}
    for name, (c, bg) in VERSIONES.items():
        files[f'asiste-horizontal-{name}.svg'] = horizontal(c, bg, f'h-{name}')
        files[f'asiste-horizontal-slogan-{name}.svg'] = horizontal(c, bg, f'hs-{name}', slogan=True)
        files[f'asiste-vertical-{name}.svg'] = vertical(c, bg, f'v-{name}')
        files[f'asiste-isotipo-{name}.svg'] = isotipo(c, bg, f'i-{name}')
    files['asiste-app-icon.svg'] = app_icon(VIOLETA, BLANCO, 'app')
    files['asiste-app-icon-claro.svg'] = app_icon(HUESO, VIOLETA, 'appc')
    files['asiste-app-icon-cuadrado.svg'] = app_icon_full(VIOLETA, BLANCO, 'appq')
    files['favicon.svg'] = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><title>Asiste</title>'
                            f'{mark(VIOLETA, 0, 0, 1, "fav")}</svg>\n')

    for n, c in files.items():
        open(os.path.join(out, n), 'w', encoding='utf-8').write(c)
    print(len(files), 'archivos')


if __name__ == '__main__':
    main(sys.argv[1])
