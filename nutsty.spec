# -*- mode: python ; coding: utf-8 -*-
import os
import sys

block_cipher = None

added_datas = [
    ('compat', 'compat'),
    ('components', 'components'),
    ('assets', 'assets'),
    ('backend', 'backend'),
    ('shell.qml', '.'),
    ('bin', 'bin'),
]

if os.path.exists('library.json'):
    added_datas.append(('library.json', '.'))

hidden_imports = [
    'PySide6.QtCore',
    'PySide6.QtGui',
    'PySide6.QtQml',
    'PySide6.QtQuick',
    'PySide6.QtQuickControls2',
    'PySide6.QtQuickLayouts',
    'PySide6.QtMultimedia',
    'http',
    'http.server',
    'http.client',
    'email',
    'email.message',
    'email.parser',
    'html',
    'ssl',
    'socket',
    'threading',
    'subprocess',
    'ctypes',
    'mutagen',
    'ytmusicapi',
    'syncedlyrics',
    'requests',
    'sqlite3',
    'uuid',
    'random',
    'datetime',
    'base64',
    'shutil',
    'tempfile',
    'pathlib',
    'urllib.request',
    'urllib.error',
    'urllib.parse',
    'auth_server',
    'player_daemon',
    'download_manager',
    'library',
    'palette_extractor',
    'lyrics_helper',
    'playlist_manager',
    'ytmusic_helper',
    'social_notes',
    'platform_compat',
]

a = Analysis(
    ['launcher_win.py'],
    pathex=['.'],
    binaries=[],
    datas=added_datas,
    hiddenimports=hidden_imports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['tkinter', 'matplotlib', 'scipy', 'numpy'],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='Nutsty',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon='assets/icons/nutsty.ico' if os.path.exists('assets/icons/nutsty.ico') else None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='Nutsty',
)
