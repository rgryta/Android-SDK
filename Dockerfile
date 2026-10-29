# Versions managed in .versions file - these are fallback defaults for local builds
ARG JDK_VERSION=25
ARG SDK_VERSION=36

# =============================================================================
# Stage: Download JDK
# =============================================================================
FROM eclipse-temurin:${JDK_VERSION}-jdk-noble AS jdk-builder

# =============================================================================
# Stage: Download Android SDK
# =============================================================================
FROM eclipse-temurin:${JDK_VERSION}-jdk-noble AS sdk-builder
ARG SDK_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends curl unzip \
    && rm -rf /var/lib/apt/lists/*

ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$PATH

RUN mkdir -p $ANDROID_HOME/cmdline-tools \
    && URL=$(curl -s https://developer.android.com/studio#command-tools \
        | grep -Eo 'https://dl.google.com/android/repository/commandlinetools-linux-[0-9]+_latest.zip' \
        | head -n 1) \
    && curl -sL $URL -o /tmp/cmdline-tools.zip \
    && unzip -q /tmp/cmdline-tools.zip -d $ANDROID_HOME/cmdline-tools \
    && mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest \
    && rm -f /tmp/cmdline-tools.zip

# Since API 37 platforms carry a minor suffix (android-37.0, 37.1, ...)
RUN yes | sdkmanager --sdk_root=$ANDROID_HOME \
    "platform-tools" \
    "platforms;android-${SDK_VERSION}.0" \
    "build-tools;${SDK_VERSION}.0.0" \
    && yes | sdkmanager --licenses

# =============================================================================
# Final minimal image (scratch)
# =============================================================================
FROM scratch

# Copy pause binary
COPY --from=ghcr.io/rgryta/volume-seed:1.0.1 /pause /pause
# The payload goes to /seed. On each start, /pause copies it into the target volumes if the
# payload changed, so a plain `compose up -d` gets the new files (see rgryta/volume-seed).
# The target dirs must exist and belong to uid 1000, so that uid 1000 can write to a new volume.
COPY --from=ghcr.io/rgryta/volume-seed:1.0.1 --chown=1000:1000 /empty /opt/java/openjdk
COPY --from=ghcr.io/rgryta/volume-seed:1.0.1 --chown=1000:1000 /empty /opt/android-sdk

# Copy JDK
COPY --from=jdk-builder --chown=1000:1000 /opt/java/openjdk /seed/opt/java/openjdk

# Copy Android SDK
COPY --from=sdk-builder --chown=1000:1000 /opt/android-sdk /seed/opt/android-sdk

# Labels
LABEL org.opencontainers.image.title="Android SDK"
LABEL org.opencontainers.image.description="Android SDK with JDK for mobile development"
LABEL org.opencontainers.image.source="https://github.com/rgryta/Android-SDK"

USER 1000:1000

CMD ["/pause", "/opt/java/openjdk", "/opt/android-sdk"]
