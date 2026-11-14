/* Oratório — Service Worker
   - Páginas (index.html): primeiro a internet, para sempre mostrar a versão mais nova;
     sem internet, usa a cópia guardada.
   - Bíblia, imagens dos santos e motor da voz: usa a cópia guardada (rápido e offline)
     e guarda novos arquivos conforme vão sendo usados.
   - API litúrgica (outro endereço): sempre direto na internet. */
const VERSAO = 'oratorio-v14';
const ESSENCIAIS = ['./', './index.html', './manifest.webmanifest', './biblia.json', './icones/icone-192.png', './icones/icone-512.png', './sobre.html'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSAO).then((c) => c.addAll(ESSENCIAIS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((chaves) => Promise.all(chaves.filter((k) => k !== VERSAO).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

function guardar(pedido, resposta) {
  if (resposta && resposta.ok) {
    const copia = resposta.clone();
    caches.open(VERSAO).then((c) => c.put(pedido, copia));
  }
  return resposta;
}

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET' || url.origin !== location.origin) return;
  const ehPagina = e.request.mode === 'navigate' || /\.(html|webmanifest)$/.test(url.pathname) || url.pathname.endsWith('/');
  if (ehPagina) {
    // Internet primeiro (versão nova); sem conexão, a cópia guardada
    e.respondWith(
      fetch(e.request).then((r) => guardar(e.request, r))
        .catch(() => caches.match(e.request, { ignoreSearch: true }).then((salvo) => salvo || caches.match('./index.html')))
    );
    return;
  }
  e.respondWith(
    caches.match(e.request, { ignoreSearch: true }).then((salvo) => salvo || fetch(e.request).then((r) => guardar(e.request, r)))
  );
});
