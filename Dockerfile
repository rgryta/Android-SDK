# Versions managed in .versions file - these are fallback defaults for local builds
ARG JDK_VERSION=25
ARG SDK_VERSION=36

# =============================================================================
# Stage: Download Android SDK
# =============================================================================
FROM debian:bookworm-slim AS sdk-builder
ARG SDK_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget unzip curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV ANDROID_HOME=/opt/android-sdk

RUN mkdir -p $ANDROID_HOME/cmdline-tools \
    && URL=$(curl -s https://developer.android.com/studio#command-tools \
        | grep -Eo 'https://dl.google.com/android/repository/commandlinetools-linux-[0-9]+_latest.zip' \
        | head -n 1) \
    && wget -q $URL -O /tmp/cmdline-tools.zip \
    && unzip -q /tmp/cmdline-tools.zip -d $ANDROID_HOME/cmdline-tools \
    && mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest \
    && rm -f /tmp/cmdline-tools.zip

# =============================================================================
# Stage: pause binary (static, for minimal entrypoint)
# =============================================================================
FROM alpine:latest AS pause-builder
RUN apk add --no-cache go \
    && echo 'package main; import ("os"; "os/signal"); func main() { c := make(chan os.Signal, 1); signal.Notify(c); <-c }' > /pause.go \
    && CGO_ENABLED=0 go build -ldflags="-s -w" -o /pause /pause.go

# =============================================================================
# Final image with JDK + Android SDK
# =============================================================================
FROM eclipse-temurin:${JDK_VERSION}-jdk-alpine
ARG SDK_VERSION

ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH

# Create non-root user
RUN adduser -D -u 1000 android

# Copy pause binary
COPY --from=pause-builder /pause /pause

# Copy Android SDK from builder
COPY --from=sdk-builder --chown=android:android /opt/android-sdk /opt/android-sdk

# Install SDK components as non-root user
USER android
WORKDIR /home/android

RUN yes | sdkmanager --sdk_root=$ANDROID_HOME \
    "platform-tools" \
    "platforms;android-${SDK_VERSION}" \
    "build-tools;${SDK_VERSION}.0.0" \
    && yes | sdkmanager --licenses

# Labels
LABEL org.opencontainers.image.title="Android SDK"
LABEL org.opencontainers.image.description="Android SDK with JDK for mobile development"
LABEL org.opencontainers.image.source="https://github.com/rgryta/Android-SDK"

CMD ["/pause"]
