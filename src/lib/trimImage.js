// Recorta el borde vacío de un logo antes de subirlo.
//
// Muchos logos vienen con mucho espacio alrededor del dibujo (ej. una imagen
// de 4000×2250 con el logo chiquito en el medio). En la invitación los logos
// se muestran con una altura fija, así que ese espacio los hace ver mucho más
// chicos que los demás. Acá se busca el rectángulo donde está el dibujo y se
// recorta, dejando un margen mínimo.
//
// «Vacío» es transparente o, si la imagen no tiene transparencia, blanco casi
// puro. Si no se encuentra borde vacío (o algo falla), se devuelve el archivo
// original sin tocar: nunca se pierde el logo.

const MAX_SIDE = 1600 // más grande no hace falta para un logo, y pesa menos
const ALPHA_MIN = 12 // por debajo de esto, el píxel cuenta como transparente
const WHITE_MIN = 245 // los tres canales por encima de esto: blanco «de fondo»

export async function trimImage(file) {
  try {
    const bitmap = await createImageBitmap(file)
    const { width: w, height: h } = bitmap
    const canvas = document.createElement('canvas')
    canvas.width = w
    canvas.height = h
    const ctx = canvas.getContext('2d', { willReadFrequently: true })
    ctx.drawImage(bitmap, 0, 0)
    const { data } = ctx.getImageData(0, 0, w, h)

    // ¿De qué es el fondo? Se mira en las cuatro esquinas.
    const px = (x, y) => (y * w + x) * 4
    const corners = [px(0, 0), px(w - 1, 0), px(0, h - 1), px(w - 1, h - 1)]
    const transparentBg = corners.some((i) => data[i + 3] < ALPHA_MIN)
    const whiteBg =
      !transparentBg && corners.every((i) => data[i] > WHITE_MIN && data[i + 1] > WHITE_MIN && data[i + 2] > WHITE_MIN)
    if (!transparentBg && !whiteBg) return file

    const isEmpty = transparentBg
      ? (i) => data[i + 3] < ALPHA_MIN
      : (i) => data[i] > WHITE_MIN && data[i + 1] > WHITE_MIN && data[i + 2] > WHITE_MIN

    let top = h
    let left = w
    let right = -1
    let bottom = -1
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        if (isEmpty(px(x, y))) continue
        if (x < left) left = x
        if (x > right) right = x
        if (y < top) top = y
        if (y > bottom) bottom = y
      }
    }
    if (right < 0) return file // imagen vacía: mejor no tocarla

    // Margen chico (2% del lado mayor del dibujo) para que no quede pegado.
    const pad = Math.round(Math.max(right - left, bottom - top) * 0.02)
    left = Math.max(0, left - pad)
    top = Math.max(0, top - pad)
    right = Math.min(w - 1, right + pad)
    bottom = Math.min(h - 1, bottom + pad)
    const cw = right - left + 1
    const ch = bottom - top + 1

    // Si casi no había borde y la imagen no es enorme, se deja la original.
    const scale = Math.min(1, MAX_SIDE / Math.max(cw, ch))
    if (cw * ch > w * h * 0.95 && scale === 1) return file

    const out = document.createElement('canvas')
    out.width = Math.round(cw * scale)
    out.height = Math.round(ch * scale)
    out.getContext('2d').drawImage(canvas, left, top, cw, ch, 0, 0, out.width, out.height)

    // PNG para conservar la transparencia.
    const blob = await new Promise((resolve) => out.toBlob(resolve, 'image/png'))
    if (!blob) return file
    const name = file.name.replace(/\.[^.]+$/, '') + '.png'
    return new File([blob], name, { type: 'image/png' })
  } catch {
    return file
  }
}
