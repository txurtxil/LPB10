/* ═══════════════ LMB10 — i18n + motion ═══════════════ */
(function () {
  "use strict";

  /* ── Diccionario ─────────────────────────────────── */
  const I18N = {
    es: {
      "skip": "Saltar al contenido",
      "nav.features": "Funciones", "nav.shots": "Capturas", "nav.compat": "Compatibilidad",
      "nav.versions": "Versiones", "nav.install": "Instalar", "nav.community": "Comunidad",
      "hero.kicker": "APP NO OFICIAL · ANDROID + iOS · GPLv3",
      "hero.sub": "Tu Leapmotor, bajo tu control. Monitoriza y controla tu coche desde tu móvil con funciones que la app oficial no ofrece.",
      "hero.cta1": "Descargar en Google Play", "hero.cta2": "APK · IPA en GitHub",
      "hero.note": " · gratis · sin anuncios · desarrollada sobre un B10 real",
      "notice": "✓ ANDROID AUTO — ya disponible instalando LMB10 desde Google Play.",
      "stats.v": "versión actual", "stats.refresh": "refresco en vivo",
      "stats.free": "sin anuncios ni cuentas extra", "stats.gpl": "código abierto", "stats.mtls": "+ firma HMAC-SHA256",
      "feat.label": "01 — FUNCIONES", "feat.title": "Todo lo que tu coche sabe, en tu bolsillo.",
      "feat.1.t": "Panel en vivo",
      "feat.1.d": "Batería precisa, autonomía, cerradura, carga, clima, maletero y centinela, con refresco automático cada 90 segundos. Odómetro, consumo real frente al dato del fabricante y la foto de tu propio coche servida por la nube.",
      "feat.2.t": "Controles remotos completos",
      "feat.2.d": "Bloqueo, climatización, asientos calefactados y ventilados, techo, ventanillas, maletero, limitador de velocidad, precalentado de batería, límite de carga y programación horaria. Con PIN, igual que la app oficial.",
      "feat.3.t": "Costes de carga reales",
      "feat.3.d": "Cada sesión AC, DC o HPC con su curva de potencia y su coste en euros según tu tarifa (PVPC horario REData o precio fijo). La app sugiere la ventana contigua más barata de 2 a 8 horas en el programador, y acumula coste por día, semana y mes.",
      "feat.4.t": "Destino al navegador del coche",
      "feat.4.d": "Busca una dirección y envíala directamente al navegador del vehículo antes de salir de casa. Sin PIN y sin tocar la pantalla del coche.",
      "feat.5.t": "Rutinas y precondicionado",
      "feat.5.d": "Programa climatización, carga al 80 %, precalentado de batería o salidas matutinas. Se ejecutan en segundo plano aunque la app esté cerrada.",
      "feat.6.t": "Tus datos son tuyos",
      "feat.6.d": "Todo se guarda cifrado en tu teléfono; nada va a servidores del desarrollador. Copia de seguridad exportable (JSON + CSV) y copia diaria opcional en tu propio Google Drive.",
      "feat.7.t": "Salud de batería e informes PDF",
      "feat.7.d": "Capacidad estimada de la batería y control de la descarga pasiva con los criterios de Leapmotor Mate. Informes mensuales automáticos en PDF, exportables, con consumos, cargas y costes.",
      "feat.8.t": "Telemetría y consumo vs temperatura",
      "feat.8.d": "Envío de telemetría por MQTT o webhook a tu propio servidor (Home Assistant, Node-RED…), además de ABRP. Y gráficas de consumo cruzadas con la temperatura exterior de Open-Meteo para entender el invierno.",
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
      "inst.label": "04 — INSTALACIÓN", "inst.title": "Instálala en 2 pasos.",
      "inst.lead": "LMB10 ya está en producción en Google Play: descarga pública, sin grupos ni esperas. Solo queda importar tu certificado.",
      "inst.s1.t": "Instala desde Google Play",
      "inst.s1.d": "Descarga pública y oficial desde la ficha de Play — con actualizaciones automáticas y soporte de Android Auto.",
      "inst.s1.cta": "Abrir en Google Play",
      "inst.s2.t": "Importa tu certificado",
      "inst.s2.d": "Abre LMB10 y sigue Ajustes → Importar certificado: la nube de Leapmotor exige mTLS con tu propio certificado.",
      "inst.s2.cert": "🔐 Certificados: markoceri/leapmotor-certs — gracias a su autor por el material",
      "inst.beta.t": "¿Quieres probar lo próximo antes que nadie?",
      "inst.beta.d": "La prueba cerrada de Play va siempre un paso por delante: ahora mismo está en la v3.60.186 mientras la producción pública es la v3.60.179. Únete al grupo de testers y activa la prueba con la misma cuenta de Google.",
      "inst.beta.cta1": "1 · Grupo de testers",
      "inst.beta.cta2": "2 · Activar la prueba",
      "inst.alt.t": "¿Prefieres el APK directo?",
      "inst.alt.d": "Está en GitHub Releases. Ojo: las dos vías van firmadas con claves distintas — cambiar de una a otra exige exportar copia, desinstalar e importar de nuevo, y el APK no aparece en Android Auto.",
      "inst.alt.cta": "APK en GitHub",
      "badge.android.top": "Disponible para", "badge.ios.top": "Compatible con",
      "inst.ios.t": "¿Tienes iPhone? LMB10 también funciona en iOS",
      "inst.ios.d": "Cada release publica también el IPA. Como la app no está en la App Store, se instala por sideloading — suena raro, pero son diez minutos una sola vez:",
      "inst.ios.s1": "<b>Descarga el IPA</b> de la última release en GitHub (archivo <span class=\"mono\">lmb10-…-unsigned.ipa</span>).",
      "inst.ios.s2": "<b>Instala AltStore o SideStore</b> (gratis) en tu iPhone y firma el IPA con tu propio Apple ID — la app queda firmada a tu nombre, nadie más toca tus datos.",
      "inst.ios.s3": "<b>Confía en tu certificado</b>: Ajustes → General → VPN y gestión de dispositivos → confiar en tu Apple ID.",
      "inst.ios.s4": "<b>Abre LMB10 e importa tu certificado</b> de Leapmotor, igual que en Android. Con Apple ID gratuito la firma dura 7 días: AltStore la renueva solo conectando el iPhone a la misma Wi-Fi que el ordenador.",
      "inst.ios.cta": "IPA en GitHub",
      "inst.ios.credit": "🙏 Guía de instalación en iOS gracias a <b>@kbs23</b>",
      "tea.label": "DEDICATORIA",
      "tea.title": "Cada pieza encaja a su manera.",
      "tea.text": "LMB10 es un proyecto personal, hecho en casa y sin más ánimo que el de compartir. Va dedicado con cariño a las personas con autismo (TEA) y a sus familias — las piezas del puzzle recuerdan que cada quien encaja a su manera, y que todas son necesarias.",
      "tea.sign": "— SurferRule",
      "com.label": "05 — COMUNIDAD", "com.title": "El B10, en vídeo y en grupo.",
      "com.v1": "Mecánico nos enseña los bajos del LeapMotor B10",
      "com.v2": "Parte 2 — ¿Cómo es realmente por debajo? Sin desmontar nada",
      "com.credit": "Vídeos del canal de YouTube EvCanariasB10, de Dani (@EVCanariasDani), con el mecánico Pedro (@P_38_87). Publicados aquí con su permiso — gracias a ambos por su trabajo.",
      "com.thanks.t": "Gracias, LEAPMOTOR B10 CLUB",
      "com.thanks.d": "El grupo de Telegram donde nos hemos reunido los betatesters: dudas, reportes de compatibilidad y vida real con el B10. La app es mejor gracias a ellos.",
      "com.thanks.cta": "t.me/LEAPMOTORB10CLUB",
      "com.thanks2.t": "Gracias, @juanludetoledo",
      "com.thanks2.d": "Por su apoyo al proyecto y por difundir el B10. Si te interesa el coche y el mundo eléctrico, apoya su canal de YouTube.",
      "com.thanks2.cta": "youtube.com/@juanludetoledo",
      "ver.label": "06 — VERSIONES", "ver.title": "Un cambio por release, validado en coche real.",
      "ver.prod.tag": "PRODUCCIÓN",
      "ver.prod.d": "<b>Google Play:</b> v3.60.179 ya es la versión pública estable. El canal beta (prueba cerrada) va por la <b>v3.60.186</b> — aquí abajo se listan las releases de GitHub, que siguen el canal beta.",
      "ver.151": "Ventana barata PVPC: la app sugiere las horas más baratas en el programador de carga.",
      "ver.150": "Enviar destino al navegador del coche (búsqueda Nominatim, sin PIN).",
      "ver.149": "Odómetro: km totales, días desde la entrega y media diaria.",
      "ver.148": "La foto real de tu coche en el panel, servida por la nube de Leapmotor.",
      "ver.147": "Limpieza: eliminados el historial de cargas y FOTA, inertes en este modelo.",
      "ver.121": "Autonomía de reserva en modelos sin señal en vivo (confirmado en un T03).",
      "ver.all": "Historial completo en GitHub →",
      "ver.loading": "Cargando releases desde GitHub…",
      "coffee.label": "07 — APOYAR EL PROYECTO",
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
      "nav.versions": "Versions", "nav.install": "Install", "nav.community": "Community",
      "hero.kicker": "UNOFFICIAL APP · ANDROID + iOS · GPLv3",
      "hero.sub": "Your Leapmotor, under your control. Monitor and control your car from your phone with features the official app doesn't offer.",
      "hero.cta1": "Download on Google Play", "hero.cta2": "APK · IPA on GitHub",
      "hero.note": " · free · no ads · developed on a real B10",
      "notice": "✓ ANDROID AUTO — now available when installing LMB10 from Google Play.",
      "stats.v": "current version", "stats.refresh": "live refresh",
      "stats.free": "no ads, no extra accounts", "stats.gpl": "open source", "stats.mtls": "+ HMAC-SHA256 signing",
      "feat.label": "01 — FEATURES", "feat.title": "Everything your car knows, in your pocket.",
      "feat.1.t": "Live dashboard",
      "feat.1.d": "Precise battery, range, lock, charging, climate, trunk and sentry status, auto-refreshing every 90 seconds. Odometer, real-world consumption vs the manufacturer's figure, and your own car's photo served by the cloud.",
      "feat.2.t": "Full remote controls",
      "feat.2.d": "Lock, climate, heated and ventilated seats, roof, windows, trunk, speed limiter, battery preheating, charge limit and schedule editor. PIN-protected, just like the official app.",
      "feat.3.t": "Real charging costs",
      "feat.3.d": "Every AC, DC or HPC session with its power curve and its cost in euros based on your tariff (hourly PVPC from REData or flat rate). The app suggests the cheapest contiguous 2–8 hour window in the scheduler, and tracks cost per day, week and month.",
      "feat.4.t": "Destination to the car's nav",
      "feat.4.d": "Search an address and send it straight to the vehicle's navigator before leaving home. No PIN, no touching the car's screen.",
      "feat.5.t": "Routines & preconditioning",
      "feat.5.d": "Schedule climate, 80% charging, battery preheating or morning departures. They run in the background even with the app closed.",
      "feat.6.t": "Your data is yours",
      "feat.6.d": "Everything is stored encrypted on your phone; nothing goes to the developer's servers. Exportable backup (JSON + CSV) and optional daily copy to your own Google Drive.",
      "feat.7.t": "Battery health & PDF reports",
      "feat.7.d": "Estimated battery capacity and passive-drain tracking using the Leapmotor Mate criteria. Automatic monthly PDF reports, exportable, with consumption, charging sessions and costs.",
      "feat.8.t": "Telemetry & consumption vs temperature",
      "feat.8.d": "Send telemetry over MQTT or webhook to your own server (Home Assistant, Node-RED…), on top of ABRP. Plus consumption charts crossed with outdoor temperature from Open-Meteo, to understand winter.",
      "chip.widget": "Desktop widget", "chip.ticket": "Thermal printer receipts",
      "chip.sentry": "Sentry mode", "chip.odo": "Odometer", "chip.tires": "Tire pressure",
      "chip.map": "Map & location", "chip.log": "Diagnostic log",
      "shots.label": "02 — SCREENSHOTS", "shots.title": "The app, as it is.",
      "shot.0": "Your car on the dashboard",
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
      "inst.label": "04 — INSTALLATION", "inst.title": "Install it in 2 steps.",
      "inst.lead": "LMB10 is now in production on Google Play: public download, no groups, no waiting. All that's left is importing your certificate.",
      "inst.s1.t": "Install from Google Play",
      "inst.s1.d": "Public, official download from the Play listing — with automatic updates and Android Auto support.",
      "inst.s1.cta": "Open in Google Play",
      "inst.s2.t": "Import your certificate",
      "inst.s2.d": "Open LMB10 and follow Settings → Import certificate: Leapmotor's cloud requires mTLS with your own certificate.",
      "inst.s2.cert": "🔐 Certificates: markoceri/leapmotor-certs — thanks to its author for the material",
      "inst.beta.t": "Want to try what's next before anyone else?",
      "inst.beta.d": "Play's closed testing track is always one step ahead: right now it's on v3.60.186 while public production is v3.60.179. Join the testers group and enable the test with the same Google account.",
      "inst.beta.cta1": "1 · Testers group",
      "inst.beta.cta2": "2 · Enable the test",
      "inst.alt.t": "Prefer the direct APK?",
      "inst.alt.d": "It's on GitHub Releases. Note: the two channels are signed with different keys — switching means exporting a backup, uninstalling and importing again, and the APK won't appear in Android Auto.",
      "inst.alt.cta": "APK on GitHub",
      "badge.android.top": "Available for", "badge.ios.top": "Compatible with",
      "inst.ios.t": "Have an iPhone? LMB10 works on iOS too",
      "inst.ios.d": "Every release also ships the IPA. Since the app isn't on the App Store, it's installed by sideloading — sounds odd, but it's ten minutes, once:",
      "inst.ios.s1": "<b>Download the IPA</b> from the latest GitHub release (the <span class=\"mono\">lmb10-…-unsigned.ipa</span> file).",
      "inst.ios.s2": "<b>Install AltStore or SideStore</b> (free) on your iPhone and sign the IPA with your own Apple ID — the app is signed in your name, nobody else touches your data.",
      "inst.ios.s3": "<b>Trust your certificate</b>: Settings → General → VPN & Device Management → trust your Apple ID.",
      "inst.ios.s4": "<b>Open LMB10 and import your Leapmotor certificate</b>, just like on Android. With a free Apple ID the signature lasts 7 days: AltStore renews it by itself when the iPhone is on the same Wi-Fi as the computer.",
      "inst.ios.cta": "IPA on GitHub",
      "inst.ios.credit": "🙏 iOS installation guide thanks to <b>@kbs23</b>",
      "tea.label": "DEDICATION",
      "tea.title": "Every piece fits in its own way.",
      "tea.text": "LMB10 is a personal project, made at home with no goal other than sharing. It is warmly dedicated to people with autism (ASD) and their families — the puzzle pieces remind us that everyone fits in their own way, and that every piece is needed.",
      "tea.sign": "— SurferRule",
      "com.label": "05 — COMMUNITY", "com.title": "The B10, on video and as a group.",
      "com.v1": "A mechanic shows us the LeapMotor B10's underside",
      "com.v2": "Part 2 — What's it really like underneath? Without dismantling anything",
      "com.credit": "Videos from the EvCanariasB10 YouTube channel, by Dani (@EVCanariasDani), with mechanic Pedro (@P_38_87). Embedded here with their permission — thanks to both for their work.",
      "com.thanks.t": "Thank you, LEAPMOTOR B10 CLUB",
      "com.thanks.d": "The Telegram group where we beta testers have gathered: questions, compatibility reports and real life with the B10. The app is better because of them.",
      "com.thanks.cta": "t.me/LEAPMOTORB10CLUB",
      "com.thanks2.t": "Thank you, @juanludetoledo",
      "com.thanks2.d": "For supporting the project and spreading the word about the B10. If you're into the car and the EV world, support his YouTube channel.",
      "com.thanks2.cta": "youtube.com/@juanludetoledo",
      "ver.label": "06 — VERSIONS", "ver.title": "One change per release, validated on a real car.",
      "ver.prod.tag": "PRODUCTION",
      "ver.prod.d": "<b>Google Play:</b> v3.60.179 is now the stable public release. The beta channel (closed testing) is on <b>v3.60.186</b> — the GitHub releases listed below follow the beta channel.",
      "ver.151": "Cheapest PVPC window: the app suggests the cheapest hours in the charge scheduler.",
      "ver.150": "Send destination to the car's navigator (Nominatim search, no PIN).",
      "ver.149": "Odometer: total km, days since delivery and daily average.",
      "ver.148": "Your real car's photo on the dashboard, served by Leapmotor's cloud.",
      "ver.147": "Cleanup: removed charge history and FOTA, inert on this model.",
      "ver.121": "Fallback range on models without the live signal (confirmed on a T03).",
      "ver.all": "Full changelog on GitHub →",
      "ver.loading": "Loading releases from GitHub…",
      "coffee.label": "07 — SUPPORT THE PROJECT",
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
