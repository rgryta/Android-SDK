## Android SDK Image

I use this image as a provider for JDK and Android SDK to my [Code Server](https://hub.docker.com/r/linuxserver/code-server)


### Docker Compose

```yaml
services:
  uv:
    image: ghcr.io/astral-sh/uv:debian-slim
    container_name: uv
    volumes:
      - /opt/python
    entrypoint:
      - sh
      - -c
      - |
        uv python install 3.12 --install-dir /opt/python_tmp &&
        rm -rf /opt/python/* &&
        cp -a /opt/python_tmp/cpython-*/* /opt/python/ &&
        rm -rf /opt/python_tmp &&
        tail -f /dev/null
    restart: unless-stopped
  android:
    labels:
      - traefik.enable=false
    image: ghcr.io/rgryta/android-sdk:main
    container_name: android
    volumes:
      - /opt/java/openjdk
      - /opt/android-sdk
    command: tail -f /dev/null
    user: node
    restart: unless-stopped
  vscode:
    image: lscr.io/linuxserver/code-server:latest
    container_name: code-server
    volumes_from:
      - android
      - uv
    volumes:
      - vscode_config:/config
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Warsaw
      - HASHED_PASSWORD=${HASHED_PASSWORD}
      - SUDO_PASSWORD_HASH=${HASHED_PASSWORD}
      - DEFAULT_WORKSPACE=/config/workspace
      - PWA_APPNAME=code-server
      - 'EXTENSIONS_GALLERY={"serviceUrl":
        "https://marketplace.visualstudio.com/_apis/public/gallery", "itemUrl":
        "https://marketplace.visualstudio.com/items"}'
      - JAVA_HOME=/opt/java/openjdk
      - ANDROID_HOME=/opt/android-sdk
      - PATH=/opt/python/bin:/opt/java/openjdk/bin:/opt/android-sdk/cmdline-tools/latest/bin:$PATH
    depends_on:
      - android
      - uv
    restart: unless-stopped
    networks:
      homelab-network:
        ipv4_address: 172.20.0.25
volumes:
  vscode_config:
    driver_opts:
      o: bind
      type: none
      device: ${VSCODE_CONFIG_PATH}
networks:
  homelab-network:
    external: true
```

### Credits
 - VS Code: https://github.com/Microsoft/vscode
 - Code Server: https://github.com/coder/code-server?tab=readme-ov-file
 - Image for Code Server: https://github.com/linuxserver/docker-code-server
