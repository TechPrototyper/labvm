"""Tests für labvm mit einem falschen limactl (keine echten VMs nötig). Aufruf: python3 -m unittest discover -s tests"""
import json, os, subprocess, sys, tempfile, unittest

HERE = os.path.dirname(os.path.abspath(__file__))
LABVM = os.path.join(os.path.dirname(HERE), "labvm")
FAKE = '''#!/bin/sh
# falsches limactl: list --json | list --format ... NAME | alles andere: ok
if [ "$1" = list ] && [ "$2" = --json ]; then
  for n in alpha beta gamma; do echo "{\\"name\\":\\"$n\\",\\"status\\":\\"Stopped\\"}"; done; exit 0; fi
if [ "$1" = list ] && [ "$2" = --format ]; then echo Stopped; exit 0; fi
exit 0
'''


class T(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.tmp, "bin"))
        with open(os.path.join(self.tmp, "bin", "limactl"), "w") as f:
            f.write(FAKE)
        os.chmod(os.path.join(self.tmp, "bin", "limactl"), 0o755)
        self.env = dict(os.environ, LABVM_CONFIG=os.path.join(self.tmp, "tree.json"), LIMA_HOME=os.path.join(self.tmp, "lima"),
                        PATH=os.path.join(self.tmp, "bin") + ":" + os.environ["PATH"])
        for n in ("alpha", "beta", "gamma"):
            os.makedirs(os.path.join(self.tmp, "lima", n))

    def lv(self, *args, ok=True):
        r = subprocess.run([sys.executable, LABVM] + list(args), env=self.env, capture_output=True, text=True)
        if ok:
            self.assertEqual(r.returncode, 0, r.stderr)
        else:
            self.assertNotEqual(r.returncode, 0)
        return r.stdout + r.stderr

    def tree(self):
        return json.load(open(self.env["LABVM_CONFIG"]))["nodes"]

    def test_adopt_resolve_mv(self):
        self.lv("adopt", "alpha", "conf/one/a")
        self.lv("adopt", "beta", "conf/two/b")
        self.lv("adopt", "gamma", "other/g")
        self.assertIn("conf/one/a", self.lv("info", "alp"))          # Lima-Name-Präfix
        self.assertIn("conf/two/b", self.lv("info", "two/b"))        # Pfadende
        self.assertIn("other/g", self.lv("info", "oth/g"))
        self.lv("mv", "a", "other")                                  # in Ordner verschieben
        self.assertIn("other/a", self.tree())
        self.lv("mv", "other", "archive")                            # Ordner umbenennen
        self.assertIn("archive/a", self.tree())
        self.assertIn("archive/g", self.tree())
        self.assertNotIn("other/a", self.tree())

    def test_ambiguous_and_errors(self):
        self.lv("adopt", "alpha", "x/same")
        self.lv("adopt", "beta", "y/same")
        out = self.lv("info", "same", ok=False)
        self.assertIn("nicht eindeutig", out)
        self.lv("adopt", "alpha", "z/dup", ok=False)                 # Lima-VM schon einsortiert
        self.lv("adopt", "nope", "z/n", ok=False)                    # unbekannte Lima-VM
        self.lv("mkdir", "x/same/sub", ok=False)                     # unter einer VM
        self.lv("mkdir", "bad name", ok=False)                       # Leerzeichen

    def test_rm_needs_yes_and_folder_rules(self):
        self.lv("adopt", "alpha", "f/a")
        self.lv("rm", "a", ok=False)                                 # ohne --yes nichts
        self.assertIn("f/a", self.tree())
        self.lv("rm", "f", ok=False)                                 # Ordner nicht leer
        self.lv("mkdir", "leer")
        self.lv("rm", "leer")
        self.assertNotIn("leer", self.tree())

    def test_ls_shows_loose(self):
        self.lv("adopt", "alpha", "f/a")
        out = self.lv("ls")
        self.assertIn("a ", out)
        self.assertIn("beta", out)                                   # nicht einsortiert

    def test_pack_roundtrip(self):
        if subprocess.run(["which", "zstd"], capture_output=True).returncode != 0:
            self.skipTest("zstd fehlt")
        d = os.path.join(self.tmp, "lima", "alpha")
        with open(os.path.join(d, "disk"), "wb") as f:
            f.write(os.urandom(2_000_000) + b"\0" * 8_000_000)
        orig = open(os.path.join(d, "disk"), "rb").read()
        self.lv("adopt", "alpha", "p/a")
        self.lv("pack", "a")
        self.assertTrue(os.path.islink(os.path.join(d, "disk")))
        self.assertTrue(os.path.isfile(os.path.join(d, "disk.zst")))
        self.lv("unpack", "a")
        self.assertEqual(open(os.path.join(d, "disk"), "rb").read(), orig)
        self.assertFalse(os.path.exists(os.path.join(d, "disk.zst")))


if __name__ == "__main__":
    unittest.main()
