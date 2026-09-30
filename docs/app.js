/* ═══════════════ LMB10 — i18n + motion ═══════════════ */
(function () {
  "use strict";

  /* ── Diccionario ─────────────────────────────────── */
  const I18N = {
    es: {
      "skip": "Saltar al contenido",
      "nav.features": "Funciones", "nav.shots": "Capturas", "nav.compat": "Compatibilidad",
      "nav.versions": "Versiones", "nav.install": "Instalar", "nav.community": "Comunidad", "nav.faq": "FAQ",
      "hero.kicker": "APP NO OFICIAL · ANDROID + iOS · GPLv3",
      "hero.sub": "Tu Leapmotor, bajo tu control. Monitoriza y controla tu coche desde tu móvil con funciones que la app oficial no ofrece.",
      "hero.cta1": "Descargar en Google Play", "hero.cta2": "APK · IPA en GitHub",
      "hero.note": " · gratis · sin anuncios · desarrollada sobre un B10 real",
      "notice": "ⓘ ANDROID AUTO — la producción (3.60.353 «lite») no lo incluye temporalmente, a la espera de la revisión de Play. La prueba abierta 3.60.358 sí lo trae, con «Cargadores cerca» y búsqueda de destinos.",
      "stats.v": "versión actual", "stats.refresh": "refresco en vivo",
      "stats.free": "sin anuncios ni cuentas extra", "stats.gpl": "código abierto", "stats.mtls": "+ firma HMAC-SHA256",
      "feat.label": "01 — FUNCIONES", "feat.title": "Todo lo que tu coche sabe, en tu bolsillo.",
      "feat.1.t": "Panel en vivo",
      "feat.1.d": "Batería precisa, autonomía, cerradura, carga, clima, maletero y centinela, con refresco automático cada 90 segundos. Odómetro, consumo real frente al dato del fabricante y la foto de tu propio coche servida por la nube.",
      "feat.2.t": "Controles remotos completos",
      "feat.2.d": "Bloqueo, climatización, asientos calefactados y ventilados, techo, ventanillas, maletero, limitador de velocidad, precalentado de batería, límite de carga y programación horaria. Con PIN, igual que la app oficial.",
      "feat.3.t": "Costes de carga reales",
      "feat.3.d": "Cada sesión AC, DC o HPC con su curva de potencia y su coste en euros según tu tarifa: PVPC horario REData, precio fijo o tarifa de 3 tramos 2.0TD (punta/llano/valle — la app reparte cada carga por la franja horaria en que ocurrió). Sugiere la ventana contigua más barata de 2 a 8 horas en el programador y acumula coste por día, semana y mes.",
      "feat.4.t": "Destino al navegador del coche",
      "feat.4.d": "Busca una dirección y envíala directamente al navegador del vehículo antes de salir de casa. Sin PIN y sin tocar la pantalla del coche.",
      "feat.5.t": "Rutinas y precondicionado",
      "feat.5.d": "Programa climatización, carga al 80 %, precalentado de batería o salidas matutinas. Se ejecutan en segundo plano aunque la app esté cerrada.",
      "feat.6.t": "Tus datos son tuyos",
      "feat.6.d": "Todo se guarda cifrado en tu teléfono; nada va a servidores del desarrollador. Copia de seguridad exportable (JSON + CSV) y copia diaria opcional en tu propio Google Drive.",
      "feat.7.t": "Salud de batería e informes PDF",
      "feat.7.d": "Capacidad estimada de la batería y control de la descarga pasiva con los criterios de Leapmotor Mate. Informe de consumo unificado —7 días, 30 días, todo o un rango a elegir— en PDF a color y en ticket de impresora térmica, con consumos, cargas y costes.",
      "feat.8.t": "Telemetría y consumo vs temperatura",
      "feat.8.d": "Envío opt-in de una lectura por minuto por MQTT o webhook HTTPS a tu propio servidor (Home Assistant, Node-RED…), además de ABRP. Guía paso a paso: <a href=\"telemetria.html\">telemetría MQTT/webhook</a>. Y gráficas de consumo cruzadas con la temperatura exterior de Open-Meteo para entender el invierno.",
      "feat.9.t": "Notificaciones configurables", "feat.9.d": "Siete avisos independientes en Ajustes → Notificaciones: carga completada, cambios de estado del coche, alertas de centinela, resúmenes diarios… Eliges qué te interesa y qué queda en silencio.",
      "chip.widget": "Widget de escritorio", "chip.ticket": "Tickets en impresora térmica",
      "chip.sentry": "Modo centinela", "chip.odo": "Odómetro", "chip.tires": "Presión de neumáticos",
      "chip.map": "Mapa y ubicación", "chip.log": "Log de diagnóstico",
      "shots.label": "02 — CAPTURAS", "shots.title": "La app, tal como es.",
      "shot.1": "Panel principal", "shot.2": "Controles remotos", "shot.3": "Confort y batería",
      "shot.4": "Rutinas", "shot.5": "Consumo y coste", "shot.6": "Precio de la luz",
      "shot.7": "Ticket de eficiencia", "shot.8": "Widget", "shot.9": "Salud de batería", "shot.10": "Descarga pasiva",
      "compat.label": "03 — COMPATIBILIDAD", "compat.title": "Confirmado en coches reales, no en teoría.",
      "compat.lead": "Desarrollada y probada a diario sobre un B10, y confirmada en B11 y en T03/B03X por usuarios reales. El login y el protocolo funcionan en toda la gama Leapmotor; el resto crece con cada persona que reporta.",
      "compat.feat": "Función",
      "c.1": "Batería y autonomía", "c.2": "Presión de neumáticos", "c.3": "Cerradura, maletero y clima",
      "c.4": "Ubicación GPS y odómetro", "c.5": "Telemetría ABRP", "c.6": "Controles remotos",
      "c.untested": "sin probar",
      "compat.note": "T03/B03X: soportado desde la v3.60.208 (la app prueba varias rutas de estado y usa la que responde). Matices: la detección de conducción por Bluetooth está limitada en Android 12+ por ahora, y algunas señales exclusivas del B10 pueden no existir en estos modelos. Los híbridos de autonomía extendida (C10 REEV) no están soportados. ¿Tienes un C10 o un B05? Tu reporte completa esta tabla.",
      "inst.label": "04 — INSTALACIÓN", "inst.title": "Instálala en 2 pasos.",
      "inst.lead": "LMB10 ya está en producción en Google Play: descarga pública, sin grupos ni esperas. Solo queda importar tu certificado.",
      "inst.s1.t": "Instala desde Google Play",
      "inst.s1.d": "Descarga pública y oficial desde la ficha de Play, con actualizaciones automáticas. (Android Auto y Bluetooth llegan con la versión completa — ver «prueba abierta» más abajo.)",
      "inst.s1.cta": "Abrir en Google Play",
      "inst.s2.t": "Importa tu certificado",
      "inst.s2.d": "Abre LMB10 y sigue Ajustes → Importar certificado: la nube de Leapmotor exige mTLS con tu propio certificado.",
      "inst.s2.cert": "🔐 Certificados: markoceri/leapmotor-certs — gracias a su autor por el material",
      "inst.beta.t": "¿Quieres la app completa? Prueba abierta",
      "inst.beta.d": "La producción es ahora la 3.60.353 «lite» (sin Android Auto ni Bluetooth, temporalmente). La prueba abierta lleva la 3.60.358 completa — entras con un clic, sin grupo ni aprobación, y puedes salir cuando quieras. La antigua prueba cerrada queda congelada.",
      "inst.beta.cta1": "Unirme a la prueba abierta",
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
      "faq.label": "05 — FAQ", "faq.title": "Preguntas frecuentes.",
      "faq.q1": "¿Producción, prueba abierta, prueba cerrada… cuál instalo?",
      "faq.a1": "<b>Producción</b> (3.60.353 «lite») es la versión pública estable; temporalmente no incluye Android Auto ni Bluetooth. La <b>prueba abierta</b> (3.60.358) lleva la app completa y puede entrar cualquiera. La <b>prueba cerrada</b> queda congelada: se acumularon releases en revisión y todo se migra a la abierta. Si quieres Auto y Bluetooth hoy, únete a la abierta.",
      "faq.q2": "¿Cómo entro en la prueba abierta?",
      "faq.a2": "Abre <a class=\"text-link cert-link\" href=\"https://play.google.com/apps/testing/com.txurtxil.lpb10\" target=\"_blank\" rel=\"noopener\">play.google.com/apps/testing/com.txurtxil.lpb10</a> con tu cuenta de Google y pulsa unirte. En unos minutos, Play te ofrece la actualización a la versión completa. Salir es igual de fácil, desde el mismo enlace.",
      "faq.q3": "¿Qué es la versión «lite» de producción?",
      "faq.a3": "La misma app menos dos cosas: Android Auto y el permiso Bluetooth (ese permiso obliga a una revisión con vídeo en Play que llevaba semanas bloqueando la publicación). Es temporal: cuando Play complete la revisión, producción recibirá la versión completa. Mientras tanto, la completa está en la prueba abierta.",
      "faq.q4": "Transparencia: ¿qué NO hace la app?",
      "faq.a4": "Los widgets de escritorio <b>no abren el coche</b> — son de consulta. Y Android Auto <b>no muestra datos del vehículo</b> (batería, clima, autonomía…): la política de Google no lo permite en apps de terceros, solo puntos de interés y navegación — por eso Auto ofrece «Cargadores cerca» y búsqueda de destinos.",
      "faq.q5": "¿Qué coches son compatibles?",
      "faq.a5": "<b>B10 y B11</b>, completos. <b>T03/B03X</b> desde la v3.60.208, con matices: la detección de conducción por Bluetooth está limitada en Android 12+ y algunas señales exclusivas del B10 pueden no existir. C10 y B05, sin confirmar — tu reporte ayuda. C10 REEV (autonomía extendida) no está soportado.",
      "faq.q6": "¿Puedo enviar la telemetría a mi Home Assistant?",
      "faq.a6": "Sí: por MQTT o webhook HTTPS, es opt-in y envía una lectura por minuto a tu propio servidor. Guía paso a paso con ejemplos para Home Assistant: <a class=\"text-link cert-link\" href=\"telemetria.html\">telemetría MQTT/webhook →</a>",
      "tea.label": "DEDICATORIA",
      "tea.title": "Cada pieza encaja a su manera.",
      "tea.text": "LMB10 es un proyecto personal, hecho en casa y sin más ánimo que el de compartir. Va dedicado con cariño a las personas con autismo (TEA) y a sus familias — las piezas del puzzle recuerdan que cada quien encaja a su manera, y que todas son necesarias.",
      "tea.sign": "— SurferRule",
      "com.label": "06 — COMUNIDAD", "com.title": "El B10, en vídeo y en grupo.",
      "com.v1": "Mecánico nos enseña los bajos del LeapMotor B10",
      "com.v2": "Parte 2 — ¿Cómo es realmente por debajo? Sin desmontar nada",
      "com.credit": "Vídeos del canal de YouTube EvCanariasB10, de Dani (@EVCanariasDani), con el mecánico Pedro (@P_38_87). Publicados aquí con su permiso — gracias a ambos por su trabajo.",
      "com.thanks.t": "Gracias, LEAPMOTOR B10 CLUB",
      "com.thanks.d": "El grupo de Telegram donde nos hemos reunido los betatesters: dudas, reportes de compatibilidad y vida real con el B10. La app es mejor gracias a ellos.",
      "com.thanks.cta": "t.me/LEAPMOTORB10CLUB",
      "com.thanks2.t": "Gracias, @juanludetoledo",
      "com.thanks2.d": "Por su apoyo al proyecto y por difundir el B10. Si te interesa el coche y el mundo eléctrico, apoya su canal de YouTube.",
      "com.thanks2.cta": "youtube.com/@juanludetoledo",
      "ver.label": "07 — VERSIONES", "ver.title": "Un cambio por release, validado en coche real.",
      "ver.prod.tag": "PRODUCCIÓN",
      "ver.prod.d": "<b>Google Play:</b> v3.60.353 «lite» (sin Android Auto ni Bluetooth, temporalmente). <b>Prueba abierta:</b> v3.60.358 completa. Abajo se listan las releases públicas de GitHub.",
      "ver.151": "Ventana barata PVPC: la app sugiere las horas más baratas en el programador de carga.",
      "ver.150": "Enviar destino al navegador del coche (búsqueda Nominatim, sin PIN).",
      "ver.149": "Odómetro: km totales, días desde la entrega y media diaria.",
      "ver.148": "La foto real de tu coche en el panel, servida por la nube de Leapmotor.",
      "ver.147": "Limpieza: eliminados el historial de cargas y FOTA, inertes en este modelo.",
      "ver.121": "Autonomía de reserva en modelos sin señal en vivo (confirmado en un T03).",
      "ver.all": "Historial completo en GitHub →",
      "ver.loading": "Cargando releases desde GitHub…",
      "coffee.label": "08 — APOYAR EL PROYECTO",
      "coffee.title": "Gratis siempre.<br>Si te sirve, invítame a un café.",
      "coffee.lead": "Sin anuncios, sin suscripciones, sin más cuentas que las tuyas. El café es totalmente opcional — nunca hace falta para ser tester ni para usar nada.",
      "coffee.cta": "☕ ko-fi.com/txurtxil",
      "foot.by": "por SurferRule · @txurtxil",
      "foot.project": "PROYECTO", "foot.releases": "Releases", "foot.group": "Grupo de testers",
      "foot.privacy": "Privacidad", "foot.credits": "CRÉDITOS", "foot.legal": "LEGAL",
      "foot.tele": "Telemetría MQTT/webhook",
      "foot.license": "Licencia GNU GPLv3. Proyecto personal, experimental y sin ánimo de lucro, con fines de interoperabilidad e investigación (EU Data Act).",
      "foot.disclaimer": "App no oficial e independiente. No afiliada ni respaldada por Leapmotor. Úsala bajo tu responsabilidad; se recomienda una cuenta secundaria."
    },
    en: {
      "skip": "Skip to content",
      "nav.features": "Features", "nav.shots": "Screenshots", "nav.compat": "Compatibility",
      "nav.versions": "Versions", "nav.install": "Install", "nav.community": "Community", "nav.faq": "FAQ",
      "hero.kicker": "UNOFFICIAL APP · ANDROID + iOS · GPLv3",
      "hero.sub": "Your Leapmotor, under your control. Monitor and control your car from your phone with features the official app doesn't offer.",
      "hero.cta1": "Download on Google Play", "hero.cta2": "APK · IPA on GitHub",
      "hero.note": " · free · no ads · developed on a real B10",
      "notice": "ⓘ ANDROID AUTO — the production build (3.60.353 “lite”) doesn't include it for now, pending Play's review. The open testing track 3.60.358 does, with “Chargers nearby” and destination search.",
      "stats.v": "current version", "stats.refresh": "live refresh",
      "stats.free": "no ads, no extra accounts", "stats.gpl": "open source", "stats.mtls": "+ HMAC-SHA256 signing",
      "feat.label": "01 — FEATURES", "feat.title": "Everything your car knows, in your pocket.",
      "feat.1.t": "Live dashboard",
      "feat.1.d": "Precise battery, range, lock, charging, climate, trunk and sentry status, auto-refreshing every 90 seconds. Odometer, real-world consumption vs the manufacturer's figure, and your own car's photo served by the cloud.",
      "feat.2.t": "Full remote controls",
      "feat.2.d": "Lock, climate, heated and ventilated seats, roof, windows, trunk, speed limiter, battery preheating, charge limit and schedule editor. PIN-protected, just like the official app.",
      "feat.3.t": "Real charging costs",
      "feat.3.d": "Every AC, DC or HPC session with its power curve and its cost in euros per your tariff: hourly PVPC from REData, flat price or a three-band 2.0TD tariff (peak/shoulder/off-peak — the app splits each charge across the time bands it spanned). It suggests the cheapest contiguous 2–8 h window in the scheduler and tracks cost per day, week and month.",
      "feat.4.t": "Destination to the car's nav",
      "feat.4.d": "Search an address and send it straight to the vehicle's navigator before leaving home. No PIN, no touching the car's screen.",
      "feat.5.t": "Routines & preconditioning",
      "feat.5.d": "Schedule climate, 80% charging, battery preheating or morning departures. They run in the background even with the app closed.",
      "feat.6.t": "Your data is yours",
      "feat.6.d": "Everything is stored encrypted on your phone; nothing goes to the developer's servers. Exportable backup (JSON + CSV) and optional daily copy to your own Google Drive.",
      "feat.7.t": "Battery health & PDF reports",
      "feat.7.d": "Estimated battery capacity and passive-drain tracking using the Leapmotor Mate criteria. Unified consumption report —7 days, 30 days, all time or any custom range— as a colour PDF and a thermal-printer receipt, with consumption, charging sessions and costs.",
      "feat.8.t": "Telemetry & consumption vs temperature",
      "feat.8.d": "Opt-in sending of one reading per minute over MQTT or HTTPS webhook to your own server (Home Assistant, Node-RED…), on top of ABRP. Step-by-step guide: <a href=\"telemetria.html\">MQTT/webhook telemetry</a>. Plus consumption charts crossed with outdoor temperature from Open-Meteo, to understand winter.",
      "feat.9.t": "Customisable notifications", "feat.9.d": "Seven independent alerts in Settings → Notifications: charge complete, car state changes, sentry alerts, daily summaries… You choose what pings and what stays silent.",
      "chip.widget": "Desktop widget", "chip.ticket": "Thermal printer receipts",
      "chip.sentry": "Sentry mode", "chip.odo": "Odometer", "chip.tires": "Tire pressure",
      "chip.map": "Map & location", "chip.log": "Diagnostic log",
      "shots.label": "02 — SCREENSHOTS", "shots.title": "The app, as it is.",
      "shot.1": "Dashboard", "shot.2": "Remote controls", "shot.3": "Comfort & battery",
      "shot.4": "Routines", "shot.5": "Consumption & cost", "shot.6": "Electricity price",
      "shot.7": "Efficiency receipt", "shot.8": "Widget", "shot.9": "Battery health", "shot.10": "Passive drain",
      "compat.label": "03 — COMPATIBILITY", "compat.title": "Confirmed on real cars, not in theory.",
      "compat.lead": "Developed and daily-driven on a B10, and confirmed on B11 and T03/B03X by real users. Login and protocol work across the Leapmotor range; the rest grows with every report.",
      "compat.feat": "Feature",
      "c.1": "Battery & range", "c.2": "Tire pressure", "c.3": "Lock, trunk & climate",
      "c.4": "GPS location & odometer", "c.5": "ABRP telemetry", "c.6": "Remote controls",
      "c.untested": "untested",
      "compat.note": "T03/B03X: supported since v3.60.208 (the app tries several status routes and uses the one that answers). Caveats: Bluetooth-based driving detection is limited on Android 12+ for now, and some B10-exclusive signals may not exist on these models. Range-extender hybrids (C10 REEV) are not supported. Have a C10 or a B05? Your report completes this table.",
      "inst.label": "04 — INSTALLATION", "inst.title": "Install it in 2 steps.",
      "inst.lead": "LMB10 is now in production on Google Play: public download, no groups, no waiting. All that's left is importing your certificate.",
      "inst.s1.t": "Install from Google Play",
      "inst.s1.d": "Public, official download from the Play listing, with automatic updates. (Android Auto and Bluetooth come with the full version — see “open testing” below.)",
      "inst.s1.cta": "Open in Google Play",
      "inst.s2.t": "Import your certificate",
      "inst.s2.d": "Open LMB10 and follow Settings → Import certificate: Leapmotor's cloud requires mTLS with your own certificate.",
      "inst.s2.cert": "🔐 Certificates: markoceri/leapmotor-certs — thanks to its author for the material",
      "inst.beta.t": "Want the full app? Open testing",
      "inst.beta.d": "Production is now 3.60.353 “lite” (no Android Auto or Bluetooth, temporarily). Open testing carries the full 3.60.358 — one click to join, no group, no approval, and you can leave anytime. The old closed testing track is frozen.",
      "inst.beta.cta1": "Join open testing",
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
      "faq.label": "05 — FAQ", "faq.title": "Frequently asked questions.",
      "faq.q1": "Production, open testing, closed testing… which one do I install?",
      "faq.a1": "<b>Production</b> (3.60.353 “lite”) is the stable public release; for now it lacks Android Auto and Bluetooth. <b>Open testing</b> (3.60.358) carries the full app and anyone can join. <b>Closed testing</b> is frozen: releases piled up in review and everything is moving to the open track. If you want Auto and Bluetooth today, join open testing.",
      "faq.q2": "How do I join open testing?",
      "faq.a2": "Open <a class=\"text-link cert-link\" href=\"https://play.google.com/apps/testing/com.txurtxil.lpb10\" target=\"_blank\" rel=\"noopener\">play.google.com/apps/testing/com.txurtxil.lpb10</a> with your Google account and tap join. Within minutes, Play offers you the update to the full version. Leaving is just as easy, from the same link.",
      "faq.q3": "What is the “lite” production version?",
      "faq.a3": "The same app minus two things: Android Auto and the Bluetooth permission (that permission forces a video review on Play that had been blocking publication for weeks). It's temporary: once Play completes the review, production will get the full version. Meanwhile, the full build is on open testing.",
      "faq.q4": "Transparency: what does the app NOT do?",
      "faq.a4": "Home-screen widgets <b>don't unlock the car</b> — they're read-only. And Android Auto <b>doesn't show vehicle data</b> (battery, climate, range…): Google's policy doesn't allow it for third-party apps, only points of interest and navigation — that's why Auto offers “Chargers nearby” and destination search.",
      "faq.q5": "Which cars are compatible?",
      "faq.a5": "<b>B10 and B11</b>, fully. <b>T03/B03X</b> since v3.60.208, with caveats: Bluetooth-based driving detection is limited on Android 12+, and some B10-exclusive signals may not exist. C10 and B05, unconfirmed — your report helps. C10 REEV (range extender) is not supported.",
      "faq.q6": "Can I send telemetry to my Home Assistant?",
      "faq.a6": "Yes: over MQTT or HTTPS webhook, it's opt-in and sends one reading per minute to your own server. Step-by-step guide with Home Assistant examples: <a class=\"text-link cert-link\" href=\"telemetria.html\">MQTT/webhook telemetry →</a>",
      "tea.label": "DEDICATION",
      "tea.title": "Every piece fits in its own way.",
      "tea.text": "LMB10 is a personal project, made at home with no goal other than sharing. It is warmly dedicated to people with autism (ASD) and their families — the puzzle pieces remind us that everyone fits in their own way, and that every piece is needed.",
      "tea.sign": "— SurferRule",
      "com.label": "06 — COMMUNITY", "com.title": "The B10, on video and as a group.",
      "com.v1": "A mechanic shows us the LeapMotor B10's underside",
      "com.v2": "Part 2 — What's it really like underneath? Without dismantling anything",
      "com.credit": "Videos from the EvCanariasB10 YouTube channel, by Dani (@EVCanariasDani), with mechanic Pedro (@P_38_87). Embedded here with their permission — thanks to both for their work.",
      "com.thanks.t": "Thank you, LEAPMOTOR B10 CLUB",
      "com.thanks.d": "The Telegram group where we beta testers have gathered: questions, compatibility reports and real life with the B10. The app is better because of them.",
      "com.thanks.cta": "t.me/LEAPMOTORB10CLUB",
      "com.thanks2.t": "Thank you, @juanludetoledo",
      "com.thanks2.d": "For supporting the project and spreading the word about the B10. If you're into the car and the EV world, support his YouTube channel.",
      "com.thanks2.cta": "youtube.com/@juanludetoledo",
      "ver.label": "07 — VERSIONS", "ver.title": "One change per release, validated on a real car.",
      "ver.prod.tag": "PRODUCTION",
      "ver.prod.d": "<b>Google Play:</b> v3.60.353 “lite” (no Android Auto or Bluetooth, temporarily). <b>Open testing:</b> full v3.60.358. The public GitHub releases are listed below.",
      "ver.151": "Cheapest PVPC window: the app suggests the cheapest hours in the charge scheduler.",
      "ver.150": "Send destination to the car's navigator (Nominatim search, no PIN).",
      "ver.149": "Odometer: total km, days since delivery and daily average.",
      "ver.148": "Your real car's photo on the dashboard, served by Leapmotor's cloud.",
      "ver.147": "Cleanup: removed charge history and FOTA, inert on this model.",
      "ver.121": "Fallback range on models without the live signal (confirmed on a T03).",
      "ver.all": "Full changelog on GitHub →",
      "ver.loading": "Loading releases from GitHub…",
      "coffee.label": "08 — SUPPORT THE PROJECT",
      "coffee.title": "Free forever.<br>If it's useful, buy me a coffee.",
      "coffee.lead": "No ads, no subscriptions, no accounts beyond your own. The coffee is entirely optional — never required to be a tester or to use anything.",
      "coffee.cta": "☕ ko-fi.com/txurtxil",
      "foot.by": "by SurferRule · @txurtxil",
      "foot.project": "PROJECT", "foot.releases": "Releases", "foot.group": "Testers group",
      "foot.privacy": "Privacy", "foot.credits": "CREDITS", "foot.legal": "LEGAL",
      "foot.tele": "MQTT/webhook telemetry",
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
