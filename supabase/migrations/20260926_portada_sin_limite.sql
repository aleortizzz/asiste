-- ============================================================
-- Fotos: sacar el tope de 5 MB del bucket "event-photos"
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- La portada se sube sin achicar para que se vea con buena calidad a
-- pantalla completa. Storage solo permite un tope por bucket (no por
-- carpeta), así que el bucket queda sin tope propio (null = el máximo
-- global del proyecto, 50 MB en el plan gratis) y el límite de 5 MB para
-- las demás secciones lo valida el frontend (ver AdminSalon.vue,
-- validatePhoto).
-- ============================================================

update storage.buckets
  set file_size_limit = null
  where id = 'event-photos';
