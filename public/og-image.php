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
