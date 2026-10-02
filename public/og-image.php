<?php
// Foto de la vista previa: la portada del evento recortada a 1200×630 (la
// proporción que usa WhatsApp para la imagen grande) y comprimida en JPG.
// Las fotos originales pueden pesar varios MB y WhatsApp directamente no
// muestra imágenes pesadas.
//
// Solo acepta un slug o un id de evento, nunca una URL: busca la foto en
// Supabase, así este archivo no sirve para achicar imágenes de cualquier sitio.
// El resultado queda guardado en og-cache/ y se reusa mientras la foto no cambie.

require __DIR__ . '/og-lib.php';

$type = $_GET['t'] ?? '';
$key = $type === 'i' ? ($_GET['s'] ?? '') : ($_GET['e'] ?? '');
$data = og_fetch($type, $key);

// Plantilla Ejecutiva con logo: en vez de una foto, la tarjeta de la invitación.
if (($_GET['k'] ?? '') === 'logo') {
  og_logo_card($data);
  exit;
}

$src = $data['image'] ?? '';

// Solo fotos del storage de nuestro proyecto de Supabase.
if (!$src || !og_config_ok() || strpos($src, rtrim(OG_SUPABASE_URL, '/') . '/storage/') !== 0) {
  http_response_code(404);
  exit;
}

function serve_file($file) {
  header('Content-Type: image/jpeg');
  header('Content-Length: ' . filesize($file));
  header('Cache-Control: public, max-age=604800');
  readfile($file);
  exit;
}

$dir = __DIR__ . '/og-cache';
$cached = $dir . '/' . sha1($src) . '.jpg';
if (is_file($cached)) serve_file($cached);

// Sin la librería de imágenes GD no podemos achicarla: mandamos la original.
if (!function_exists('imagecreatefromstring') || !function_exists('curl_init')) {
  header('Location: ' . $src, true, 302);
  exit;
}

$ch = curl_init($src);
curl_setopt_array($ch, [
  CURLOPT_RETURNTRANSFER => true,
  CURLOPT_FOLLOWLOCATION => true,
  CURLOPT_CONNECTTIMEOUT => 4,
  CURLOPT_TIMEOUT => 12,
  CURLOPT_MAXFILESIZE => 20 * 1024 * 1024,
]);
$bytes = curl_exec($ch);
curl_close($ch);
$img = $bytes ? @imagecreatefromstring($bytes) : false;
if (!$img) {
  header('Location: ' . $src, true, 302);
  exit;
}

// Recorte tipo "cover" a 1200×630, un poco hacia arriba (suelen estar las caras).
$W = 1200;
$H = 630;
$sw = imagesx($img);
$sh = imagesy($img);
$scale = max($W / $sw, $H / $sh);
$cw = (int) round($W / $scale);
$ch2 = (int) round($H / $scale);
$cx = (int) round(($sw - $cw) / 2);
$cy = (int) round(($sh - $ch2) * 0.3);

$out = imagecreatetruecolor($W, $H);
imagecopyresampled($out, $img, 0, 0, $cx, $cy, $W, $H, $cw, $ch2);
imageinterlace($out, true);

if (!is_dir($dir)) @mkdir($dir, 0755, true);
if (is_dir($dir) && @imagejpeg($out, $cached, 82)) serve_file($cached);

// Si no se pudo guardar en disco, la mandamos igual.
header('Content-Type: image/jpeg');
header('Cache-Control: public, max-age=86400');
imagejpeg($out, null, 82);

// --- Tarjeta con el logo (plantilla Ejecutiva) ----------------------------------
// 1200×630 con el fondo de la invitación (papel claro u oscuro), el marco fino
// doble de la tarjeta, el logo centrado y una línea fina en el color de
// detalles debajo, como la portada. El texto (título, fecha, lugar) lo pone
// WhatsApp abajo de la imagen, desde og.php.
function og_rgb($hex) {
  return [hexdec(substr($hex, 1, 2)), hexdec(substr($hex, 3, 2)), hexdec(substr($hex, 5, 2))];
}
// $t de $a y el resto de $b (como color-mix en CSS).
function og_mix($a, $b, $t) {
  [$r1, $g1, $b1] = og_rgb($a);
  [$r2, $g2, $b2] = og_rgb($b);
  return [(int) round($r1 * $t + $r2 * (1 - $t)), (int) round($g1 * $t + $g2 * (1 - $t)), (int) round($b1 * $t + $b2 * (1 - $t))];
}

function og_logo_card($data) {
  $src = $data['logo'] ?? '';
  if (!$src || !og_config_ok() || strpos($src, rtrim(OG_SUPABASE_URL, '/') . '/storage/') !== 0
    || !function_exists('imagecreatefromstring') || !function_exists('curl_init')) {
    http_response_code(404);
    return;
  }
  $st = og_logo_card_style($data);

  $dir = __DIR__ . '/og-cache';
  $cached = $dir . '/' . sha1(og_logo_card_key($data)) . '-logo.jpg';
  if (is_file($cached)) serve_file($cached);

  $ch = curl_init($src);
  curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_FOLLOWLOCATION => true,
    CURLOPT_CONNECTTIMEOUT => 4,
    CURLOPT_TIMEOUT => 12,
    CURLOPT_MAXFILESIZE => 20 * 1024 * 1024,
  ]);
  $bytes = curl_exec($ch);
  curl_close($ch);
  $logo = $bytes ? @imagecreatefromstring($bytes) : false;
  if (!$logo) {
    http_response_code(404); // og.php igual muestra título y descripción
    return;
  }
  og_draw_logo_card($logo, $st, $cached);
}

// Separado de la descarga para poder probarlo con un archivo local.
function og_draw_logo_card($logo, $st, $cached = null) {
  $W = 1200;
  $H = 630;
  $out = imagecreatetruecolor($W, $H);
  $color = fn($rgb) => imagecolorallocate($out, $rgb[0], $rgb[1], $rgb[2]);
  imagefill($out, 0, 0, $color(og_rgb($st['bg'])));

  // Marco fino doble.
  $frame = $color($st['dark'] ? og_mix($st['accent'], $st['bg'], 0.35) : og_mix($st['ink'], $st['bg'], 0.18));
  imagesetthickness($out, 2);
  imagerectangle($out, 36, 36, $W - 37, $H - 37, $frame);
  imagerectangle($out, 50, 50, $W - 51, $H - 51, $frame);

  // Logo: entero, lo más grande que entre en 640×220.
  if (!imageistruecolor($logo)) imagepalettetotruecolor($logo);
  if ($st['white']) {
    imagefilter($logo, IMG_FILTER_BRIGHTNESS, -255); // todo negro, conserva la transparencia
    imagefilter($logo, IMG_FILTER_NEGATE); // → blanco
  }
  $lw = imagesx($logo);
  $lh = imagesy($logo);
  $scale = min(640 / $lw, 220 / $lh, 4);
  $dw = (int) round($lw * $scale);
  $dh = (int) round($lh * $scale);
  $dx = (int) round(($W - $dw) / 2);
  $dy = (int) round(($H - $dh) / 2 - 24);
  imagealphablending($out, true);
  imagecopyresampled($out, $logo, $dx, $dy, 0, 0, $dw, $dh, $lw, $lh);

  // Línea fina debajo, en el color de detalles.
  $line = $color($st['dark'] ? og_rgb($st['accent']) : og_mix($st['accent'], $st['ink'], 0.85));
  $ly = $dy + $dh + 44;
  imagefilledrectangle($out, (int) ($W / 2 - 90), $ly, (int) ($W / 2 + 90), $ly + 1, $line);
  imageinterlace($out, true);

  if ($cached) {
    $dir = dirname($cached);
    if (!is_dir($dir)) @mkdir($dir, 0755, true);
    if (is_dir($dir) && @imagejpeg($out, $cached, 88)) serve_file($cached);
  }
  header('Content-Type: image/jpeg');
  header('Cache-Control: public, max-age=86400');
  imagejpeg($out, null, 88);
}
