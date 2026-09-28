<?php
// Vista previa de los links al compartirlos (WhatsApp, Telegram, Facebook…).
//
// Esos robots no ejecutan JavaScript: leen las etiquetas <meta property="og:…">
// del HTML tal cual llega. Como la app es una SPA, sin esto todos los links
// mostrarían lo mismo («asiste»). Acá tomamos el index.html de siempre y le
// agregamos título, descripción y foto de esa invitación.
//
// .htaccess manda acá solo a los robots de vista previa (por User-Agent); las
// personas reciben el index.html directo, sin esperar a Supabase. Si algo
// falla, se sirve el index.html sin cambios: nunca rompe el link.

require __DIR__ . '/og-lib.php';

header('Content-Type: text/html; charset=utf-8');
header('Cache-Control: no-cache');
header('Vary: User-Agent');

$html = @file_get_contents(__DIR__ . '/index.html');
if ($html === false) {
  http_response_code(500);
  exit;
}

$type = $_GET['t'] ?? '';
$key = $type === 'i' ? ($_GET['s'] ?? '') : ($_GET['e'] ?? '');
$data = og_fetch($type, $key);
if (!$data) {
  echo $html;
  exit;
}

$name = trim($data['hero_title'] ?? '') ?: trim($data['event_name'] ?? '') ?: 'Asiste';
$fecha = og_fecha($data['event_date'] ?? null);
$fechaTxt = $fecha ? ucfirst($fecha) . ' · ' : '';

if ($type === 'i') {
  $suffix = ['cumpleanos' => 'Mi invitación', 'casamiento' => 'Nuestra invitación'][$data['event_type'] ?? ''] ?? 'Invitación';
  $title = "$name · $suffix";
  $family = trim($data['family_name'] ?? '');
  $description = ($family ? "Para $family · " : '') . $fechaTxt . 'Tocá para ver la invitación y confirmar tu asistencia.';
  $path = '/i/' . $key;
} else {
  $title = "Compartí tus fotos · $name";
  $description = $fechaTxt . 'Subí las fotos que saques en la fiesta y mirá las de todos.';
  $path = '/fotos/' . $key;
}

$base = og_base_url();
$e = fn($s) => htmlspecialchars($s, ENT_QUOTES, 'UTF-8');

$meta = [
  '<title>' . $e($title) . '</title>',
  '<meta name="description" content="' . $e($description) . '" />',
  '<meta property="og:type" content="website" />',
  '<meta property="og:site_name" content="Asiste" />',
  '<meta property="og:locale" content="es_AR" />',
  '<meta property="og:url" content="' . $e($base . $path) . '" />',
  '<meta property="og:title" content="' . $e($title) . '" />',
  '<meta property="og:description" content="' . $e($description) . '" />',
];
if (!empty($data['image'])) {
  // La foto pasa por og-image.php: la achica a 1200×630 (WhatsApp no muestra
  // imágenes pesadas) y la guarda para no rehacerla en cada vista previa.
  // `v` cambia si cambia la foto, así WhatsApp no se queda con la vieja.
  $img = $base . '/og-image.php?t=' . $type . '&' . ($type === 'i' ? 's' : 'e') . '=' . rawurlencode($key)
    . '&v=' . substr(sha1($data['image']), 0, 10);
  array_push(
    $meta,
    '<meta property="og:image" content="' . $e($img) . '" />',
    '<meta property="og:image:width" content="1200" />',
    '<meta property="og:image:height" content="630" />',
    '<meta property="og:image:type" content="image/jpeg" />',
    '<meta name="twitter:card" content="summary_large_image" />'
  );
}

// Reemplaza el <title> genérico del index.html por el bloque nuevo.
$block = implode("\n    ", $meta);
$out = preg_replace('#<title>.*?</title>#s', $block, $html, 1, $count);
if (!$count) $out = str_replace('</head>', $block . "\n  </head>", $html);
echo $out;
