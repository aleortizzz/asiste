<?php
// Funciones compartidas por og.php y og-image.php (vista previa de links al
// compartirlos por WhatsApp, Telegram, etc.). Este archivo no imprime nada.
//
// og-config.php no está en el repo: lo genera el deploy
// (.github/workflows/deploy.yml) con la URL y la anon key de Supabase, las
// mismas que ya van públicas dentro del JS de la app.

function og_config_ok() {
  $file = __DIR__ . '/og-config.php';
  if (!is_file($file)) return false;
  require_once $file;
  return defined('OG_SUPABASE_URL') && defined('OG_SUPABASE_KEY') && OG_SUPABASE_URL !== '';
}

// Llama a una función RPC de Supabase. Devuelve el array decodificado o null
// ante cualquier problema (sin config, sin red, función inexistente…).
function og_rpc($fn, $params) {
  if (!og_config_ok() || !function_exists('curl_init')) return null;
  $ch = curl_init(rtrim(OG_SUPABASE_URL, '/') . '/rest/v1/rpc/' . $fn);
  curl_setopt_array($ch, [
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => json_encode($params),
    CURLOPT_HTTPHEADER => [
      'apikey: ' . OG_SUPABASE_KEY,
      'Authorization: Bearer ' . OG_SUPABASE_KEY,
      'Content-Type: application/json',
    ],
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_CONNECTTIMEOUT => 3,
    CURLOPT_TIMEOUT => 4,
  ]);
  $body = curl_exec($ch);
  $status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
  curl_close($ch);
  if ($body === false || $status !== 200) return null;
  $data = json_decode($body, true);
  return is_array($data) ? $data : null;
}

// Datos para la vista previa según el tipo de link:
//   t=i → invitación de una familia (/i/:slug)
//   t=f → galería de fotos del evento (/fotos/:eventId)
function og_fetch($type, $key) {
  if ($type === 'i' && preg_match('/^[A-Za-z0-9_-]{1,64}$/', $key)) {
    return og_rpc('vista_previa_invitacion', ['p_slug' => $key]);
  }
  if ($type === 'f' && preg_match('/^[0-9a-fA-F-]{36}$/', $key)) {
    return og_rpc('vista_previa_fotos', ['p_event_id' => $key]);
  }
  return null;
}

// "sábado 17 de octubre" sin depender del locale del servidor.
function og_fecha($iso) {
  if (!$iso || !preg_match('/^(\d{4})-(\d{2})-(\d{2})$/', $iso, $m)) return '';
  $dias = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
  $meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  $ts = mktime(12, 0, 0, (int) $m[2], (int) $m[3], (int) $m[1]);
  return $dias[(int) date('w', $ts)] . ' ' . (int) $m[3] . ' de ' . $meses[(int) $m[2] - 1];
}

function og_base_url() {
  $https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
    || (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https');
  return ($https ? 'https' : 'http') . '://' . $_SERVER['HTTP_HOST'];
}

// --- Tarjeta con el logo (plantilla Ejecutiva) --------------------------------
// Colores de la tarjeta: en claro, el papel de la invitación; en oscuro, el
// color principal. El logo se pasa a blanco solo en oscuro y si lo pidieron.
function og_logo_card_style($data) {
  $dark = ($data['theme_mode'] ?? '') === 'oscuro';
  $hex = fn($c, $def) => (is_string($c) && preg_match('/^#[0-9a-fA-F]{6}$/', $c)) ? strtolower($c) : $def;
  $primary = $hex($data['primary_color'] ?? '', '#0f1b2d');
  return [
    'dark' => $dark,
    'bg' => $dark ? $primary : $hex($data['bg_color'] ?? '', '#f7f4ee'),
    'ink' => $dark ? '#f3efe6' : $primary,
    'accent' => $hex($data['accent_color'] ?? '', '#c8a96a'),
    'white' => $dark && !empty($data['logo_white']),
  ];
}

// Cambia si cambia el logo o algo de cómo se dibuja la tarjeta.
function og_logo_card_key($data) {
  return ($data['logo'] ?? '') . '|' . json_encode(og_logo_card_style($data));
}
