#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
cp $K/ChargersScreen.kt backups_widget/ChargersScreen.kt.bak_$TS
echo "[i] Backup en *.bak_$TS"

python3 - <<'PYEOF'
import io, sys
p = "android/app/src/main/kotlin/com/txurtxil/lpb10/ChargersScreen.kt"
s = io.open(p, encoding='utf-8').read()

# 1. Añadir imports para el mapa
old_imports = '''import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template'''
new_imports = '''import androidx.car.app.model.CarColor
import androidx.car.app.model.CarIcon
import androidx.car.app.model.CarLocation
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Metadata
import androidx.car.app.model.Place
import androidx.car.app.model.PlaceListMapTemplate
import androidx.car.app.model.PlaceMarker
import androidx.car.app.model.Row
import androidx.car.app.model.Template'''
if s.count(old_imports) != 1:
    sys.exit("ABORT: ancla imports x%d" % s.count(old_imports))
s = s.replace(old_imports, new_imports, 1)

# 2. Reemplazar onGetTemplate para usar PlaceListMapTemplate
old_tmpl = '''    override fun onGetTemplate(): Template {
        if (loading) {
            return ListTemplate.Builder()
                .setLoading(true)
                .setTitle("Cargadores")
                .setHeaderAction(Action.BACK)
                .build()
        }

        val list = ItemList.Builder()
        val msg = errorMsg
        if (msg != null) {
            list.setNoItemsMessage(msg)
        } else {
            for (c in chargers) {
                val km = String.format("%.1f km", c.distM / 1000f)
                val sub = if (c.info.isNotEmpty()) "$km · ${c.info}" else km
                list.addItem(
                    Row.Builder()
                        .setTitle(c.name)
                        .addText(sub)
                        .setOnClickListener { navigate(c) }
                        .build()
                )
            }
        }

        return ListTemplate.Builder()
            .setSingleList(list.build())
            .setTitle("Cargadores")
            .setHeaderAction(Action.BACK)
            .build()
    }'''

new_tmpl = '''    override fun onGetTemplate(): Template {
        if (loading) {
            return PlaceListMapTemplate.Builder()
                .setLoading(true)
                .setTitle("Cargadores")
                .setHeaderAction(Action.BACK)
                .build()
        }

        val list = ItemList.Builder()
        val msg = errorMsg
        if (msg != null) {
            list.setNoItemsMessage(msg)
        } else {
            for ((idx, c) in chargers.withIndex()) {
                val km = String.format("%.1f km", c.distM / 1000f)
                val sub = if (c.info.isNotEmpty()) "$km · ${c.info}" else km
                // Marcador numerado en el mapa para cada cargador
                val marker = PlaceMarker.Builder()
                    .setLabel((idx + 1).toString())
                    .setColor(CarColor.GREEN)
                    .build()
                val place = Place.Builder(CarLocation.create(c.lat, c.lon))
                    .setMarker(marker)
                    .build()
                list.addItem(
                    Row.Builder()
                        .setTitle(c.name)
                        .addText(sub)
                        .setOnClickListener { navigate(c) }
                        .setMetadata(Metadata.Builder().setPlace(place).build())
                        .build()
                )
            }
        }

        return PlaceListMapTemplate.Builder()
            .setItemList(list.build())
            .setTitle("Cargadores")
            .setHeaderAction(Action.BACK)
            .build()
    }'''

if s.count(old_tmpl) != 1:
    sys.exit("ABORT: ancla onGetTemplate x%d" % s.count(old_tmpl))
s = s.replace(old_tmpl, new_tmpl, 1)

io.open(p, 'w', encoding='utf-8').write(s)
print("[ok] ChargersScreen: PlaceListMapTemplate con marcadores")
PYEOF

echo "[i] Verificacion:"
echo -n "  PlaceListMapTemplate (debe ser >=2): "; grep -c "PlaceListMapTemplate" $K/ChargersScreen.kt
echo -n "  marcadores Place (1): "; grep -c "CarLocation.create" $K/ChargersScreen.kt
echo -n "  Metadata setPlace (1): "; grep -c "setPlace" $K/ChargersScreen.kt
