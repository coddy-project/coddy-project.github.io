// Shared site chrome for coddy.dev: the mobile nav drawer, in-page anchor
// scrolling that clears the sticky header, and the release pill that reads the
// latest tag from the GitHub API. Loaded by every page so the header behaves
// the same on the landing page and on /compare/.
(function () {
  var burger = document.querySelector(".nav-burger");
  var drawer = document.getElementById("site-nav");
  var scrim = document.getElementById("nav-scrim");
  function isMobileNav() {
    return window.matchMedia("(max-width: 720px)").matches;
  }

  function scrollHeaderOffset() {
    if (!isMobileNav()) return 0;
    var header = document.querySelector(".site-header");
    return header ? Math.ceil(header.getBoundingClientRect().height) + 8 : 56;
  }

  function sectionScrollTop(hash) {
    var id = (hash || "").replace(/^#/, "");
    if (!id) return null;
    var target = document.getElementById(id);
    if (!target) return null;
    return Math.max(0, target.getBoundingClientRect().top + readScrollY() - scrollHeaderOffset());
  }

  function navScrollBehavior() {
    return isMobileNav() ? "instant" : "smooth";
  }

  function scrollToSection(hash, behavior) {
    var top = sectionScrollTop(hash);
    if (top == null) return;
    window.scrollTo({ top: top, left: 0, behavior: behavior || navScrollBehavior() });
  }

  var navScrollLockY = 0;

  function readScrollY() {
    return window.scrollY || window.pageYOffset || 0;
  }

  function syncSiteHeaderOffset() {
    var header = document.querySelector(".site-header");
    if (!header) return;
    if (!isMobileNav()) {
      document.documentElement.style.removeProperty("--site-header-offset");
      return;
    }
    document.documentElement.style.setProperty(
      "--site-header-offset",
      Math.ceil(header.getBoundingClientRect().height) + "px"
    );
  }

  function captureNavScrollY() {
    if (!isMobileNav()) return;
    navScrollLockY = readScrollY();
  }

  function lockPageScroll(lock) {
    if (!isMobileNav()) return;
    var root = document.documentElement;
    if (lock) {
      navScrollLockY = readScrollY();
      root.classList.add("nav-scroll-lock");
    } else {
      root.classList.remove("nav-scroll-lock");
    }
  }

  function unlockPageScroll(scrollTop, behavior) {
    if (!isMobileNav()) return;
    var root = document.documentElement;
    root.classList.remove("nav-scroll-lock");
    document.body.classList.remove("nav-open");
    window.scrollTo({ top: scrollTop, left: 0, behavior: behavior || "auto" });
  }

  function setNavOpen(open, scrollTarget) {
    if (!burger || !drawer || !scrim) return;
    if (!isMobileNav()) {
      drawer.classList.remove("is-open");
      scrim.classList.remove("is-open");
      scrim.hidden = true;
      document.body.classList.remove("nav-open");
      document.documentElement.classList.remove("nav-scroll-lock");
      burger.setAttribute("aria-expanded", "false");
      burger.setAttribute("aria-label", "Open menu");
      drawer.setAttribute("aria-hidden", "false");
      return;
    }
    burger.setAttribute("aria-expanded", open ? "true" : "false");
    burger.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    if (open) {
      captureNavScrollY();
      lockPageScroll(true);
      document.body.classList.add("nav-open");
    } else {
      var hadLock = document.documentElement.classList.contains("nav-scroll-lock");
      document.body.classList.remove("nav-open");
      drawer.classList.remove("is-open");
      drawer.setAttribute("aria-hidden", "true");
      scrim.classList.remove("is-open");
      scrim.hidden = true;
      if (hadLock) {
        var unlockY = typeof scrollTarget === "number" ? scrollTarget : navScrollLockY;
        unlockPageScroll(unlockY, typeof scrollTarget === "number" ? navScrollBehavior() : "auto");
      } else if (typeof scrollTarget === "number") {
        window.scrollTo({ top: scrollTarget, left: 0, behavior: navScrollBehavior() });
      }
      requestAnimationFrame(syncSiteHeaderOffset);
      return;
    }
    drawer.classList.toggle("is-open", open);
    drawer.setAttribute("aria-hidden", open ? "false" : "true");
    scrim.classList.toggle("is-open", open);
    scrim.hidden = !open;
    requestAnimationFrame(syncSiteHeaderOffset);
  }

  syncSiteHeaderOffset();
  window.addEventListener("resize", syncSiteHeaderOffset);

  if (burger && drawer && scrim) {
    setNavOpen(false);
    burger.addEventListener("pointerdown", captureNavScrollY, { passive: true });
    burger.addEventListener("touchstart", captureNavScrollY, { passive: true });
    burger.addEventListener("mousedown", function (e) {
      if (!isMobileNav()) return;
      e.preventDefault();
    });
    burger.addEventListener("click", function () {
      setNavOpen(!drawer.classList.contains("is-open"));
    });
    scrim.addEventListener("click", function () {
      setNavOpen(false);
    });
    drawer.querySelectorAll(".nav-drawer-link, .nav-release").forEach(function (link) {
      link.addEventListener("click", function (e) {
        var href = link.getAttribute("href") || "";
        if (href.charAt(0) === "#" && href.length > 1) {
          e.preventDefault();
          if (history.pushState) {
            history.pushState(null, "", href);
          } else {
            location.hash = href;
          }
          if (isMobileNav()) {
            setNavOpen(false, sectionScrollTop(href));
          } else {
            setNavOpen(false);
            scrollToSection(href, navScrollBehavior());
          }
          return;
        }
        setNavOpen(false);
      });
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && drawer.classList.contains("is-open")) {
        setNavOpen(false);
      }
    });
    window.addEventListener("resize", function () {
      setNavOpen(false);
      syncSiteHeaderOffset();
    });
  }

  if (location.hash) {
    window.requestAnimationFrame(function () {
      scrollToSection(location.hash, "auto");
    });
  }

  window.addEventListener("hashchange", function () {
    scrollToSection(location.hash, "smooth");
  });

  var releaseVersion = document.getElementById("release-pill-version");
  if (releaseVersion && window.fetch) {
    fetch("https://api.github.com/repos/coddy-project/coddy-agent/releases/latest", {
      headers: { Accept: "application/vnd.github+json" }
    })
      .then(function (r) {
        return r.ok ? r.json() : null;
      })
      .then(function (data) {
        var tag = data && data.tag_name ? String(data.tag_name).replace(/^v/, "") : "";
        if (!/^\d+\.\d+\.\d+/.test(tag)) return;
        releaseVersion.textContent = "v" + tag;
        // The package install commands name an asset file, so they carry the
        // version too. Fill them from the same answer instead of pinning a
        // number in the markup that goes stale on the next release.
        Array.prototype.slice.call(document.querySelectorAll(".pkg-version")).forEach(function (el) {
          el.textContent = tag;
        });
      })
      .catch(function () {});
  }
})();
