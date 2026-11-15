---
name: labvm
description: Verwaltet Lima-VMs auf diesem Mac mit dem Werkzeug `labvm` (Hierarchie aus Ordnern wie 40c3/workshop/vm1, Kurznamen, neue VMs mit Standard-Ausstattung, Platten packen/auspacken). Nutzen bei: VM anlegen, starten, stoppen, Shell in einer VM, VMs auflisten/einsortieren/verschieben, Platz sparen, "welche VMs gibt es", Congress/Labortage-VMs, Debian-VM mit Chromium/Claude Code/Qwen Code.
---

# labvm – Lima-VMs mit Hierarchie

`labvm` (installiert unter /opt/homebrew/bin, Quelle: ~/Projects/labvm) ist das Standardwerkzeug des Nutzers für Lima-VMs (vz, Debian 13 ARM64) auf diesem Mac.
**Nie `limactl` direkt zum Löschen/Stoppen/Packen benutzen, wenn `labvm` es kann**: der Baum (~/.config/labvm/tree.json) und das Packen der Platten
(`disk.zst`, `disk` = Symlink auf /dev/null) würden sonst inkonsistent. Ein direktes `limactl start` auf einer gepackten VM scheitert absichtlich.

## Grundlagen
- **Baum**: VM-Pfade wie `labortage26/kubers`, `40c3/workshop/vm1`. Ordner entstehen automatisch oder per `labvm mkdir`.
- **Kurznamen**: `labvm start kubers` genügt, wenn eindeutig (Pfadende, Präfix, Teilstring, auch der Lima-Name). Mehrdeutig → Fehler mit Kandidaten. Beim Löschen kein Teilstring-Raten.
- **Packen**: VMs mit `auto-pack` werden nach dem Beenden automatisch mit zstd gepackt (≈12 GB → 4 GB) und beim Start entpackt (15–30 s). Ein Hintergrund-Wächter erledigt das nach `labvm start`; `labvm run` bleibt im Vordergrund (für Start-Apps).
- **Shared-Ordner**: neue VMs bekommen den Mac-Ordner `~/LabShare/<Pfad>` als `/mnt/share` (in der VM `~/share`). Dort liegen alle Nutzdaten; alles andere ist individuell.
- Vorhandene VMs: Baum `labortage26/{z80(lab), kubers, nixos, fsre}`; Sammelordner für Material: `~/Projects/labortage`.

## Befehle
```
labvm ls [ordner]                      Baum: Status, Zustand (gepackt/ausgepackt), Mac-GB
labvm new 40c3/workshop/vm1 [--cpus 4 --memory 8GiB --disk 60GiB] [--compress pack|fs|none] [--no-gui] [--no-provision] [--no-share] [--mount MAC:VM] [--start]
labvm start|run NAME                   entpacken + starten (run: im Vordergrund bis zum Ende, dann packen)
labvm stop NAME|ORDNER [--force]       stoppen (Ordner: alle darunter); --force nur auf Wunsch/als Rückfall
labvm shell NAME [cmd…]                Shell in der VM (startet sie bei Bedarf)
labvm pack|unpack [NAME|ORDNER…]       ohne Namen: alle gestoppten packen / alle auspacken
labvm autopack NAME on|off             Auto-Pack umschalten
labvm mv QUELLE ZIEL                   verschieben/umbenennen (Ziel = bestehender Ordner → hinein). Lima-Name bleibt.
labvm mkdir PFAD · labvm adopt LIMA-NAME PFAD · labvm info NAME · labvm doctor
labvm image [--force]                 btrfs-Basisimage bauen (für new --compress fs)
labvm provision NAME [--ai-only]       Standard-Ausstattung (erneut) anwenden, idempotent
labvm rm NAME --yes                    VM unwiderruflich löschen (nur auf ausdrücklichen Wunsch!); leere Ordner ohne --yes
```
Neue VM (Standard): Debian 13, XFCE-Desktop mit Autologin, **Chromium** (Standardbrowser, im Startmenü), Compiler (gcc, g++, clang, make, cmake, gdb …),
großer Satz Unix-Werkzeuge, **Claude Code** und **Qwen Code** (+ OpenCode), Locale en_US mit deutschen Formaten/Tastatur, Zeitzone Berlin. `--no-gui` = ohne Desktop.
Kompression: `--compress pack` (Standard: Platte nach dem Beenden mit zstd packen, ruhend ca. 2,4 GB), `--compress fs` (Root-Dateisystem btrfs mit zstd, komprimiert im laufenden Betrieb, kein Ent-/Packen; ruhend ca. 5 GB; baut beim ersten Mal einmalig das Image mit `labvm image`, ca. 10 Min.), `none`.

## Arbeitsweise
1. Erst `labvm ls` (Zustand kennen). Bei unklarem Namen Kandidaten zeigen statt raten.
2. Anlegen: Pfad nach Anlass wählen (z. B. `40c3/<thema>`), Ressourcen angeben; `labvm new` dauert einige Minuten (im Hintergrund laufen lassen und Log lesen).
3. Kein `rm --yes`, kein `stop --force` und kein Überschreiben von Platten ohne ausdrückliche Anweisung des Nutzers. Nach `rm` ist die Platte weg.
4. Sichere Reihenfolge zum Aufräumen: `labvm stop X` → `labvm pack X` (oder Auto-Pack) → prüfen mit `labvm ls`.
5. Projektspezifische Provisionierung gehört in die Repos der Projekte (z. B. ~/Projects/fsre/labortage26-fsre); `labvm` liefert nur die Basis.
