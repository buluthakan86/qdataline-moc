// CSP uyumu: satır içi onclick yerine veri özniteliği + olay delegasyonu (script-src 'unsafe-inline' yok).
// <button data-qdl-click="ad"> veya data-qdl-click="ad:argüman"  →  window.ad(argüman)
document.addEventListener('click', function(e){
  var el = e.target.closest && e.target.closest('[data-qdl-click]');
  if(!el) return;
  var v = el.getAttribute('data-qdl-click') || '', i = v.indexOf(':');
  var ad = i < 0 ? v : v.slice(0, i), arg = i < 0 ? undefined : v.slice(i + 1);
  if(typeof window[ad] === 'function') window[ad](arg);
});
