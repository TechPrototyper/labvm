# labvm

Goto-Werkzeug für Lima-VMs auf dem Mac (Apple Silicon, vz): **Hierarchie** (Ordner/Unterordner) statt flacher Liste, **Kurznamen**, neue VMs mit
**Standard-Ausstattung** und **Plattenkompression** (zstd, ca. 70 % weniger Platz).

```
labvm ls
├── 40c3/
│   └── smoke          Stopped  gepackt     3.9  [auto-pack]
└── labortage26/
    ├── fsre  kubers  nixos  z80 (lab)
labvm new 40c3/workshop/vm1 --memory 8GiB     # legt an, installiert Chromium, Compiler, Unix-Tools, Claude Code, Qwen Code
labvm start vm1                               # Kurzname; entpackt, startet; nach dem Beenden packt ein Wächter wieder
labvm stop 40c3                               # Ordner: alles darunter
```

## Konzepte
- **Baum** in `~/.config/labvm/tree.json`; Lima-Namen bleiben flach (`40c3-workshop-vm1`), der Baum ist die Ordnung dazu. `labvm adopt` nimmt bestehende Lima-VMs auf, `labvm mv` verschiebt nur Baumeinträge.
- **Kurznamen**: Pfadende → Präfix → Teilstring, auch Lima-Name; mehrdeutig = Fehler mit Kandidaten. Löschen (`rm --yes`) nur mit eindeutigem Namen/Präfix.
- **Packen**: `disk` → `disk.zst` (geprüft), `disk` wird Symlink auf `/dev/null`, damit ein versehentliches `limactl start` sicher scheitert. `limactl start` kehrt nach dem Hochfahren zurück; darum beobachtet ein Hintergrund-Wächter (`start`) bzw. der Vordergrundbefehl `run` das Ende und packt dann.
- **Shared**: `~/LabShare/<Pfad>` (Mac) ↔ `/mnt/share` bzw. `~/share` (VM): alle Nutzdaten an einer Stelle auf dem Mac.
- **Standard-Ausstattung** (`profile/`): Debian 13, XFCE + Autologin, Chromium (Standardbrowser, im Startmenü), build-essential/clang/gdb/cmake …, großer Satz Unix-Werkzeuge, Claude Code, Qwen Code, OpenCode; Locale en_US mit deutschen Formaten, Tastatur de, Berlin.
- `--compress fs` (btrfs mit zstd im Gast) ist vorgesehen, siehe Notizen unten.

## Installation
```bash
./install.sh        # Befehl, Claude-Skill, zsh-Vervollständigung; braucht: brew install lima zstd
python3 -m unittest discover -s tests   # Tests mit falschem limactl
```
Nur Python-Standardbibliothek.

## Grenzen
Teilstring-Treffer sind bequem, aber nur eindeutig; Pfade erlauben `A-Za-z0-9._-`. Der Shared-Mount einer VM bleibt bei `mv` am alten Pfad. Eine gepackte VM nie per `limactl` starten.
