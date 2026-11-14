FROM ubuntu:26.04
ENV DEBIAN_FRONTEND=noninteractive
COPY QQ.deb /tmp/QQ.deb
# QQ from QQ.deb, Firefox for links (Ubuntu's package is a snap stub, so Mozilla's repo),
# waypipe carries Wayland out of the VM.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && install -d /etc/apt/keyrings \
 && curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg -o /etc/apt/keyrings/mozilla.asc \
 && echo 'deb [signed-by=/etc/apt/keyrings/mozilla.asc] https://packages.mozilla.org/apt mozilla main' > /etc/apt/sources.list.d/mozilla.list \
 && printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' > /etc/apt/preferences.d/mozilla \
 && apt-get update \
 && apt-get install -y --no-install-recommends /tmp/QQ.deb \
 && apt-get install -y --no-install-recommends firefox waypipe libasound2t64 libgbm1 libegl1 libgl1-mesa-dri \
      libwayland-client0 libwayland-cursor0 libwayland-egl1 libxkbcommon0 libx11-xcb1 \
      fonts-noto-cjk fontconfig xdg-utils \
 && apt-get purge -y --auto-remove curl \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists /tmp/QQ.deb
