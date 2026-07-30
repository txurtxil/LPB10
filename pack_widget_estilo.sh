set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
D=android/app/src/main/res/drawable
cp android/app/src/main/res/layout/quick_widget.xml "backups_widget/quick_widget.xml.bak_$TS"
cp "$K/QuickWidgetProvider.kt" "backups_widget/QuickWidgetProvider.kt.bak_$TS"
mkdir -p "$D"

cat > "$D/qw_bg.xml" << 'X'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#F0121820" />
    <corners android:radius="26dp" />
</shape>
X

cat > "$D/qw_btn.xml" << 'X'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#22344A" />
    <corners android:radius="16dp" />
    <stroke android:width="1dp" android:color="#33FFFFFF" />
</shape>
X

cat > "$D/qw_btn_warn.xml" << 'X'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#3D2B16" />
    <corners android:radius="16dp" />
    <stroke android:width="1dp" android:color="#55E9A23B" />
</shape>
X

cat > "$D/qw_ic_lock.xml" << 'X'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24">
    <path android:fillColor="#FFFFFF" android:pathData="M18,8h-1V6c0,-2.76 -2.24,-5 -5,-5S7,3.24 7,6v2H6c-1.1,0 -2,0.9 -2,2v10c0,1.1 0.9,2 2,2h12c1.1,0 2,-0.9 2,-2V10c0,-1.1 -0.9,-2 -2,-2zM9,6c0,-1.66 1.34,-3 3,-3s3,1.34 3,3v2H9V6zM18,20H6V10h12v10zM12,17c1.1,0 2,-0.9 2,-2s-0.9,-2 -2,-2 -2,0.9 -2,2 0.9,2 2,2z"/>
</vector>
X

cat > "$D/qw_ic_unlock.xml" << 'X'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24">
    <path android:fillColor="#FFFFFF" android:pathData="M12,17c1.1,0 2,-0.9 2,-2s-0.9,-2 -2,-2 -2,0.9 -2,2 0.9,2 2,2zM18,8h-1V6c0,-2.76 -2.24,-5 -5,-5S7,3.24 7,6h2c0,-1.66 1.34,-3 3,-3s3,1.34 3,3v2H6c-1.1,0 -2,0.9 -2,2v10c0,1.1 0.9,2 2,2h12c1.1,0 2,-0.9 2,-2V10c0,-1.1 -0.9,-2 -2,-2zM18,20H6V10h12v10z"/>
</vector>
X

cat > "$D/qw_ic_clima.xml" << 'X'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24">
    <path android:fillColor="#FFFFFF" android:pathData="M12,11c0.55,0 1,-0.45 1,-1V4c0,-0.55 -0.45,-1 -1,-1s-1,0.45 -1,1v6c0,0.55 0.45,1 1,1zM12,13c-0.55,0 -1,0.45 -1,1v6c0,0.55 0.45,1 1,1s1,-0.45 1,-1v-6c0,-0.55 -0.45,-1 -1,-1zM11,12c0,-0.55 -0.45,-1 -1,-1H4c-0.55,0 -1,0.45 -1,1s0.45,1 1,1h6c0.55,0 1,-0.45 1,-1zM20,11h-6c-0.55,0 -1,0.45 -1,1s0.45,1 1,1h6c0.55,0 1,-0.45 1,-1s-0.45,-1 -1,-1z"/>
</vector>
X

cat > "$D/qw_ic_trunk.xml" << 'X'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24">
    <path android:fillColor="#FFFFFF" android:pathData="M20,10h-1.5l-1.6,-4.6C16.7,4.6 15.9,4 15,4H9c-0.9,0 -1.7,0.6 -1.9,1.4L5.5,10H4c-0.55,0 -1,0.45 -1,1s0.45,1 1,1h1v6c0,0.55 0.45,1 1,1h1c0.55,0 1,-0.45 1,-1v-1h8v1c0,0.55 0.45,1 1,1h1c0.55,0 1,-0.45 1,-1v-6h1c0.55,0 1,-0.45 1,-1s-0.45,-1 -1,-1zM9,6h6l1.4,4H7.6L9,6zM17,14H7v-2h10v2z"/>
</vector>
X
echo "Drawables creados"

cat > android/app/src/main/res/layout/quick_widget.xml << 'XMLEOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/qw_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:background="@drawable/qw_bg"
    android:padding="16dp">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:baselineAligned="false">
        <TextView
            android:id="@+id/qw_title"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:maxLines="1"
            android:ellipsize="end"
            android:text="LMB10"
            android:textColor="#F2F7FB"
            android:textStyle="bold"
            android:letterSpacing="0.04"
            android:textSize="13sp" />
        <TextView
            android:id="@+id/qw_fresh"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:maxLines="1"
            android:text=""
            android:textColor="#8FA8BC"
            android:textSize="11sp" />
    </LinearLayout>

    <ImageView
        android:id="@+id/qw_bar_img"
        android:layout_width="match_parent"
        android:layout_height="38dp"
        android:layout_marginTop="10dp"
        android:scaleType="fitXY"
        android:contentDescription="Bateria" />

    <TextView
        android:id="@+id/qw_bar_txt"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="10dp"
        android:fontFamily="monospace"
        android:textSize="15sp"
        android:textColor="#F2F7FB"
        android:visibility="gone"
        android:text="" />

    <TextView
        android:id="@+id/qw_info"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:maxLines="1"
        android:ellipsize="end"
        android:textColor="#D2E0EC"
        android:textSize="13sp"
        android:text="-- km" />

    <TextView
        android:id="@+id/qw_info2"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="2dp"
        android:maxLines="1"
        android:ellipsize="end"
        android:textColor="#8FA8BC"
        android:textSize="12sp"
        android:text="" />

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1"
        android:orientation="vertical" />

    <LinearLayout
        android:id="@+id/qw_buttons"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:layout_marginTop="10dp"
        android:baselineAligned="false">
        <Button
            android:id="@+id/qw_lock"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:layout_marginEnd="5dp"
            android:minHeight="0dp"
            android:minWidth="0dp"
            android:paddingTop="9dp"
            android:paddingBottom="9dp"
            android:textSize="11sp"
            android:textAllCaps="false"
            android:textColor="#E8F1F8"
            android:background="@drawable/qw_btn"
            android:drawableTop="@drawable/qw_ic_lock"
            android:drawablePadding="3dp"
            android:text="Cerrar" />
        <Button
            android:id="@+id/qw_clima"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:layout_marginHorizontal="5dp"
            android:minHeight="0dp"
            android:minWidth="0dp"
            android:paddingTop="9dp"
            android:paddingBottom="9dp"
            android:textSize="11sp"
            android:textAllCaps="false"
            android:textColor="#E8F1F8"
            android:background="@drawable/qw_btn"
            android:drawableTop="@drawable/qw_ic_clima"
            android:drawablePadding="3dp"
            android:text="Clima" />
        <Button
            android:id="@+id/qw_unlock"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:layout_marginHorizontal="5dp"
            android:minHeight="0dp"
            android:minWidth="0dp"
            android:paddingTop="9dp"
            android:paddingBottom="9dp"
            android:textSize="11sp"
            android:textAllCaps="false"
            android:textColor="#FFD9A0"
            android:background="@drawable/qw_btn_warn"
            android:drawableTop="@drawable/qw_ic_unlock"
            android:drawablePadding="3dp"
            android:text="Abrir" />
        <Button
            android:id="@+id/qw_trunk"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:layout_marginStart="5dp"
            android:minHeight="0dp"
            android:minWidth="0dp"
            android:paddingTop="9dp"
            android:paddingBottom="9dp"
            android:textSize="11sp"
            android:textAllCaps="false"
            android:textColor="#FFD9A0"
            android:background="@drawable/qw_btn_warn"
            android:drawableTop="@drawable/qw_ic_trunk"
            android:drawablePadding="3dp"
            android:text="Maletero" />
    </LinearLayout>
</LinearLayout>
XMLEOF
echo "Layout reescrito"

python3 - << 'PYEOF'
import sys
p = 'android/app/src/main/kotlin/com/txurtxil/lpb10/QuickWidgetProvider.kt'
s = open(p, encoding='utf-8').read()

def rep(old, new, tag):
    global s
    if s.count(old) != 1:
        print("ABORTA %s: %d ocurrencias" % (tag, s.count(old))); sys.exit(1)
    s = s.replace(old, new)

rep('''        val extra = if (charging == "1" && !kw.isNullOrEmpty()) "  ·  " + kw + " kW" else ""
        v.setTextViewText(R.id.qw_info, rangoTxt + "  ·  " + estado + extra)''',
'''        v.setTextViewText(R.id.qw_info, rangoTxt)

        // Segunda linea: estado y lo que este pasando ahora mismo.
        val temp = p.getString("interiorTemp", null)
        val partes = ArrayList<String>()
        partes.add(estado)
        if (charging == "1" && !kw.isNullOrEmpty()) partes.add("cargando " + kw + " kW")
        if (!temp.isNullOrEmpty()) partes.add("interior " + temp + "\\u00B0")
        v.setTextViewText(R.id.qw_info2, partes.joinToString("  ·  "))''', 'info2')

rep('''        p.color = Color.WHITE
        p.isFakeBoldText = true
        p.textSize = 46f
        p.textAlign = Paint.Align.LEFT
        c.drawText(pct.toInt().toString() + "%", 16f, h - 22f, p)
        return bmp''',
'''        // El numero va DENTRO de la parte llena si cabe, y fuera si no: con
        // bateria baja el texto blanco sobre fondo oscuro se leia mal.
        p.isFakeBoldText = true
        p.textSize = 44f
        p.textAlign = Paint.Align.LEFT
        val txt = pct.toInt().toString() + "%"
        val ancho = p.measureText(txt)
        if (w * f > ancho + 40f) {
            p.color = Color.parseColor("#0B1A18")
            c.drawText(txt, 22f, h - 24f, p)
        } else {
            p.color = Color.WHITE
            c.drawText(txt, w * f + 22f, h - 24f, p)
        }
        return bmp''', 'texto-barra')
open(p, 'w', encoding='utf-8').write(s)
print("OK kotlin")
PYEOF

echo "--- verificaciones ---"
echo -n "drawables: "; ls -1 "$D"/qw_*.xml | wc -l
echo -n "textAllCaps: "; grep -c 'textAllCaps="false"' android/app/src/main/res/layout/quick_widget.xml
echo -n "qw_info2 en kotlin: "; grep -c 'qw_info2' "$K/QuickWidgetProvider.kt"
echo
echo "--- compilando ---"
flutter build apk --release 2>&1 | tail -5
