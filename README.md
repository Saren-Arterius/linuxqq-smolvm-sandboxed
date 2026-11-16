# QQ in a smolvm microVM

## What this is

This project runs Tencent QQ for Linux in a small virtual machine (VM).

QQ is closed-source software. You cannot see what it does. Do not give it your user account.

The VM has its own Linux kernel. If bad code breaks the kernel in the VM,
the kernel of your computer is still safe.

The VM gives QQ these limits:

- QQ cannot see your home folder. It can see only the folders in "What QQ can see".
- QQ cannot connect to your home network, your router, or your computer.
- QQ can connect to the internet.

You do not need root access to run the VM.

## Disclaimer

An AI model wrote the configuration and this document.
The commands ran on one computer only (CachyOS, GNOME on Wayland, an NVIDIA GPU).
No person did a security audit.

This is not a Tencent project. Tencent does not support it.

## Before you start

You must have these items:

1. Linux with a Wayland desktop. This project does not operate with X11.
2. Access to `/dev/kvm`.
3. The `smolvm` and `waypipe` packages.
4. Docker. The project uses Docker only to build the VM image.

On Arch Linux, type this command to install the packages:

```
sudo pacman -S smolvm waypipe
```

## Install

Do these steps in the project folder.

1. Download QQ. Use the mirror URL. The Tencent URL gives an HTTP 403 error from most networks.

   ```
   curl -fL "https://dlqq.akkariin.moe/$(curl -s https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/linuxConfig.js | grep -oP '(?<="deb":")[^"]+' | head -1)" -o QQ.deb
   ```

2. Start QQ:

   ```
   ./run.sh
   ```

   The first start builds and loads the VM image. This takes some minutes.
   After the first start, the VM starts in less than one second.

3. Add QQ to your app menu:

   ```
   docker run --rm --entrypoint cat linuxqq-smolvm /usr/share/icons/hicolor/512x512/apps/qq.png > /tmp/qq.png
   install -Dm644 /tmp/qq.png ~/.local/share/icons/hicolor/512x512/apps/qq.png
   sed "s|@DIR@|$PWD|g" qq-smolvm.desktop > ~/.local/share/applications/qq-smolvm.desktop
   ```

   GNOME finds `Icon=qq` only in an icon theme. A full path to the file shows a gear icon.

## Start and stop QQ

To start QQ, click "QQ (smolvm)" in your app menu. You can also type `./run.sh`.
If QQ runs, this does nothing. Two QQs that use the same `home` folder can damage it.

To stop QQ, right-click "QQ (smolvm)" and click "Stop QQ". You can also type `./run.sh stop`.
The "Quit" item of the dock does not always stop the VM.

About half of the starts of QQ hang before the window. The cause is not known.
`run.sh` sees this and starts QQ again, up to five times. The window can take up to a minute.

If no window comes, look in `home/qq.log`. The log of the start before it is in `home/qq.log.1`.

## What QQ can see

QQ can see only these items:

| Item | QQ can read | QQ can change |
|---|---|---|
| The `home` folder in this project (QQ login, settings and chat history) | Yes | Yes |
| The `share` folder in this project | Yes | Yes |
| The internet | Yes | Yes |
| Your desktop, through `waypipe` (windows and clipboard) | Yes | Yes |

QQ cannot connect to:

- Your home network and your router.
- Your computer.
- Private network addresses, for example `192.168.x.x` and `10.x.x.x`.

QQ saves received files in the `share` folder. Files that QQ saves belong to your user.

To send a file, put the file in the `share` folder first.

Links in QQ open in a Firefox in the same VM.

## Your login

QQ connects your login to the machine ID and the host name.
`run.sh` keeps these two values in `home/.machine-id` and `home/.hostname`.
If you delete these files, QQ asks you to log in again.

Do not share these files. `.gitignore` excludes the `home` folder.

## The GPU

The VM does not use the GPU. QQ draws the screen with the CPU.

WARNING: Do not add `--gpu` to `run.sh` on a computer with an NVIDIA GPU.
In a test with Telegram on an NVIDIA RTX 4090, the GPU caused the desktop to stop.

## Get a new version of QQ

Download `QQ.deb` again (Install, step 1). Then delete the old image and start QQ:

```
rm image.tar && ./run.sh
```

Do the same after you change the `Dockerfile`.

## Technical notes

These notes are for persons who change the project.

- Wayland cannot go directly out of a VM. `waypipe` sends the Wayland data through one socket.
  `run.sh` gives this socket to the VM with `--mount-socket`.
- `--block-private` blocks private networks, the computer, CGNAT addresses, and cloud metadata.
- In the VM, `run.sh` starts as root for some setup steps. Then QQ runs as your user,
  with no new permissions.
- QQ uses `--no-sandbox`, because the VM is the sandbox.
- `--disable-crash-reporter` stops crash reports to Tencent.
- smolvm 1.34 stops if a folder name in the VM has letters that are not ASCII.
  Keep the mount paths in `run.sh` in ASCII.

## Remove

Delete the project folder. This also deletes your QQ login and chat history.
Then delete the app menu entry and the image:

```
rm ~/.local/share/applications/qq-smolvm.desktop ~/.local/share/icons/hicolor/512x512/apps/qq.png
docker rmi linuxqq-smolvm
```
