# Edge Functions (Mercado Pago)

| Función | La llama | Verify JWT |
|---|---|---|
| `crear-pago` | El panel («Tu plan»), con la sesión del organizador | **Sí** |
| `mp-webhook` | Mercado Pago, cuando un pago cambia | **No** (MP no tiene sesión) |

La lógica de los pagos está en la base: `migrations/20261015_pagos.sql` (correrla antes).

## Subirlas desde el Dashboard (sin instalar nada)

1. Supabase → **Edge Functions** → *Deploy a new function* → *Via Editor*.
2. Nombre exacto (`crear-pago` / `mp-webhook`), pegar el `index.ts` y *Deploy*.
3. En `mp-webhook` → *Details* / *Settings*: apagar **Enforce JWT verification** y guardar.
4. **Edge Functions → Secrets**:
   - `MP_ACCESS_TOKEN`: Mercado Pago Developers → Tus integraciones → la app → Credenciales.
     Para probar, la de **prueba** (`TEST-…` o la de un vendedor de prueba); para cobrar de verdad, la de **producción** (`APP_USR-…`).
   - `MP_WEBHOOK_SECRET` (opcional, recomendado): en la app de MP → Webhooks → configurar la URL
     `https://<proyecto>.supabase.co/functions/v1/mp-webhook`, evento **Pagos**, y copiar la «clave secreta».
   - `SITE_URL` (opcional): por defecto `https://asiste.tizdigital.com`. Para probar en local: `http://localhost:5173`.

Los cambios a una función se suben repitiendo el paso 2 (editar y *Deploy*).

## Con la CLI (alternativa)

```sh
npx supabase login
npx supabase functions deploy crear-pago --project-ref <ref>
npx supabase functions deploy mp-webhook --project-ref <ref> --no-verify-jwt
npx supabase secrets set MP_ACCESS_TOKEN=... --project-ref <ref>
```

## Probar

- Con credenciales de prueba se paga con las [tarjetas de prueba](https://www.mercadopago.com.ar/developers/es/docs/checkout-pro/additional-content/your-integrations/test/cards)
  (titular `APRO` = aprobado, `OTHE` = rechazado, `CONT` = pendiente), logueado en MP con un **comprador de prueba**, no con tu cuenta real.
- Lo que pasó se ve en Supabase → Edge Functions → la función → **Logs**, y en la tabla `pagos`.
- Si el aviso no llegó, el plan se puede subir a mano desde Superadmin (como hasta ahora).
