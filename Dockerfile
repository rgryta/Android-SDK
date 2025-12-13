ARG JDK_VERSION=21
FROM eclipse-temurin:${JDK_VERSION}-jdk-jammy

ARG SDK_VERSION=36

RUN apt-get update && apt-get install -y --no-install-recommends wget unzip curl git && rm -rf /var/lib/apt/lists/*

ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$PATH

RUN mkdir -p $ANDROID_HOME/cmdline-tools

RUN set -e; \
    URL=$(curl -s https://developer.android.com/studio#command-tools \
        | grep -Eo 'https://dl.google.com/android/repository/commandlinetools-linux-[0-9]+_latest.zip' \
        | head -n 1); \
    wget -q $URL -O /tmp/cmdline-tools.zip; \
    unzip -q /tmp/cmdline-tools.zip -d $ANDROID_HOME/cmdline-tools; \
    mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest; \
    rm -f /tmp/cmdline-tools.zip

RUN useradd -m -u 1000 node && chown -R node:node $ANDROID_HOME
USER node
WORKDIR /home/node

RUN yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --sdk_root=$ANDROID_HOME "platform-tools" "platforms;android-${SDK_VERSION}" "build-tools;${SDK_VERSION}.0.0" \
    && yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses

CMD ["tail", "-f", "/dev/null"]
