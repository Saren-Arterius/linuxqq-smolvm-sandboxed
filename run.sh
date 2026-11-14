#!/bin/sh
# QQ in a smolvm microVM. Wayland goes through waypipe over one mounted socket.
set -eu
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
    exec setpriv --reuid="$U" --regid="$G" --clear-groups --no-new-privs \
      waypipe --no-gpu -s /run/waypipe.sock server -- /opt/QQ/qq --no-sandbox \
        --ozone-platform=wayland --enable-wayland-ime --disable-crash-reporter'
