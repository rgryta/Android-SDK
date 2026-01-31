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

RUN yes | sdkmanager --sdk_root=$ANDROID_HOME \
    "platform-tools" \
    "platforms;android-${SDK_VERSION}" \
    "build-tools;${SDK_VERSION}.0.0" \
    && yes | sdkmanager --licenses

# =============================================================================
# Stage: pause binary (static, for scratch)
# =============================================================================
FROM alpine:latest AS pause-builder
RUN apk add --no-cache go \
    && echo 'package main; import ("os"; "os/signal"); func main() { c := make(chan os.Signal, 1); signal.Notify(c); <-c }' > /pause.go \
    && CGO_ENABLED=0 go build -ldflags="-s -w" -o /pause /pause.go

# =============================================================================
# Final minimal image (scratch)
# =============================================================================
FROM scratch

# Copy pause binary
COPY --from=pause-builder /pause /pause

# Copy JDK
COPY --from=jdk-builder --chown=1000:1000 /opt/java/openjdk /opt/java/openjdk

# Copy Android SDK
COPY --from=sdk-builder --chown=1000:1000 /opt/android-sdk /opt/android-sdk

# Labels
LABEL org.opencontainers.image.title="Android SDK"
LABEL org.opencontainers.image.description="Android SDK with JDK for mobile development"
LABEL org.opencontainers.image.source="https://github.com/rgryta/Android-SDK"

USER 1000:1000

CMD ["/pause"]
