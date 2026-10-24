{{flutter_js}}
{{flutter_build_config}}

// Flutter navigation replaces the fragment; keep authentication across reloads.
try {
  const token = new URLSearchParams(location.hash.slice(1)).get('token');
  if (token) {
    sessionStorage.setItem('funclash.panelToken', token);
  } else {
    const saved = sessionStorage.getItem('funclash.panelToken');
    if (saved) history.replaceState(null, '', `#token=${encodeURIComponent(saved)}`);
  }
} catch (_) {
  // Storage may be disabled; an explicit token link still works.
}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
});
