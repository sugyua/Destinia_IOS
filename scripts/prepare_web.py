#!/usr/bin/env python3
"""Prepara o pacote Web do Destinia no projeto iOS, sem modificar o repositório original.

Exemplo: python3 scripts/prepare_web.py --repo /caminho/destinia
Os recursos originais permanecem apenas na cópia local/artefato privado.
"""
import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

APP_ROOT = Path(__file__).resolve().parents[1]
DESTINATION = APP_ROOT / "Web"

DELETE_NEEDLE = "if(ok&&match)this.codex.erase(Number(match[1]));this.w(0,ok?0:-1);"
DELETE_REPLACEMENT = (
    "if(ok&&match)this.codex.erase(Number(match[1]));"
    "if(ok){const name=path.split('/').pop().split('\\\\').pop();"
    "this.saved.delete(name);this.saved.delete('./'+name);"
    "this.saved.delete('/data/data/game.destiniaeng/files/'+name);"
    "this.persistCloudDelete(path);}this.w(0,ok?0:-1);"
)

DELETE_METHOD = '''  persistCloudDelete(filePath){
    const name=filePath.split('/').pop().split('\\\\').pop();
    if(!name.includes('save')&&!name.includes('codex'))return;
    const base=(typeof location!=='undefined'&&location.origin)?location.origin:'http://127.0.0.1:19406';
    fetch(base+'/api/save',{method:'DELETE',headers:{'Content-Type':'application/json'},body:JSON.stringify({name})})
      .then(r=>r.json()).then(result=>{if(!result?.ok)this.log('Falha ao excluir save local: '+name);})
      .catch(error=>this.log('Falha ao excluir save local: '+String(error)));
  }
'''

IOS_CSS = '''/* Ajustes somente no pacote iOS; nenhum arquivo Windows/Web original é modificado. */
html,body{overscroll-behavior:none;-webkit-text-size-adjust:100%;}
body{touch-action:manipulation;}
canvas,.controls{-webkit-user-select:none;user-select:none;}
@media (orientation:landscape) and (max-height:520px){
 body{height:100dvh;min-height:100dvh;overflow:hidden;}
 header{padding-left:max(8px,env(safe-area-inset-left));padding-right:max(8px,env(safe-area-inset-right));}
 .controls{padding-left:max(12px,env(safe-area-inset-left));padding-right:max(12px,env(safe-area-inset-right));}
 footer{padding-bottom:max(2px,env(safe-area-inset-bottom));}
}
'''


def patch_engine(text: str) -> str:
    if text.count(DELETE_NEEDLE) != 1 or text.count("  persistCloudSave(filePath){") != 1:
        raise ValueError("A versão do engine.mjs mudou: revise o adaptador de saves antes de compilar.")
    text = text.replace(DELETE_NEEDLE, DELETE_REPLACEMENT, 1)
    text = text.replace("  persistCloudSave(filePath){", DELETE_METHOD + "  persistCloudSave(filePath){", 1)
    text = text.replace("Save sincronizado com Google Drive: ", "Save armazenado no iPhone: ")
    text = text.replace("Aviso Sync Drive: ", "Aviso do save local: ")
    text = text.replace("Saves carregados do Google Drive: ", "Saves carregados do iPhone: ")
    text = text.replace("Drive sync indisponivel: ", "Saves locais indisponíveis: ")
    return text


def patch_html(text: str) -> str:
    if "</head>" not in text:
        raise ValueError("index.html sem fechamento de <head>; atualização manual necessária.")
    return text.replace("</head>", '<link rel="stylesheet" href="./ios-overrides.css">\n</head>', 1)


def safe_copy(source: Path, destination: Path):
    if not source.is_dir():
        raise FileNotFoundError(f"A pasta de fontes não existe: {source}")
    for path in source.rglob("*"):
        if path.is_symlink():
            raise ValueError(f"Link simbólico não permitido nos recursos: {path}")
    shutil.copytree(source, destination, ignore=shutil.ignore_patterns("game", ".DS_Store", "*.log"))


def prepare(repo: Path, *, skip_game: bool = False) -> dict:
    source = repo / "web" / "dist"
    needed = ["worker.js", "engine.mjs", "app.mjs", "index.html", "style.css", "vendor/unicorn_arm.js"]
    for name in needed:
        if not (source / name).is_file():
            raise FileNotFoundError(f"Fonte necessário ausente: {source / name}")
    if not skip_game:
        for path in [repo / "web" / "tools" / "pack_game.py", repo / "game" / "lib" / "armeabi" / "libdestinia_jni.so", repo / "game" / "assets"]:
            if not path.exists():
                raise FileNotFoundError(f"Recurso original não encontrado: {path}")

    target = DESTINATION
    staging = target.parent / "Web.staging"
    if staging.exists():
        shutil.rmtree(staging)
    try:
        safe_copy(source, staging)
        engine = staging / "engine.mjs"
        engine.write_text(patch_engine(engine.read_text(encoding="utf-8")), encoding="utf-8")
        html = staging / "index.html"
        ios_html = patch_html(html.read_text(encoding="utf-8"))
        ios_html = ios_html.replace("UMA AVENTURA, DIRETO NO SAFARI", "DESTINIA PARA IPHONE · OFFLINE")
        ios_html = ios_html.replace("progresso temporário", "progresso salvo localmente")
        html.write_text(ios_html, encoding="utf-8")
        app_file = staging / "app.mjs"
        app_file.write_text(app_file.read_text(encoding="utf-8").replace("progresso temporário", "saves locais no iPhone"), encoding="utf-8")
        (staging / "ios-overrides.css").write_text(IOS_CSS, encoding="utf-8")

        # A Web do Destinia já salva por HTTP; o aplicativo responde em /api/save
        # e guarda arquivos em Documents/DestiniaSaves (não no próprio app bundle).
        if not skip_game:
            subprocess.run([sys.executable, str(repo / "web" / "tools" / "pack_game.py"),
                            "--game", str(repo / "game"), "--out", str(staging / "game")],
                           check=True)
        if target.exists():
            shutil.rmtree(target)
        staging.rename(target)
    except Exception:
        if staging.exists():
            shutil.rmtree(staging)
        raise

    report = {
        "destino": str(target),
        "origem": str(repo),
        "fontes_web": len([p for p in target.rglob("*") if p.is_file()]),
        "motor_arm": (target / "game" / "libdestinia_jni.so").exists(),
        "recursos": (target / "game" / "assets.bin").exists(),
    }
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True, help="Checkout do repositório sugyua/destinia")
    parser.add_argument("--skip-game", action="store_true", help="Somente validação local de fontes; não gera app jogável")
    args = parser.parse_args()
    try:
        report = prepare(args.repo.resolve(), skip_game=args.skip_game)
    except (ValueError, FileNotFoundError, subprocess.CalledProcessError) as error:
        print(f"ERRO: {error}", file=sys.stderr)
        return 1
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
