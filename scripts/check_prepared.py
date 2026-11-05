#!/usr/bin/env python3
"""Falha cedo caso os recursos do jogo não tenham sido preparados."""
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "Web"
required = {
    "index.html": 100,
    "app.mjs": 100,
    "engine.mjs": 100,
    "worker.js": 100,
    "vendor/unicorn_arm.js": 10000,
    "game/libdestinia_jni.so": 10000,
    "game/assets.bin": 1000,
}
missing = [relative for relative, minimum in required.items()
           if not (root / relative).is_file() or (root / relative).stat().st_size < minimum]
if missing:
    print("Faltam arquivos do aplicativo:", *missing, sep="\n - ", file=sys.stderr)
    print("Execute python3 scripts/prepare_web.py --repo /caminho/destinia", file=sys.stderr)
    raise SystemExit(1)
print("Recursos essenciais presentes para compilar (não equivale a teste no iPhone).")
