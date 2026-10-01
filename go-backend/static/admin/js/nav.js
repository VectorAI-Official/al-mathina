/* ==========================================================================
   AL-Madhina Admin — app shell behaviour
   --------------------------------------------------------------------------
   The ONLY JavaScript file added by the UI work. It is fully guarded and
   self-contained: if the shell markup is absent, or the script is blocked,
   or it throws, the page behaves exactly as it did before.

   Without JS the .app-nav stays visible (see components.css), so navigation
   degrades to a scrollable link row rather than disappearing.
   ========================================================================== */
(function () {
    'use strict';

    var doc = document;

    function ready(fn) {
        if (doc.readyState === 'loading') {
            doc.addEventListener('DOMContentLoaded', fn, { once: true });
        } else {
            fn();
        }
    }

    ready(function () {
        var header = doc.querySelector('.app-header');
        if (!header) return;

        var toggle = header.querySelector('.nav-toggle');
        var drawer = doc.querySelector('.app-drawer');
        var backdrop = doc.querySelector('.app-drawer-backdrop');

        /* --- active link, derived from the URL so every page agrees --------- */
        var path = window.location.pathname.replace(/\/+$/, '') || '/';
        var links = doc.querySelectorAll('.app-nav-link, .app-drawer__link');
        for (var i = 0; i < links.length; i++) {
            var href = (links[i].getAttribute('href') || '').replace(/\/+$/, '');
            if (href && href === path) {
                links[i].setAttribute('aria-current', 'page');
            } else {
                links[i].removeAttribute('aria-current');
            }
        }

        /* --- no drawer on this page: nothing else to wire up ---------------- */
        if (!toggle || !drawer) return;

        var lastFocused = null;

        function isOpen() {
            return drawer.getAttribute('data-open') === 'true';
        }

        function open() {
            lastFocused = doc.activeElement;
            drawer.setAttribute('data-open', 'true');
            if (backdrop) backdrop.setAttribute('data-open', 'true');
            toggle.setAttribute('aria-expanded', 'true');
            doc.documentElement.style.overflow = 'hidden';
            var first = drawer.querySelector('a, button');
            if (first) first.focus();
        }

        function close() {
            if (!isOpen()) return;
            drawer.setAttribute('data-open', 'false');
            if (backdrop) backdrop.setAttribute('data-open', 'false');
            toggle.setAttribute('aria-expanded', 'false');
            doc.documentElement.style.overflow = '';
            if (lastFocused && lastFocused.focus) lastFocused.focus();
        }

        function toggleDrawer() {
            if (isOpen()) close(); else open();
        }

        toggle.addEventListener('click', toggleDrawer);
        if (backdrop) backdrop.addEventListener('click', close);

        /* Tapping any destination closes the drawer before navigation. */
        drawer.addEventListener('click', function (e) {
            if (e.target.closest('a')) close();
        });

        doc.addEventListener('keydown', function (e) {
            if (e.key === 'Escape') close();
        });

        /* Back to the inline nav once there is room for it again. */
        var mq = window.matchMedia('(min-width: 769px)');
        var onChange = function (e) {
            if (e.matches) close();
        };
        if (mq.addEventListener) {
            mq.addEventListener('change', onChange);
        } else if (mq.addListener) {
            mq.addListener(onChange);
        }

        /* Mark as enhanced so CSS can retire the no-JS fallback path. */
        header.setAttribute('data-enhanced', 'true');
    });
})();
