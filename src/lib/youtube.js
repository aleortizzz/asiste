// Búsqueda de videos por YouTube Data API v3, llamada directo desde el
// navegador. La key se restringe por dominio (HTTP referrer) en Google
// Cloud Console — ver supabase/migrations/20260924_canciones_plan.sql y
// el README para los pasos. Sin key configurada, devuelve [] en vez de
// romper la sección de canciones.
const API_KEY = import.meta.env.VITE_YOUTUBE_API_KEY

// La API devuelve el título con entidades HTML escapadas (& -> &amp;, etc).
function decodeHtmlEntities(str) {
  return new DOMParser().parseFromString(str, 'text/html').documentElement.textContent
}

export async function searchYoutubeVideos(query) {
  const q = query.trim()
  if (!q || !API_KEY) return []

  const url = new URL('https://www.googleapis.com/youtube/v3/search')
  url.searchParams.set('part', 'snippet')
  url.searchParams.set('type', 'video')
  url.searchParams.set('videoEmbeddable', 'true')
  url.searchParams.set('maxResults', '6')
  url.searchParams.set('q', q)
  url.searchParams.set('key', API_KEY)

  const res = await fetch(url)
  if (!res.ok) throw new Error('No se pudo buscar en YouTube')
  const data = await res.json()

  return (data.items ?? []).map((item) => ({
    videoId: item.id.videoId,
    title: decodeHtmlEntities(item.snippet.title),
    channel: decodeHtmlEntities(item.snippet.channelTitle),
    thumbnail: item.snippet.thumbnails?.default?.url,
  }))
}
