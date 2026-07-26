import xml.etree.ElementTree as ET
import os

manifest_path = 'android/app/src/main/AndroidManifest.xml'
ET.register_namespace('android', 'http://schemas.android.com/apk/res/android')
tree = ET.parse(manifest_path)
root = tree.getroot()

permissions_to_add = ['android.permission.INTERNET']

existing_permissions = [
    elem.attrib.get('{http://schemas.android.com/apk/res/android}name') 
    for elem in root.findall('uses-permission')
]

modified = False
for p in permissions_to_add:
    if p not in existing_permissions:
        new_perm = ET.Element('uses-permission')
        new_perm.set('android:name', p)
        root.insert(0, new_perm)
        modified = True

if modified:
    tree.write(manifest_path, encoding='utf-8', xml_declaration=True)
    print("-> Permisos inyectados correctamente.")
else:
    print("-> Los permisos ya estaban presentes.")
