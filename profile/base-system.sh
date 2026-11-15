#!/usr/bin/env bash
# labvm Standard-Ausstattung (als root in der VM, idempotent):
# Compiler, großer Satz Unix-Kommandozeilenwerkzeuge, Chromium (Standardbrowser, im Startmenü), Locale/Tastatur,
# optional Desktop (XFCE + LightDM-Autologin, GUI=1). Debian 13, nur Debian-Pakete.
set -euo pipefail
export LC_ALL=C.UTF-8 DEBIAN_FRONTEND=noninteractive
: "${LAB_USER:?LAB_USER fehlt}"
GUI="${GUI:-1}"
log()  { printf '\033[1;34m  ->\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !!\033[0m %s\n' "$*" >&2; }
mkdir -p /var/lib/lab

REQUIRED="build-essential gcc g++ clang lld gdb make cmake ninja-build pkg-config autoconf automake libtool bison flex nasm m4
  git git-lfs curl wget ca-certificates gnupg openssh-client rsync tmux screen vim nano less
  man-db manpages manpages-dev manpages-posix manpages-posix-dev info
  coreutils util-linux procps psmisc lsof strace ltrace tcpdump netcat-openbsd socat bind9-dnsutils iproute2 iputils-ping
  traceroute mtr-tiny net-tools ethtool file tree jq ripgrep fd-find bat fzf htop ncdu
  zip unzip p7zip-full xz-utils bzip2 zstd lz4 gzip patch diffutils findutils gawk sed grep bc dc expect moreutils pv parallel
  sysstat lshw pciutils usbutils dmidecode e2fsprogs dosfstools btrfs-progs xxd bsdextrautils binutils
  python3 python3-pip python3-venv pipx perl bash-completion locales xdg-utils chromium"
GUI_PKGS="xfce4 xfce4-terminal lightdm lightdm-gtk-greeter dbus-x11 xserver-xorg-core xserver-xorg-input-libinput
  x11-utils x11-xserver-utils xdotool fonts-dejavu fonts-liberation fonts-firacode mousepad zenity"
OPTIONAL="valgrind ltrace btop iotop iftop dstat whois ftp telnet strace-doc libc6-dbg elfutils lynx wdiff"
avail() { LC_ALL=C apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print ($2 != "(none)" && $2 != "")}' | grep -q 1; }

log "apt update"; apt-get update -qq
log "Pflichtpakete (Compiler, Unix-Werkzeuge, Chromium)"
# shellcheck disable=SC2086
apt-get install -y -qq $REQUIRED
if [ "$GUI" = 1 ]; then
  log "Desktop (XFCE, LightDM)"
  # shellcheck disable=SC2086
  apt-get install -y -qq $GUI_PKGS
  apt-get purge -y -qq xfce4-screensaver light-locker 2>/dev/null || true   # Konto ohne Passwort: Sperre würde aussperren
fi
want=(); skipped=()
for p in $OPTIONAL; do if avail "$p"; then want+=("$p"); else skipped+=("$p"); fi; done
[ ${#want[@]} -gt 0 ] && apt-get install -y -qq "${want[@]}" || true
[ ${#skipped[@]} -gt 0 ] && warn "Nicht verfügbar (übersprungen): ${skipped[*]}"

# ------------------------------------------------------------ Locale/Tastatur: Englisch, Formate/Tastatur deutsch
if ! locale -a | grep -qi '^en_US.utf8' || ! locale -a | grep -qi '^de_DE.utf8'; then
  sed -i 's/^# *\(de_DE.UTF-8 UTF-8\)/\1/; s/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
  locale-gen >/dev/null
fi
want_locale='LANG=en_US.UTF-8
LC_NUMERIC=de_DE.UTF-8
LC_TIME=de_DE.UTF-8
LC_MONETARY=de_DE.UTF-8
LC_PAPER=de_DE.UTF-8
LC_MEASUREMENT=de_DE.UTF-8
LC_NAME=de_DE.UTF-8
LC_ADDRESS=de_DE.UTF-8
LC_TELEPHONE=de_DE.UTF-8'
if [ "$(cat /etc/default/locale 2>/dev/null)" != "$want_locale" ]; then
  printf '%s\n' "$want_locale" > /etc/default/locale; echo 1 > /var/lib/lab/needs-reboot
fi
cat > /etc/default/keyboard <<'KBD'
XKBMODEL="pc105"
XKBLAYOUT="de"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
KBD
timedatectl set-timezone Europe/Berlin 2>/dev/null || ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

# ------------------------------------------------------------ Desktop: Autologin
if [ "$GUI" = 1 ]; then
  mkdir -p /etc/lightdm/lightdm.conf.d
  want_conf="[Seat:*]
autologin-user=$LAB_USER
autologin-user-timeout=0
autologin-session=xfce"
  if [ "$(cat /etc/lightdm/lightdm.conf.d/50-lab.conf 2>/dev/null)" != "$want_conf" ]; then
    printf '%s\n' "$want_conf" > /etc/lightdm/lightdm.conf.d/50-lab.conf; echo 1 > /var/lib/lab/needs-reboot
  fi
  echo /usr/sbin/lightdm > /etc/X11/default-display-manager
  if [ "$(systemctl get-default)" != graphical.target ]; then systemctl set-default graphical.target; echo 1 > /var/lib/lab/needs-reboot; fi
  systemctl enable lightdm >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------ Chromium als Standardbrowser, im Startmenü
# Google Chrome gibt es für Linux nur für x86_64; auf ARM64 ist Chromium der Browser.
update-alternatives --set x-www-browser /usr/bin/chromium >/dev/null 2>&1 || update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/chromium 90
update-alternatives --set gnome-www-browser /usr/bin/chromium >/dev/null 2>&1 || update-alternatives --install /usr/bin/gnome-www-browser gnome-www-browser /usr/bin/chromium 90
# systemweite Vorgabe für alle Benutzer (xdg-mime), plus XFCE-Hilfsprogramm
cat > /usr/share/applications/mimeapps.list <<'MIME'
[Default Applications]
x-scheme-handler/http=chromium.desktop
x-scheme-handler/https=chromium.desktop
text/html=chromium.desktop
application/xhtml+xml=chromium.desktop
MIME
mkdir -p /etc/xdg/xfce4
printf '[Default]\nWebBrowser=chromium\n' > /etc/xdg/xfce4/helpers.rc
command -v update-desktop-database >/dev/null && update-desktop-database /usr/share/applications || true
[ -f /usr/share/applications/chromium.desktop ] && log "Chromium-Eintrag im Startmenü: /usr/share/applications/chromium.desktop" || warn "chromium.desktop fehlt"

# PATH und Komfort für alle Sitzungen
cat > /etc/profile.d/labvm.sh <<'PROFILE'
# fd/bat heißen unter Debian fdfind/batcat
command -v fd >/dev/null 2>&1 || { command -v fdfind >/dev/null 2>&1 && alias fd=fdfind; }
command -v bat >/dev/null 2>&1 || { command -v batcat >/dev/null 2>&1 && alias bat=batcat; }
PROFILE
grep -q 'profile.d/labvm.sh' /etc/bash.bashrc || printf '\n[ -r /etc/profile.d/labvm.sh ] && . /etc/profile.d/labvm.sh\n' >> /etc/bash.bashrc
log "base-system.sh fertig"
