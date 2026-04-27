# Android emulator Image

This repository provides two different Docker workflows depending on the target architecture. On `linux/amd64`, it can build and run an Android emulator inside Docker. On `linux/arm64`, including Apple Silicon, it provides Appium plus `adb` tooling for real-device automation, but not the Android emulator itself. The image includes the Android SDK tooling, Appium, and helper scripts for the supported paths.
  for more info --> https://medium.com/@Amr.sa/running-android-emulator-in-a-docker-container-19ecb68e1909

# Feature

- Run the Android emulator in headless or headed mode on `linux/amd64`
- Run Appium plus `adb` tooling on `linux/arm64`
- Open a Fluxbox VNC desktop with a shell for supported desktop workflows
- Come with the latest JDK LTS


# Support matrix

| Platform | Supported | Not supported |
| -------- | --------- | ------------- |
| `linux/amd64` | Build the full image, create the AVD, run `./start_emu.sh`, run `./start_emu_headless.sh`, run `./start_vnc.sh`, run `./start_appium.sh` | No additional architecture-specific limitation documented by this image |
| `linux/arm64` | Build the image, run `./start_appium.sh`, use `adb` and `fastboot`, run `./start_vnc.sh` for a desktop shell | `./start_emu.sh`, `./start_emu_headless.sh`, and any Android emulator running inside Docker |


# Not supported

- Running the Android emulator inside Docker on Apple Silicon or any other `linux/arm64` host
- Using the VNC desktop on `linux/arm64` to launch a visible Android emulator
- Treating the ARM64 image as a drop-in replacement for the AMD64 emulator image


# Apple Silicon support

This repository now supports Apple Silicon builds as an Appium plus ADB container.

- On `linux/amd64`, the image installs the Android SDK, creates the AVD, and supports `./start_emu.sh` and `./start_emu_headless.sh`.
- On `linux/arm64`, the image builds and runs on Apple Silicon, installs native `adb`, and supports `./start_appium.sh` for real-device automation.
- On `linux/arm64`, `./start_vnc.sh` opens a Fluxbox desktop with a shell, but not a runnable Android emulator.
- On `linux/arm64`, the emulator is intentionally disabled inside Docker because nested virtualization is not available in a reliable way on Apple Silicon Docker hosts.


# Setup

## Manual execution

Down below is the list of the main scripts to launch the relevant service, certain environment variables should be passed during starting the container.

1.  **build the docker image :** 

        docker build -t android-emulator .

        On Apple Silicon, build the ARM64 image explicitly:

                docker build --platform linux/arm64 -t android-emulator .

    OR for customized image

        docker build \
        --build-arg ARCH=x86_64  \
        --build-arg TARGET=google_apis_playstore\
        --build-arg API_LEVEL=36 \
        --build-arg BUILD_TOOLS=36.0.0 \
        --build-arg EMULATOR_DEVICE="Nexus 6" \
        --build-arg EMULATOR_NAME=nexus \
        -t my-android-image .  
    
2.  **Start your container:**

        docker run -it --privileged -d -p 4723:4723 --name androidContainer android-emulator  

3.  **Launch the appium session :**

        docker exec --privileged -it androidContainer bash -c "appium -p 4723"

     OR

        docker exec --privileged  -it androidContainer bash -c "./start_appium.sh"

        This is the recommended path on Apple Silicon and on all `linux/arm64` hosts.

 
4.  **Start the emulator in headless mode :**
   
        docker exec --privileged -it -e EMULATOR_TIMEOUT=300 androidContainer bash -c "./start_emu_headless.sh"

        This mode is supported on `amd64` only.

5.  **Starting VNC server:**

        docker exec --privileged -it androidContainer bash -c "./start_vnc.sh"

        On `linux/arm64`, this gives you a Fluxbox desktop and shell access only. It does not enable the Android emulator.



## Launch emulator in headed mode (`amd64` only)


1.  **The following command must be used to initiate the Docker container:**

        docker run -it -d -p 5900:5900 --name androidContainer -e VNC_PASSWORD=password --privileged android-emulator

2.  **Instantiate the VNC service by running:**

        docker exec --privileged -it androidContainer bash -c "./start_vnc.sh"

3.  **Connect to the VNC server via remmina or any VNC viewer, on:**
          
        localhost:5900
    
4.  **On `amd64` only, open Applications -> Shells -> Bash in the VNC viewer and run:** 

        #: ./start_emu.sh

        On Apple Silicon or any other `arm64` Docker host, the VNC session only shows the Fluxbox desktop. The Android emulator is disabled in Docker on that architecture, so use `./start_appium.sh` instead.
 
<a href="https://ibb.co/pPq0bn9"><img src="https://i.ibb.co/pPq0bn9/vnc.png" alt="vnc" border="0"></a>       <a href="https://ibb.co/cJB6qkX"><img src="https://i.ibb.co/cJB6qkX/gif.gif"       alt="gif" border="0"></a>
    
Note:
- The "start_emu.sh" script will start the emulator in a visible mode, therefore it should not be used for integration with a pipeline such as GitHub Actions or CircleCI. Instead, use the "start_emu_headless.sh" script.
- By default, the emulator device is 'Nexus 6' (emulator name: nexus).
- It is not necessary to launch all services in the docker-compose file, instead you should only enable the services you require, and comment out the others in the file.


## Using Docker-compose

The Docker Compose file simplifies the process of starting the service. It includes multiple services, such as launching the emulator with the Appium instance or launching the VNC server. You have the flexibility to enable or disable any service based on your needs.
    
    docker compose up

On Apple Silicon, `docker compose up` starts the default ARM64-safe path, which launches Appium instead of the Android emulator.

## Environments

**When manually starting the container, ensure to set the necessary environment variables for proper operation** 

| Environments      | Description                                                                                              | Required          |  Service   |
| ----------------- | -------------------------------------------------------------------------------------------------------- | ----------------- | -----------|
| APPIUM_PORT       | Port for the appium instance                                                                             | optional          | Android    |
| VNC_PASSWORD      | Password needed to connect to VNC Server                                                                 | optional          | VNC        |
| OSTYPE            | linux or macos/darwin                                                                                    | optional          | Android    |
| EMULATOR_TIMEOUT  | emulator booting up timeoue, default 240 second                                                          | optional          | Android    |
| HW_ACCEL_OVERRIDE | Pass aceel options e.g "-accel on" or "-aceel off"                                                       | optional          | Android    

## Kill the container

-   **Run the following command to kill and remove the container:** 

        docker rm -f androidContainer
