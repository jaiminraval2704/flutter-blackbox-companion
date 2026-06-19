import os
import re

lib_dir = 'lib'

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Replace withOpacity(x) with withValues(alpha: x)
    new_content = re.sub(r'\.withOpacity\(([^)]+)\)', r'.withValues(alpha: \1)', content)
    
    # Fix dart:html in firebase_service.dart
    if filepath.endswith('firebase_service.dart'):
        new_content = new_content.replace("import 'dart:html' as html;", "import 'package:web/web.dart' as web;")
        new_content = new_content.replace("html.window.localStorage", "web.window.localStorage")

    # Fix connection_screen.dart dart:html
    if filepath.endswith('connection_screen.dart'):
        new_content = new_content.replace("import 'dart:html' as html;", "import 'package:web/web.dart' as web;")
        new_content = new_content.replace("html.window.localStorage", "web.window.localStorage")

    # Fix print in websocket_service.dart
    if filepath.endswith('websocket_service.dart'):
        new_content = new_content.replace("print(", "debugPrint(")

    if new_content != content:
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
