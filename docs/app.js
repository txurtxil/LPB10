/* ═══════════════ LMB10 — i18n + motion ═══════════════ */
(function () {
  "use strict";

  /* ── Diccionario ─────────────────────────────────── */
  const I18N = {
    es: {
      "skip": "Saltar al contenido",
      "nav.features": "Funciones", "nav.shots": "Capturas", "nav.compat": "Compatibilidad",
      "nav.versions": "Versiones", "nav.install": "Instalar",
      "hero.kicker": "APP NO OFICIAL · ANDROID · GPLv3",
      "hero.sub": "Tu Leapmotor, bajo tu control. Monitoriza y controla tu coche desde Android con funciones que la app oficial no ofrece.",
      "hero.cta1": "Conviértete en tester", "hero.cta2": "Descargar APK",
      "hero.note": " · gratis · sin anuncios · desarrollada sobre un B10 real",
      "notice": "⚠ ANDROID AUTO — temporalmente desactivado por una revisión de políticas de Google Play. Volverá.",
      "stats.v": "versión actual", "stats.refresh": "refresco en vivo",
      "stats.free": "sin anuncios ni cuentas extra", "stats.gpl": "código abierto", "stats.mtls": "+ firma HMAC-SHA256",
      "feat.label": "01 — FUNCIONES", "feat.title": "Todo lo que tu coche sabe, en tu bolsillo.",
      "feat.1.t": "Panel en vivo",
      "feat.1.d": "Batería precisa, autonomía, cerradura, carga, clima, maletero y centinela, con refresco automático cada 90 segundos. Odómetro, consumo real frente al dato del fabricante y la foto de tu propio coche servida por la nube.",
      "feat.2.t": "Controles remotos completos",
      "feat.2.d": "Bloqueo, climatización, asientos calefactados y ventilados, techo, ventanillas, maletero, limitador de velocidad, precalentado de batería, límite de carga y programación horaria. Con PIN, igual que la app oficial.",
      "feat.3.t": "Carga en la ventana más barata",
      "feat.3.d": "Precios PVPC horarios de REData integrados: la app calcula la ventana contigua más barata de 2 a 8 horas y te la sugiere en el programador de carga. También coste por día, semana y mes en euros.",
      "feat.4.t": "Destino al navegador del coche",
      "feat.4.d": "Busca una dirección y envíala directamente al navegador del vehículo antes de salir de casa. Sin PIN y sin tocar la pantalla del coche.",
      "feat.5.t": "Rutinas y precondicionado",
      "feat.5.d": "Programa climatización, carga al 80 %, precalentado de batería o salidas matutinas. Se ejecutan en segundo plano aunque la app esté cerrada.",
      "feat.6.t": "Tus datos son tuyos",
      "feat.6.d": "Todo se guarda cifrado en tu teléfono; nada va a servidores del desarrollador. Copia de seguridad exportable (JSON + CSV) y copia diaria opcional en tu propio Google Drive.",
      "chip.widget": "Widget de escritorio", "chip.ticket": "Tickets en impresora térmica",
      "chip.sentry": "Modo centinela", "chip.odo": "Odómetro", "chip.tires": "Presión de neumáticos",
      "chip.map": "Mapa y ubicación", "chip.log": "Log de diagnóstico",
      "shots.label": "02 — CAPTURAS", "shots.title": "La app, tal como es.",
      "shot.0": "Tu coche en el panel",
      "shot.1": "Panel principal", "shot.2": "Controles remotos", "shot.3": "Confort y batería",
      "shot.4": "Rutinas", "shot.5": "Consumo y coste", "shot.6": "Precio de la luz",
      "shot.7": "Ticket de eficiencia", "shot.8": "Widget",
      "compat.label": "03 — COMPATIBILIDAD", "compat.title": "Confirmado en coches reales, no en teoría.",
      "compat.lead": "Desarrollada y probada a diario sobre un B10. El login y el protocolo funcionan en toda la gama Leapmotor; el resto crece con cada tester que reporta.",
      "compat.feat": "Función",
      "c.1": "Batería y autonomía", "c.2": "Presión de neumáticos", "c.3": "Cerradura, maletero y clima",
      "c.4": "Ubicación GPS y odómetro", "c.5": "Telemetría ABRP", "c.6": "Controles remotos",
      "c.untested": "sin probar",
      "compat.note": "Los híbridos de autonomía extendida (C10 REEV) no están soportados. ¿Tienes un C10 o un B05? Tu reporte en el grupo de testers completa esta tabla.",
      "inst.label": "04 — INSTALACIÓN", "inst.title": "Tester en 3 pasos.",
      "inst.lead": "Si alguien te ha mandado el enlace, esto es todo lo que necesitas. Un minuto, sin aprobación.",
      "inst.s1.t": "Únete al grupo de testers",
      "inst.s1.d": "Un clic, sin aprobación. El grupo es además el canal de dudas, fallos y sugerencias.",
      "inst.s1.cta": "groups.google.com/g/lmb10-testers",
      "inst.s2.t": "Activa la prueba en Google Play",
      "inst.s2.d": "Con la misma cuenta de Google, pulsa «Convertirte en tester».",
      "inst.s2.cta": "play.google.com · Convertirte en tester",
      "inst.s3.t": "Instala e importa tu certificado",
      "inst.s3.d": "Instala LMB10 desde Play (puede tardar unos minutos en aparecer) y sigue Ajustes → Importar certificado: la nube de Leapmotor exige mTLS con tu propio certificado.",
      "inst.alt.t": "¿Prefieres el APK directo?",
      "inst.alt.d": "Está en GitHub Releases. Ojo: las dos vías van firmadas con claves distintas — cambiar de una a otra exige exportar copia, desinstalar e importar de nuevo, y el APK no aparece en Android Auto.",
      "inst.alt.cta": "APK en GitHub",
      "ver.label": "05 — VERSIONES", "ver.title": "Un cambio por release, validado en coche real.",
      "ver.151": "Ventana barata PVPC: la app sugiere las horas más baratas en el programador de carga.",
      "ver.150": "Enviar destino al navegador del coche (búsqueda Nominatim, sin PIN).",
      "ver.149": "Odómetro: km totales, días desde la entrega y media diaria.",
      "ver.148": "La foto real de tu coche en el panel, servida por la nube de Leapmotor.",
      "ver.147": "Limpieza: eliminados el historial de cargas y FOTA, inertes en este modelo.",
      "ver.121": "Autonomía de reserva en modelos sin señal en vivo (confirmado en un T03).",
      "ver.all": "Historial completo en GitHub →",
      "ver.loading": "Cargando releases desde GitHub…",
      "coffee.label": "06 — APOYAR EL PROYECTO",
      "coffee.title": "Gratis siempre.<br>Si te sirve, invítame a un café.",
      "coffee.lead": "Sin anuncios, sin suscripciones, sin más cuentas que las tuyas. El café es totalmente opcional — nunca hace falta para ser tester ni para usar nada.",
      "coffee.cta": "☕ ko-fi.com/txurtxil",
      "foot.by": "por SurferRule · @txurtxil",
      "foot.project": "PROYECTO", "foot.releases": "Releases", "foot.group": "Grupo de testers",
      "foot.privacy": "Privacidad", "foot.credits": "CRÉDITOS", "foot.legal": "LEGAL",
      "foot.license": "Licencia GNU GPLv3. Proyecto personal, experimental y sin ánimo de lucro, con fines de interoperabilidad e investigación (EU Data Act).",
      "foot.disclaimer": "App no oficial e independiente. No afiliada ni respaldada por Leapmotor. Úsala bajo tu responsabilidad; se recomienda una cuenta secundaria."
    },
    en: {
      "skip": "Skip to content",
      "nav.features": "Features", "nav.shots": "Screenshots", "nav.compat": "Compatibility",
      "nav.versions": "Versions", "nav.install": "Install",
      "hero.kicker": "UNOFFICIAL APP · ANDROID · GPLv3",
      "hero.sub": "Your Leapmotor, under your control. Monitor and control your car from Android with features the official app doesn't offer.",
      "hero.cta1": "Become a tester", "hero.cta2": "Download APK",
      "hero.note": "v3.60.151+301 · free · no ads · developed on a real B10",
      "notice": "⚠ ANDROID AUTO — temporarily unavailable while a Google Play policy review is resolved. It will be back.",
      "stats.v": "current version", "stats.refresh": "live refresh",
      "stats.free": "no ads, no extra accounts", "stats.gpl": "open source", "stats.mtls": "+ HMAC-SHA256 signing",
      "feat.label": "01 — FEATURES", "feat.title": "Everything your car knows, in your pocket.",
      "feat.1.t": "Live dashboard",
      "feat.1.d": "Precise battery, range, lock, charging, climate, trunk and sentry status, auto-refreshing every 90 seconds. Odometer, real-world consumption vs the manufacturer's figure, and your own car's photo served by the cloud.",
      "feat.2.t": "Full remote controls",
      "feat.2.d": "Lock, climate, heated and ventilated seats, roof, windows, trunk, speed limiter, battery preheating, charge limit and schedule editor. PIN-protected, just like the official app.",
      "feat.3.t": "Charge in the cheapest window",
      "feat.3.d": "Hourly PVPC electricity prices from REData built in: the app finds the cheapest contiguous 2–8 hour window and suggests it in the charge scheduler. Plus energy cost per day, week and month, in euros.",
      "feat.4.t": "Destination to the car's nav",
      "feat.4.d": "Search an address and send it straight to the vehicle's navigator before leaving home. No PIN, no touching the car's screen.",
      "feat.5.t": "Routines & preconditioning",
      "feat.5.d": "Schedule climate, 80% charging, battery preheating or morning departures. They run in the background even with the app closed.",
      "feat.6.t": "Your data is yours",
      "feat.6.d": "Everything is stored encrypted on your phone; nothing goes to the developer's servers. Exportable backup (JSON + CSV) and optional daily copy to your own Google Drive.",
      "chip.widget": "Desktop widget", "chip.ticket": "Thermal printer receipts",
      "chip.sentry": "Sentry mode", "chip.odo": "Odometer", "chip.tires": "Tire pressure",
      "chip.map": "Map & location", "chip.log": "Diagnostic log",
      "shots.label": "02 — SCREENSHOTS", "shots.title": "The app, as it is.",
      "shot.1": "Dashboard", "shot.2": "Remote controls", "shot.3": "Comfort & battery",
      "shot.4": "Routines", "shot.5": "Consumption & cost", "shot.6": "Electricity price",
      "shot.7": "Efficiency receipt", "shot.8": "Widget",
      "compat.label": "03 — COMPATIBILITY", "compat.title": "Confirmed on real cars, not in theory.",
      "compat.lead": "Developed and daily-driven on a B10. Login and protocol work across the Leapmotor range; the rest grows with every tester report.",
      "compat.feat": "Feature",
      "c.1": "Battery & range", "c.2": "Tire pressure", "c.3": "Lock, trunk & climate",
      "c.4": "GPS location & odometer", "c.5": "ABRP telemetry", "c.6": "Remote controls",
      "c.untested": "untested",
      "compat.note": "Range-extender hybrids (C10 REEV) are not supported. Have a C10 or a B05? Your report in the testers group completes this table.",
      "inst.label": "04 — INSTALLATION", "inst.title": "Two channels, one decision.",
      "inst.lead": "They are not interchangeable: they are signed with different keys, and switching means exporting a backup, uninstalling, and importing again.",
      "inst.play.tag": "RECOMMENDED", "inst.play.sub": "· closed testing",
      "inst.play.1": "Join the testers group (one click).",
      "inst.play.2": "Tap “Become a tester” on Play.",
      "inst.play.3": "Install LMB10, then Settings → Import certificate.",
      "inst.play.cta1": "Testers group", "inst.play.cta2": "Become a tester",
      "inst.play.note": "The only channel Android Auto can use once re-enabled.",
      "inst.gh.tag": "DIRECT", "inst.gh.sub": "· APK",
      "inst.gh.1": "Download the APK from the latest release.",
      "inst.gh.2": "Install it allowing unknown sources.",
      "inst.gh.3": "Import your client certificate in Settings.",
      "inst.gh.cta": "Latest release",
      "inst.gh.note": "Installs anywhere, but won't appear in Android Auto.",
      "cert.t": "🔐 Client certificate",
      "cert.d": "Leapmotor's cloud requires mTLS: you need your own client certificate (the app ships none). Settings → Import certificate walks you through it, based on the community leapmotor-certs material.",
      "ver.label": "05 — VERSIONS", "ver.title": "One change per release, validated on a real car.",
      "ver.151": "Cheapest PVPC window: the app suggests the cheapest hours in the charge scheduler.",
      "ver.150": "Send destination to the car's navigator (Nominatim search, no PIN).",
      "ver.149": "Odometer: total km, days since delivery and daily average.",
      "ver.148": "Your real car's photo on the dashboard, served by Leapmotor's cloud.",
      "ver.147": "Cleanup: removed charge history and FOTA, inert on this model.",
      "ver.121": "Fallback range on models without the live signal (confirmed on a T03).",
      "ver.all": "Full changelog on GitHub →",
      "coffee.label": "06 — SUPPORT THE PROJECT",
      "coffee.title": "Free forever.<br>If it's useful, buy me a coffee.",
      "coffee.lead": "No ads, no subscriptions, no accounts beyond your own. The coffee is entirely optional — never required to be a tester or to use anything.",
      "coffee.cta": "☕ ko-fi.com/txurtxil",
      "foot.by": "by SurferRule · @txurtxil",
      "foot.project": "PROJECT", "foot.releases": "Releases", "foot.group": "Testers group",
      "foot.privacy": "Privacy", "foot.credits": "CREDITS", "foot.legal": "LEGAL",
      "foot.license": "GNU GPLv3 license. Personal, experimental, non-commercial project for interoperability and research purposes (EU Data Act).",
      "foot.disclaimer": "Unofficial, independent app. Not affiliated with or endorsed by Leapmotor. Use at your own risk; a secondary account is recommended."
    }
  };

  /* ── Idioma ──────────────────────────────────────── */
  const html = document.documentElement;
  const toggle = document.getElementById("langToggle");

  function setLang(lang) {
    const dict = I18N[lang] || I18N.es;
    html.lang = lang;
    document.querySelectorAll("[data-i18n]").forEach((el) => {
      const k = el.getAttribute("data-i18n");
      if (dict[k] !== undefined) el.innerHTML = dict[k];
    });
    toggle.querySelectorAll("span").forEach((s) => {
      s.classList.toggle("active", s.dataset.lang === lang);
    });
    try { localStorage.setItem("lmb10-lang", lang); } catch (e) {}
  }

  toggle.addEventListener("click", () => {
    setLang(html.lang === "es" ? "en" : "es");
  });

  let initial = "es";
  try {
    const saved = localStorage.getItem("lmb10-lang");
    if (saved) initial = saved;
    else if (navigator.language && !navigator.language.toLowerCase().startsWith("es")) initial = "en";
  } catch (e) {}
  setLang(initial);

  /* ── Hero: reveal de letras ──────────────────────── */
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (!reduced) {
    const letters = document.querySelectorAll(".hero-title .w span");
    letters.forEach((s, i) => {
      s.style.transition = "transform 1s cubic-bezier(.38,.005,.215,1) " + (0.08 + i * 0.07) + "s";
      requestAnimationFrame(() => requestAnimationFrame(() => { s.style.transform = "translateY(0)"; }));
    });
    document.querySelectorAll(".reveal-line").forEach((el, i) => {
      el.style.transition = "opacity .9s ease " + (0.5 + i * 0.15) + "s, transform .9s cubic-bezier(.38,.005,.215,1) " + (0.5 + i * 0.15) + "s";
      requestAnimationFrame(() => requestAnimationFrame(() => { el.style.opacity = "1"; el.style.transform = "none"; }));
    });
  } else {
    document.querySelectorAll(".reveal-line,.hero-title .w span").forEach((el) => {
      el.style.opacity = "1"; el.style.transform = "none";
    });
  }

  /* ── Reveal on scroll ────────────────────────────── */
  const io = new IntersectionObserver((entries) => {
    entries.forEach((en) => {
      if (en.isIntersecting) { en.target.classList.add("in"); io.unobserve(en.target); }
    });
  }, { threshold: 0.18 });
  document.querySelectorAll(".reveal,.shot").forEach((el) => io.observe(el));

  /* ── Parallax hero ───────────────────────────────── */
  const heroBg = document.getElementById("heroBg");
  if (heroBg && !reduced) {
    let ticking = false;
    window.addEventListener("scroll", () => {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(() => {
        const y = Math.min(window.scrollY, window.innerHeight);
        heroBg.style.transform = "scale(" + (1.12 - y / window.innerHeight * 0.12) + ") translateY(" + y * 0.18 + "px)";
        ticking = false;
      });
    }, { passive: true });
  }

  /* ── Releases dinámicas desde la API de GitHub ──────
     La web se actualiza sola con cada release publicada;
     si la API falla, queda el contenido estático.        */
  const REPO = "txurtxil/LPB10";

  function stripMd(s) {
    return s
      .replace(/!\[[^\]]*\]\([^)]*\)/g, "")
      .replace(/\[([^\]]*)\]\([^)]*\)/g, "$1")
      .replace(/[*_`#>~]/g, "")
      .replace(/\s+/g, " ")
      .trim();
  }

  function releaseSummary(rel) {
    const body = (rel.body || "").split("\n")
      .map((l) => stripMd(l))
      .filter((l) => l.length > 12 && !/^(-\s*)?(apk|aab|sha256|checksum)/i.test(l));
    let s = body[0] || stripMd(rel.name || "") || rel.tag_name;
    if (s.length > 180) s = s.slice(0, 177).replace(/\s+\S*$/, "") + "…";
    return s;
  }

  function fmtDate(iso) {
    try {
      return new Date(iso).toLocaleDateString(html.lang === "es" ? "es-ES" : "en-GB",
        { day: "numeric", month: "short", year: "numeric" });
    } catch (e) { return ""; }
  }

  fetch("https://api.github.com/repos/" + REPO + "/releases?per_page=6")
    .then((r) => { if (!r.ok) throw new Error("http " + r.status); return r.json(); })
    .then((rels) => {
      if (!Array.isArray(rels) || !rels.length) throw new Error("empty");
      const latest = rels[0].tag_name;
      const heroVer = document.getElementById("heroVer");
      const statVer = document.getElementById("statVer");
      if (heroVer) heroVer.textContent = latest;
      if (statVer) statVer.textContent = latest;

      const tl = document.getElementById("timeline");
      if (!tl) return;
      tl.innerHTML = "";
      rels.forEach((rel) => {
        const row = document.createElement("div");
        row.className = "tl-row in";
        const v = document.createElement("span");
        v.className = "mono tl-v";
        v.textContent = rel.tag_name;
        const p = document.createElement("p");
        p.textContent = releaseSummary(rel) + " ";
        const d = document.createElement("span");
        d.className = "tl-date";
        d.textContent = "· " + fmtDate(rel.published_at);
        p.appendChild(d);
        row.appendChild(v);
        row.appendChild(p);
        tl.appendChild(row);
      });
    })
    .catch(() => {
      // Fallback: contenido estático ya presente en el HTML
      const loading = document.getElementById("tlLoading");
      if (loading) loading.remove();
    });
})();
