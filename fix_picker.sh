#!/bin/bash
# LMB10 - fix_picker.sh: sustituye file_picker (3.0.4 rota, jcenter) por
# file_selector (paquete oficial flutter.dev) en la importacion de backup.
set -e
cp lib/history_archive.dart backups_widget/history_archive.dart.bak_fixpicker

python3 << 'PYEOF'
import sys

def patch(path, jobs):
    src = open(path, encoding='utf-8').read()
    for label, anchor, repl in jobs:
        n = src.count(anchor)
        if n != 1:
            print(f"ERROR '{label}': ancla {n} veces (esperada 1). {path} sin tocar.")
            sys.exit(1)
        src = src.replace(anchor, repl)
        print(f"OK  {label}")
    open(path, 'w', encoding='utf-8').write(src)

patch('lib/history_archive.dart', [
 ('import file_selector',
  "import 'package:file_picker/file_picker.dart';",
  "import 'package:file_selector/file_selector.dart';"),

 ('selector de archivo con file_selector',
  """    final res = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['json'], withData: true);
    if (res == null || res.files.isEmpty) return 'Importacion cancelada';
    final f = res.files.single;
    String? content;
    if (f.bytes != null) {
      content = utf8.decode(f.bytes!);
    } else if (f.path != null) {
      content = await File(f.path!).readAsString();
    }
    if (content == null) return 'No se pudo leer el fichero';""",
  """    const grupo = XTypeGroup(label: 'Backup JSON', extensions: ['json']);
    final XFile? file = await openFile(acceptedTypeGroups: [grupo]);
    if (file == null) return 'Importacion cancelada';
    final content = await file.readAsString();"""),
])
print('OK  parches aplicados')
PYEOF
echo "LISTO. Compila: flutter build apk --release"
