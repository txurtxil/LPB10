#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10

cat > /tmp/notas3602.md << 'NOTEOF'
## LMB10 v3.60.2

App Android **no oficial** para el Leapmotor B10. Proyecto independiente, sin
relacion ni respaldo de Leapmotor.

### IMPORTANTE: certificado de cliente

Esta version **no incluye ni distribuye ningun material de Leapmotor**. Para
conectar con el servidor hace falta un certificado de cliente que **debes
obtener tu mismo**. Al abrir la app por primera vez te llevara a la pantalla
de importacion.

Disponible tambien en **Ajustes > Certificado de cliente** para revisarlo,
reimportarlo o borrarlo. Se guarda cifrado en el dispositivo y no se incluye
en las copias de seguridad.

### Novedades

- **Pantalla de bienvenida** en el primer arranque: aviso de app no oficial y
  sin garantia, recomendacion de usar una **cuenta secundaria** (la app
  oficial suele permitir una sola sesion activa) y nota de privacidad.
- **Privacidad**: el ticket de eficiencia ya no muestra el nombre del titular.
- **Acerca de**: version de la app visible y seccion de concienciacion sobre
  el autismo.

### Aviso

Se ofrece "tal cual", sin garantia de ningun tipo. El autor no se hace
responsable de danos al vehiculo, a la bateria, de perdida de datos ni de
incidencias con tu cuenta. Gratuita y sin animo de lucro.

---

## LMB10 v3.60.2 (EN)

Unofficial Android app for the Leapmotor B10. Independent project, not
affiliated with or endorsed by Leapmotor.

**Client certificate required**: this version bundles no Leapmotor material.
You must supply your own client certificate; the app will prompt you on first
launch (also under Settings > Client certificate).

Provided "as is", without warranty of any kind. Free and non-commercial.
NOTEOF

gh release edit v3.60.2 --notes-file /tmp/notas3602.md
echo "Notas actualizadas"

echo; echo "=== El APK publicado esta limpio? ==="
gh release download v3.60.2 -D /tmp/relcheck --clobber
unzip -l /tmp/relcheck/*.apk | grep -iE "\.p12|\.pem|\.crt|\.key|certs/" || echo "SIN CERTIFICADOS"
unzip -p /tmp/relcheck/*.apk 2>/dev/null | grep -ac "LeapmotorAppCrtCN" || echo "0 rastros"
rm -rf /tmp/relcheck

echo; echo "=== Estado final ==="
gh release view v3.60.2 --json tagName,name,url -q '"\(.tagName) | \(.name) | \(.url)"'
