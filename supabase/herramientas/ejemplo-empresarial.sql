-- ============================================================
-- Cargar contenido de ejemplo en un evento empresarial (para mostrar todo
-- lo que se puede hacer con la plantilla Ejecutiva).
-- Pegar en Supabase → SQL Editor (proyecto "asiste"), completar el mail de
-- la cuenta y ejecutar.
--
-- SOLO COMPLETA LO QUE ESTÁ VACÍO: lo que ya está cargado no se toca.
-- Al final muestra un resumen de qué está completo y qué falta.
-- ============================================================

do $$
declare
  v_email text := 'aleortizjusto3@gmail.com';  -- ⬅ cuenta dueña del evento
  v_event uuid;
begin
  select e.id into v_event
  from public.events e join auth.users u on u.id = e.owner_user_id
  where lower(u.email) = lower(v_email);

  if v_event is null then
    raise exception 'No hay ningún evento para %', v_email;
  end if;

  update public.events set
    -- Programa (solo si no tiene ninguna actividad)
    agenda = case when jsonb_array_length(agenda) = 0 then '[
      {"time": "08:30", "title": "Acreditación y café de bienvenida", "detail": "Hall central"},
      {"time": "09:00", "title": "Apertura institucional", "detail": "Palabras de la Dirección"},
      {"time": "09:30", "title": "Resultados del año y desafíos 2027", "detail": "Dirección Comercial"},
      {"time": "10:30", "title": "Pausa café", "detail": ""},
      {"time": "11:00", "title": "Novedades de nuestros proveedores", "detail": "Schneider Electric · Ledvance · Festo"},
      {"time": "12:00", "title": "Reconocimiento a los equipos", "detail": ""},
      {"time": "12:30", "title": "Almuerzo de cierre", "detail": "Terraza"}
    ]'::jsonb else agenda end,

    -- Datos del evento
    hero_subtitle  = coalesce(nullif(trim(hero_subtitle), ''), 'Un encuentro para celebrar lo logrado y planificar lo que viene'),
    end_time       = coalesce(end_time, '13:30'),
    maps_url       = coalesce(nullif(trim(maps_url), ''), 'https://maps.google.com/?q=' || replace(coalesce(venue_address, 'Pilar'), ' ', '+')),
    dress_code     = coalesce(nullif(trim(dress_code), ''), 'Smart casual'),
    access_info    = coalesce(nullif(trim(access_info), ''), 'Estacionamiento gratuito dentro del predio.' || chr(10) || 'Ingreso por la entrada principal.'),
    notes          = coalesce(nullif(trim(notes), ''), 'En la acreditación se entrega el material del encuentro.'),
    rsvp_deadline  = coalesce(rsvp_deadline, event_date - 7),

    -- Contacto y redes (datos de ejemplo: reemplazarlos por los reales)
    contact_name   = coalesce(nullif(trim(contact_name), ''), 'Organización del Encuentro'),
    contact_email  = coalesce(nullif(trim(contact_email), ''), 'eventos@pelba.com.ar'),
    contact_phone  = coalesce(nullif(trim(contact_phone), ''), '54 9 11 0000-0000'),
    social_links   = case when social_links = '{}'::jsonb then '{"web": "www.pelba.com.ar"}'::jsonb else social_links end
  where id = v_event;

  raise notice 'Listo: ejemplos cargados donde estaba vacío.';
end;
$$;

-- Resumen: ✔ completo · ✘ falta (lo marcado «opcional» puede quedar vacío).
select
  case when e.logo <> '[]'::jsonb then '✔' else '✘' end                         as logo,
  case when e.event_date is not null then '✔' else '✘' end                       as fecha,
  case when e.reception_time is not null then '✔' else '✘' end                   as hora,
  case when coalesce(e.venue_name, '') <> '' then '✔' else '✘' end              as lugar,
  case when e.intro_text is not null then '✔' else '✘ (usa el de ejemplo)' end   as saludo,
  case when jsonb_array_length(e.agenda) > 0 then '✔' else '✘' end              as programa,
  case when e.sponsors <> '[]'::jsonb then '✔' else '✘ (opcional)' end          as sponsors,
  case when e.detalle <> '[]'::jsonb then '✔' else '✘ (opcional)' end           as foto_del_lugar,
  case when e.momentos <> '[]'::jsonb or e.retrato <> '[]'::jsonb or e.galeria <> '[]'::jsonb
       then '✔' else '✘ (opcional)' end                                           as fotos,
  case when e.rsvp_deadline is not null then '✔' else '✘' end                    as fecha_limite,
  e.template, e.theme_mode, e.tono, e.date_style
from public.events e join auth.users u on u.id = e.owner_user_id
where lower(u.email) = lower('aleortizjusto3@gmail.com');
