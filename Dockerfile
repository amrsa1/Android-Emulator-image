FROM eclipse-temurin:21-jdk-jammy

LABEL maintainer="Amr Salem"

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /

#=============================
# Install Dependencies
#=============================
SHELL ["/bin/bash", "-c"]

#==============================
# Android SDK ARGS
#==============================
ARG TARGETARCH
ARG ARCH="x86_64"
ARG TARGET="google_apis_playstore"
ARG API_LEVEL="36"
ARG BUILD_TOOLS="36.0.0"
ARG ANDROID_API_LEVEL="android-${API_LEVEL}"
ARG ANDROID_APIS="${TARGET};${ARCH}"
ARG EMULATOR_PACKAGE="system-images;${ANDROID_API_LEVEL};${ANDROID_APIS}"
ARG PLATFORM_VERSION="platforms;${ANDROID_API_LEVEL}"
ARG BUILD_TOOL="build-tools;${BUILD_TOOLS}"
ARG ANDROID_CMD="commandlinetools-linux-14742923_latest.zip"
ARG ANDROID_SDK_PACKAGES="${EMULATOR_PACKAGE} ${PLATFORM_VERSION} ${BUILD_TOOL} platform-tools emulator"
ARG EMULATOR_NAME="nexus"
ARG EMULATOR_DEVICE="Nexus 6"

#==============================
# Set JAVA_HOME - SDK
#==============================
ENV ANDROID_SDK_ROOT=/opt/android
ENV ANDROID_HOME=/opt/android
ENV PATH="$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/build-tools/${BUILD_TOOLS}"
ENV DOCKER="true"
ENV EMULATOR_NAME="${EMULATOR_NAME}"
ENV DEVICE_NAME="${EMULATOR_DEVICE}"
ENV CONTAINER_ARCH="${TARGETARCH}"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bzip2 \
        ca-certificates \
        curl \
        feh \
        fluxbox \
        libasound-dev \
        libdbus-glib-1-2 \
        libdrm-dev \
        libgbm-dev \
        libnss3 \
        libpulse-dev \
        libxcursor1 \
        libxkbcommon-dev \
        libxshmfence-dev \
        sudo \
        unzip \
        wget \
        wmctrl \
        x11-utils \
        x11vnc \
        xauth \
        xterm \
        xvfb && \
    if [[ "${TARGETARCH}" == "arm64" ]]; then \
        apt-get install -y --no-install-recommends \
            adb \
            android-sdk-platform-tools-common \
            fastboot; \
    fi && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

#============================================
# Install Android tooling by architecture
#============================================
RUN mkdir -p "${ANDROID_SDK_ROOT}" && \
    if [[ "${TARGETARCH}" == "amd64" ]]; then \
        wget -q "https://dl.google.com/android/repository/${ANDROID_CMD}" -O "/tmp/${ANDROID_CMD}" && \
        mkdir -p /tmp/android-sdk "${ANDROID_SDK_ROOT}/cmdline-tools" && \
        unzip -q "/tmp/${ANDROID_CMD}" -d /tmp/android-sdk && \
        mv /tmp/android-sdk/cmdline-tools "${ANDROID_SDK_ROOT}/cmdline-tools/latest" && \
        yes Y | sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" --licenses && \
        yes Y | sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" --verbose --no_https ${ANDROID_SDK_PACKAGES} && \
        echo "no" | avdmanager --verbose create avd --force --name "${EMULATOR_NAME}" --device "${EMULATOR_DEVICE}" --package "${EMULATOR_PACKAGE}"; \
    else \
        printf '%s\n' 'ARM64 image: Appium and adb are enabled. Android emulator creation is skipped because nested virtualization is not available inside Docker on Apple Silicon.' > /opt/android/APPLE_SILICON_NOTES.txt; \
    fi && \
    rm -rf /tmp/android-sdk /tmp/${ANDROID_CMD}

#====================================
# Install Node.js, npm and Appium
#====================================
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    npm install -g npm && \
    npm install -g appium --unsafe-perm=true --allow-root && \
    appium driver install uiautomator2 && \
    npm cache clean --force && \
    apt-get clean && \
    rm -rf /tmp/* /var/lib/apt/lists/*

#===================
# Alias
#===================
ENV EMU=./start_emu.sh
ENV EMU_HEADLESS=./start_emu_headless.sh
ENV EMU_AUTO=./start_android.sh
ENV VNC=./start_vnc.sh
ENV APPIUM=./start_appium.sh

#===================
# Ports
#===================
ENV APPIUM_PORT=4723

#=========================
# Copying Scripts to root
#=========================
COPY . /

RUN chmod a+x script_utils.sh && \
    chmod a+x start_android.sh && \
    chmod a+x start_appium.sh && \
    chmod a+x start_emu.sh && \
    chmod a+x start_emu_headless.sh && \
    chmod a+x start_vnc.sh

#=======================
# framework entry point
#=======================
CMD ["/bin/bash"]
