import base64
import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location(
    "viewer_setup", Path(__file__).resolve().parents[1] / "scripts" / "viewer_setup.py"
)
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)


class ViewerSetupTests(unittest.TestCase):
    def test_credentials_are_random_and_auth_matches_project(self):
        first, second = setup.credentials(), setup.credentials()
        self.assertNotEqual(first["ENCRYPTION_KEY"], second["ENCRYPTION_KEY"])
        self.assertEqual(len(first["ENCRYPTION_KEY"]), 64)
        expected = (
            first["LANGFUSE_INIT_PROJECT_PUBLIC_KEY"] + ":"
            + first["LANGFUSE_INIT_PROJECT_SECRET_KEY"]
        )
        self.assertEqual(base64.b64decode(first["LANGFUSE_AUTH"]).decode(), expected)
        self.assertIn(first["POSTGRES_PASSWORD"], first["DATABASE_URL"])


if __name__ == "__main__":
    unittest.main()
