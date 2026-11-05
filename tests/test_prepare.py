import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("prepare_web", ROOT / "scripts" / "prepare_web.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PreparationTests(unittest.TestCase):
    def test_patch_html_adds_ios_styles(self):
        self.assertIn('ios-overrides.css', module.patch_html('<html><head></head><body></body></html>'))

    def test_patch_engine_preserves_original_save_calls_and_adds_delete(self):
        source = (
            "L('remove',()=>{if(ok&&match)this.codex.erase(Number(match[1]));this.w(0,ok?0:-1);});\n"
            "  persistCloudSave(filePath){console.log('Save sincronizado com Google Drive: ');}\n"
        )
        result = module.patch_engine(source)
        self.assertIn("this.persistCloudDelete(path)", result)
        self.assertIn("  persistCloudSave(filePath){", result)
        self.assertIn("method:'DELETE'", result)
        self.assertIn("Save armazenado no iPhone:", result)

    def test_patch_engine_fails_closed_if_upstream_changed(self):
        with self.assertRaises(ValueError):
            module.patch_engine("  persistCloudSave(filePath){")

    def test_rejects_symlinks(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "source").mkdir()
            (root / "file").write_text("ok")
            (root / "source" / "linked").symlink_to(root / "file")
            with self.assertRaises(ValueError):
                module.safe_copy(root / "source", root / "copy")


if __name__ == "__main__":
    unittest.main()
