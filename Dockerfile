FROM openjdk:18-jdk-slim

LABEL maintainer "Amr Salem"

ENV DEBIAN_FRONTEND noninteractive

WORKDIR /
#=============================
# Install Dependenices 
#=============================
RUN apt update && apt install -y curl sudo wget unzip bzip2 libdrm-dev libxkbcommon-dev libgbm-dev libasound-dev libnss3 libxcursor1 libpulse-dev libxshmfence-dev xauth xvfb x11vnc fluxbox wmctrl libdbus-glib-1-2

#==============================
# Android SDK ARGS
#==============================
ENV ANDROID_ARCH="x86_64" 
ENV ANDROID_TARGET="google_apis_playstore"  
ENV API_LEVEL="33" 
ENV BUILD_TOOLS="33.0.1"
ARG ANDROID_ARCH=$ANDROID_ARCH
ARG ANDROID_TARGET=$ANDROID_TARGET     
ARG ANDROID_API_LEVEL="android-$API_LEVEL"
ARG ANDROID_APIS="$ANDROID_TARGET;$ANDROID_ARCH"
ARG ANDROID_BUILD_TOOLS_VERSION=$BUILD_TOOLS
ARG ANDROID_EMULATOR_PACKAGE="system-images;${ANDROID_API_LEVEL};${ANDROID_APIS}"
ARG ANDROID_PLATFORM_VERSION="platforms;${ANDROID_API_LEVEL}"
ARG ANDROID_BUILD_TOOLS="build-tools;${ANDROID_BUILD_TOOLS_VERSION}"
ARG ANDROID_CMD_VERSION="commandlinetools-linux-8092744_latest.zip"
ARG ANDROID_SDK_PACKAGES="${ANDROID_EMULATOR_PACKAGE} ${ANDROID_PLATFORM_VERSION} ${ANDROID_BUILD_TOOLS} platform-tools"

#==============================
# Set JAVA_HOME - SDK
#==============================
ENV ANDROID_SDK_ROOT=/opt/android
ENV PATH "$PATH:$ANDROID_SDK_ROOT/cmdline-tools/tools:$ANDROID_SDK_ROOT/cmdline-tools/tools/bin:$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/tools/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/build-tools/${ANDROID_BUILD_TOOLS_VERSION}"
ENV DOCKER="true"

#============================================
# Install required Android CMD-line tools
#============================================
RUN wget https://dl.google.com/android/repository/${ANDROID_CMD_VERSION} -P /tmp && \
              unzip -d $ANDROID_SDK_ROOT /tmp/$ANDROID_CMD_VERSION && \
              mkdir -p $ANDROID_SDK_ROOT/cmdline-tools/tools && cd $ANDROID_SDK_ROOT/cmdline-tools &&  mv NOTICE.txt source.properties bin lib tools/  && \
              cd $ANDROID_SDK_ROOT/cmdline-tools/tools && ls

#============================================
# Install required package using SDK manager
#============================================
RUN yes Y | sdkmanager --licenses 
RUN yes Y | sdkmanager --verbose --no_https ${ANDROID_SDK_PACKAGES} 

#============================================
# Create required emulator
#============================================
ARG EMULATOR_NAME="nexus"
ARG EMULATOR_DEVICE="Nexus 6"
ENV EMULATOR_NAME=$EMULATOR_NAME
ENV EMULATOR_DEVICE_NAME=$EMULATOR_DEVICE
RUN echo "no" | avdmanager --verbose create avd --force --name "${EMULATOR_NAME}" --device "${EMULATOR_DEVICE}" --package "${ANDROID_EMULATOR_PACKAGE}"

#====================================
# Install latest nodejs, npm & appium
#====================================
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash && \
    apt-get -qqy install nodejs && \
    npm i -g appium@next --unsafe-perm=true --allow-root && \
    appium driver install uiautomator2 && \
    exit 0 && \
    npm cache clean && \
    apt-get remove --purge -y npm && \  
    apt-get autoremove --purge -y && \
    apt-get clean && \
    rm -Rf /tmp/* && rm -Rf /var/lib/apt/lists/*

#===================
# Ports
#===================
ENV APPIUM_PORT=4723

#=========================
# Copying Scripts to root
#=========================
COPY . /

RUN chmod a+x start_vnc.sh && \
    chmod a+x start_emu.sh && \
    chmod a+x start_appium.sh && \
    chmod a+x start_emu_headless.sh
    
#=======================
# framework entry point
#=======================
CMD [ "/bin/bash" ]
