/* ═══════════════ LMB10 — guía telemetría · i18n ═══════════════ */
(function () {
  "use strict";

  const I18N = {
    es: {
      "t.back": "← Volver a la web",
      "t.faq": "FAQ",
      "t.label": "GUÍA",
      "t.title": "Telemetría MQTT / webhook: tu coche, en tu servidor.",
      "t.lead": "LMB10 puede publicar el estado de tu Leapmotor en tu propio servidor — por MQTT, por webhook HTTPS, o ambos a la vez. Es opt-in (apagado por defecto), envía una lectura por minuto como máximo, y ningún dato pasa por servidores del desarrollador: va directo de tu móvil a tu casa.",
      "t.b1": "opt-in · apagado por defecto",
      "t.b2": "1 lectura / minuto",
      "t.b3": "MQTT y/o webhook HTTPS",
      "t.b4": "sin servidores de terceros",
      "t.s1.label": "01 — QUÉ ENVÍA",
      "t.s1.title": "El estado del coche, en JSON.",
      "t.s1.lead": "Cada lectura es un pequeño JSON con el estado del vehículo en ese momento. Tú decides dónde aterriza.",
      "t.s1.c1": "La app publica en un topic de tu broker (por ejemplo <span class=\"mono\">lmb10/b10</span>). Ideal con Mosquitto y Home Assistant: sensores nativos, histórico y gráficas sin escribir código de red.",
      "t.s1.c2": "La app hace un POST a la URL que indiques — un endpoint de Home Assistant, Node-RED, n8n o cualquier script tuyo. Perfecto si no quieres mantener un broker.",
      "t.s1.c3t": "Ritmo y control",
      "t.s1.c3": "Como mucho una lectura por minuto, solo cuando hay datos nuevos que contar. Se activa y se desactiva con un interruptor en Ajustes, y puedes configurar ambos canales a la vez o solo uno.",
      "t.s2.label": "02 — EN LA APP",
      "t.s2.title": "Configuración en cuatro pasos.",
      "t.s2.p1": "<b>Abre Ajustes → Telemetría</b> y activa el interruptor. Nada se envía hasta que rellenes al menos un canal.",
      "t.s2.p2": "<b>Para MQTT:</b> host y puerto de tu broker (1883 sin TLS, 8883 con TLS), topic (ej. <span class=\"mono\">lmb10/b10</span>), y usuario/contraseña si el broker los pide — que debería.",
      "t.s2.p3": "<b>Para webhook:</b> la URL HTTPS completa de tu endpoint. Opcionalmente, una cabecera de autorización para que solo tu servidor acepte los POST.",
      "t.s2.p4": "<b>Comprueba el envío de prueba</b> desde la propia pantalla: publica una lectura inmediata para validar que broker o endpoint responden antes de salir de dudas.",
      "t.s3.label": "03 — HOME ASSISTANT CON MQTT",
      "t.s3.title": "El camino recomendado.",
      "t.s3.p1": "<b>Instala el add-on Mosquitto broker</b> en Home Assistant (Ajustes → Add-ons) y arráncalo. Activa «Start on boot».",
      "t.s3.p2": "<b>Crea un usuario dedicado</b> para LMB10 (Ajustes → Personas → Usuarios → añadir, marca «solo usuario local»). No reutilices tu usuario principal.",
      "t.s3.p3": "<b>En LMB10:</b> host = IP de tu Home Assistant, puerto 1883, topic <span class=\"mono\">lmb10/b10</span>, y ese usuario/contraseña. Si HA y el móvil están en la misma red, ya está; para fuera de casa, expón el broker con TLS (puerto 8883) o una VPN como Tailscale/WireGuard — nunca 1883 abierto a internet.",
      "t.s3.p4": "<b>Declara los sensores</b> en tu <span class=\"mono\">configuration.yaml</span> (o un paquete) y reinicia HA:",
      "t.s3.note": "A partir de ahí: histórico, gráficas, automatizaciones («avísame si baja del 20 %») y lo que quieras. Los nombres de campo exactos los ves en Ajustes → Telemetría de la app.",
      "t.s4.label": "04 — HOME ASSISTANT CON WEBHOOK",
      "t.s4.title": "Sin broker: un POST y listo.",
      "t.s4.lead": "Crea una automatización con disparador webhook; HA genera una URL tipo <span class=\"mono\">/api/webhook/lmb10_b10</span>. Pon esa URL completa en la app. Un sensor de plantilla por disparador convierte cada POST en estado:",
      "t.s4.note": "Sirve igual para Node-RED (nodo «http in») o n8n (nodo Webhook). Recuerda que la URL debe ser alcanzable desde el móvil: red local si estás en casa, o HTTPS público si quieres telemetría fuera.",
      "t.s5.label": "05 — EJEMPLO DE LECTURA",
      "t.s5.title": "Así es un mensaje.",
      "t.s5.note": "Ejemplo ilustrativo: los campos disponibles y sus nombres exactos aparecen en Ajustes → Telemetría de la app, junto al envío de prueba.",
      "t.s6.label": "06 — SEGURIDAD",
      "t.s6.title": "Cuatro reglas sencillas.",
      "t.s6.p1": "<b>TLS siempre que salgas de tu red local.</b> En casa, 1883 vale; fuera, 8883 con certificado o una VPN.",
      "t.s6.p2": "<b>Usuario dedicado y contraseña única</b> para LMB10 en tu broker. Si algún día la cambias, solo afecta a esto.",
      "t.s6.p3": "<b>Tus datos no pasan por nadie más.</b> La telemetría viaja directa de tu móvil a tu servidor; el desarrollador no recibe nada, aquí ni en ninguna otra función.",
      "t.s6.p4": "<b>Apágala cuando quieras.</b> El interruptor de Ajustes corta el envío al momento, sin desinstalar nada.",
      "t.back2": "← Volver a lmb10",
      "t.foot": "LMB10 · GPLv3 · app no oficial, sin afiliación con Leapmotor"
    },
    en: {
      "t.back": "← Back to the site",
      "t.faq": "FAQ",
      "t.label": "GUIDE",
      "t.title": "MQTT / webhook telemetry: your car, on your server.",
      "t.lead": "LMB10 can publish your Leapmotor's status to your own server — over MQTT, HTTPS webhook, or both at once. It's opt-in (off by default), sends at most one reading per minute, and no data passes through the developer's servers: it goes straight from your phone to your home.",
      "t.b1": "opt-in · off by default",
      "t.b2": "1 reading / minute",
      "t.b3": "MQTT and/or HTTPS webhook",
      "t.b4": "no third-party servers",
      "t.s1.label": "01 — WHAT IT SENDS",
      "t.s1.title": "The car's status, as JSON.",
      "t.s1.lead": "Each reading is a small JSON with the vehicle's state at that moment. You decide where it lands.",
      "t.s1.c1": "The app publishes to a topic on your broker (e.g. <span class=\"mono\">lmb10/b10</span>). Ideal with Mosquitto and Home Assistant: native sensors, history and charts without writing any network code.",
      "t.s1.c2": "The app POSTs to whatever URL you set — a Home Assistant endpoint, Node-RED, n8n or any script of yours. Perfect if you don't want to run a broker.",
      "t.s1.c3t": "Pace and control",
      "t.s1.c3": "At most one reading per minute, only when there's new data worth sending. It turns on and off with a switch in Settings, and you can configure both channels at once or just one.",
      "t.s2.label": "02 — IN THE APP",
      "t.s2.title": "Setup in four steps.",
      "t.s2.p1": "<b>Open Settings → Telemetry</b> and flip the switch. Nothing is sent until you fill in at least one channel.",
      "t.s2.p2": "<b>For MQTT:</b> your broker's host and port (1883 without TLS, 8883 with TLS), topic (e.g. <span class=\"mono\">lmb10/b10</span>), and username/password if the broker asks for them — which it should.",
      "t.s2.p3": "<b>For webhook:</b> the full HTTPS URL of your endpoint. Optionally, an authorization header so only your server accepts the POSTs.",
      "t.s2.p4": "<b>Use the test send</b> on that same screen: it publishes a reading immediately to validate that the broker or endpoint responds before you start troubleshooting.",
      "t.s3.label": "03 — HOME ASSISTANT WITH MQTT",
      "t.s3.title": "The recommended path.",
      "t.s3.p1": "<b>Install the Mosquitto broker add-on</b> in Home Assistant (Settings → Add-ons) and start it. Enable “Start on boot”.",
      "t.s3.p2": "<b>Create a dedicated user</b> for LMB10 (Settings → People → Users → add, tick “local user only”). Don't reuse your main user.",
      "t.s3.p3": "<b>In LMB10:</b> host = your Home Assistant IP, port 1883, topic <span class=\"mono\">lmb10/b10</span>, and that username/password. If HA and the phone are on the same network, you're done; for away-from-home, expose the broker with TLS (port 8883) or a VPN like Tailscale/WireGuard — never leave 1883 open to the internet.",
      "t.s3.p4": "<b>Declare the sensors</b> in your <span class=\"mono\">configuration.yaml</span> (or a package) and restart HA:",
      "t.s3.note": "From there: history, charts, automations (“tell me if it drops below 20%”) and whatever you like. The exact field names are shown in Settings → Telemetry in the app.",
      "t.s4.label": "04 — HOME ASSISTANT WITH WEBHOOK",
      "t.s4.title": "No broker: one POST and done.",
      "t.s4.lead": "Create an automation with a webhook trigger; HA generates a URL like <span class=\"mono\">/api/webhook/lmb10_b10</span>. Put that full URL in the app. A trigger-based template sensor turns each POST into state:",
      "t.s4.note": "Works just the same for Node-RED (“http in” node) or n8n (Webhook node). Remember the URL must be reachable from the phone: local network when you're home, or public HTTPS if you want telemetry on the road.",
      "t.s5.label": "05 — SAMPLE READING",
      "t.s5.title": "This is what a message looks like.",
      "t.s5.note": "Illustrative example: the available fields and their exact names are shown in Settings → Telemetry in the app, next to the test send.",
      "t.s6.label": "06 — SECURITY",
      "t.s6.title": "Four simple rules.",
      "t.s6.p1": "<b>TLS whenever you leave your local network.</b> At home, 1883 is fine; outside, 8883 with a certificate or a VPN.",
      "t.s6.p2": "<b>Dedicated user and unique password</b> for LMB10 on your broker. If you ever change it, only this is affected.",
      "t.s6.p3": "<b>Your data passes through nobody else.</b> Telemetry travels straight from your phone to your server; the developer receives nothing, here or in any other feature.",
      "t.s6.p4": "<b>Turn it off whenever you like.</b> The Settings switch stops sending instantly, without uninstalling anything.",
      "t.back2": "← Back to lmb10",
      "t.foot": "LMB10 · GPLv3 · unofficial app, not affiliated with Leapmotor"
    }
  };

  const html = document.documentElement;
  const toggle = document.getElementById("langToggle");

  function setLang(lang) {
    const dict = I18N[lang] || I18N.es;
    html.lang = lang;
    document.title = lang === "en"
      ? "LMB10 — Guide: MQTT / webhook telemetry"
      : "LMB10 — Guía: telemetría MQTT / webhook";
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
})();
