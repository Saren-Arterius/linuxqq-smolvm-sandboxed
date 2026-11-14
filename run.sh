#!/bin/sh
# QQ in a smolvm microVM. Wayland goes through waypipe over one mounted socket.
set -eu
# [s]: so pkill doesn't match a shell whose command line has this pattern.
vm='[s]molvm-bin machine run .*qq-waypipe'
[ "${1-}" = stop ] && exec pkill -TERM -f "$vm"
# ponytail: already running, do nothing. Two QQs on one ./home corrupt it. Focusing the window needs more.
pgrep -f "$vm" >/dev/null && exit 0
cd "$(dirname "$0")"
mkdir -p home share
# Delete image.tar to rebuild (for example after a new QQ.deb).
[ -f image.tar ] || { docker build -t linuxqq-smolvm . && docker save linuxqq-smolvm -o image.tar; }
sock=$XDG_RUNTIME_DIR/qq-waypipe.sock
rm -f "$sock"
waypipe --no-gpu -s "$sock" client &
trap 'kill $! 2>/dev/null' EXIT INT TERM
# --no-sandbox: the VM is the sandbox. --disable-crash-reporter: no crash reports to Tencent.
smolvm machine run --block-private --cpus 4 --mem 8192 \
  -e HOME=/home/qq -e XDG_RUNTIME_DIR=/tmp -e QT_ACCESSIBILITY=0 -e MOZ_ENABLE_WAYLAND=1 \
  -e TZ="$(tail -n1 /etc/localtime)" -e U="$(id -u)" -e G="$(id -g)" \
  -v "$PWD/home:/home/qq" -v "$PWD/share:/share" \
  --mount-socket "$sock:/run/waypipe.sock" --image ./image.tar -- sh -c '
    rmdir /home/qq/Downloads 2>/dev/null; ln -sfn /share /home/qq/Downloads
    # QQ ties the login to machine-id and hostname. Keep both stable in ./home.
    [ -s /home/qq/.machine-id ] || tr -d - < /proc/sys/kernel/random/uuid > /home/qq/.machine-id
    [ -s /home/qq/.hostname ] || echo qq > /home/qq/.hostname
    cp /home/qq/.machine-id /etc/machine-id; hostname "$(cat /home/qq/.hostname)"
    # QQ'"'"'s native clipboard code uses X11 and crashes on copy (SIGSEGV) without a display.
    # Xvfb stays in the VM; QQ draws and copies text over Wayland.
    mkdir -p -m 1777 /tmp/.X11-unix
    setpriv --reuid="$U" --regid="$G" --clear-groups --no-new-privs \
      Xvfb :99 -nolisten tcp -screen 0 64x64x24 >/dev/null 2>&1 &
    export DISPLAY=:99
    exec setpriv --reuid="$U" --regid="$G" --clear-groups --no-new-privs \
      waypipe --no-gpu -s /run/waypipe.sock server -- /opt/QQ/qq --no-sandbox \
        --ozone-platform=wayland --enable-wayland-ime --disable-crash-reporter'
