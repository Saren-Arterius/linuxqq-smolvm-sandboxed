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
    # Log to ./home/qq.log as it happens (smolvm holds stdout until the VM exits). Last start: qq.log.1.
    # Through a FIFO: isatty() on a virtiofs file gives EOPNOTSUPP, and waypipe 0.11 panics on it.
    mv -f /home/qq/qq.log /home/qq/qq.log.1 2>/dev/null; mkfifo /tmp/log
    cat /tmp/log >/home/qq/qq.log & exec >/tmp/log 2>&1; date
    mkdir -p -m 1777 /tmp/.X11-unix
    setpriv --reuid="$U" --regid="$G" --clear-groups --no-new-privs \
      Xvfb :99 -nolisten tcp -screen 0 64x64x24 &
    export DISPLAY=:99
    # ponytail: about half of the starts hang before the window (cause unknown: QQ waits in its
    # own JS; not GPU, Xvfb, network or locks). A good start logs initializeMMKV within seconds,
    # so kill and retry the others. Remove this loop when a new QQ fixes the hang.
    for try in 1 2 3 4 5; do
      echo "start $try"
      setpriv --reuid="$U" --regid="$G" --clear-groups --no-new-privs \
        waypipe --no-gpu -s /run/waypipe.sock server -- /opt/QQ/qq --no-sandbox \
          --ozone-platform=wayland --enable-wayland-ime --disable-crash-reporter &
      pid=$!; i=0
      while [ $i -lt 20 ] && kill -0 $pid 2>/dev/null && ! grep -q initializeMMKV /home/qq/qq.log; do
        sleep 1; i=$((i+1))
      done
      grep -q initializeMMKV /home/qq/qq.log && { wait $pid; exit; }
      echo "start $try hung, retrying"; kill $pid
      # By name: -f /opt/QQ would also match this shell.
      pkill -x qq; pkill -x chrome_crashpad; sleep 2; pkill -9 -x qq; wait $pid
    done'
