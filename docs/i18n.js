(function () {
  var SUPPORTED = ['tr', 'en', 'ar'];

  function resolveInitialLang() {
    var params = new URLSearchParams(window.location.search);
    var q = (params.get('lang') || '').toLowerCase().slice(0, 2);
    if (SUPPORTED.indexOf(q) !== -1) return q;

    try {
      var saved = localStorage.getItem('mikat_lang');
      if (saved && SUPPORTED.indexOf(saved) !== -1) return saved;
    } catch (e) {}

    var nav = (navigator.language || 'tr').toLowerCase().slice(0, 2);
    if (SUPPORTED.indexOf(nav) !== -1) return nav;
    return 'tr';
  }

  function applyLang(lang, persist) {
    if (SUPPORTED.indexOf(lang) === -1) lang = 'tr';
    var root = document.documentElement;
    root.setAttribute('data-active-lang', lang);
    root.setAttribute('lang', lang);
    root.setAttribute('dir', lang === 'ar' ? 'rtl' : 'ltr');

    if (persist) {
      try {
        localStorage.setItem('mikat_lang', lang);
      } catch (e) {}
      try {
        var url = new URL(window.location.href);
        url.searchParams.set('lang', lang);
        window.history.replaceState({}, '', url.toString());
      } catch (e) {}
    }

    var buttons = document.querySelectorAll('.lang-btn[data-set-lang]');
    buttons.forEach(function (btn) {
      var active = btn.getAttribute('data-set-lang') === lang;
      btn.classList.toggle('active', active);
      btn.setAttribute('aria-pressed', active ? 'true' : 'false');
    });

    // Update page title if localized titles exist
    var titleEl = document.querySelector('meta[name="title-' + lang + '"]');
    if (titleEl && titleEl.getAttribute('content')) {
      document.title = titleEl.getAttribute('content');
    }

    // Preserve ?lang=... on internal page links
    document.querySelectorAll('a[data-local-nav]').forEach(function (link) {
      var base = link.getAttribute('data-local-nav');
      link.setAttribute('href', base + '?lang=' + lang);
    });
  }

  // Apply immediately to minimize FOUC
  var initial = resolveInitialLang();
  document.documentElement.setAttribute('data-active-lang', initial);
  document.documentElement.setAttribute('lang', initial);
  document.documentElement.setAttribute('dir', initial === 'ar' ? 'rtl' : 'ltr');

  document.addEventListener('DOMContentLoaded', function () {
    applyLang(initial, false);
    document.querySelectorAll('.lang-btn[data-set-lang]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        applyLang(btn.getAttribute('data-set-lang'), true);
      });
    });
  });
})();
