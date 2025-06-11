#!/bin/sh

# set -e -o pipefail

if [ -n "$BASH_SOURCE" ]; then
  cd "$(dirname "${BASH_SOURCE[0]}")"
else
  cd "$(dirname "$0")"
fi

IMAGE_NAME="onekey-emulator:latest"
REPO_PATH=""

if [ "$#" -gt 1 ]; then
    echo "Usage: $0 [pro-emu] [1s-emu]" >&2
    return 1 2>/dev/null || exit 1
fi

if [ -n "$1" ] && [ "$1" != "pro-emu" ] && [ "$1" != "1s-emu" ]; then
    echo "Error: argument must be 'pro-emu', '1s-emu'." >&2
    return 1 2>/dev/null || exit 1
fi

# Check if IMAGE_NAME image exists
if ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
    echo "$IMAGE_NAME not found! pulling johnwanzi/onekey-emulator:latest..."
    docker pull johnwanzi/onekey-emulator:latest
    docker tag johnwanzi/onekey-emulator:latest "$IMAGE_NAME"
else
    echo "find $IMAGE_NAME"
fi

# function to configure environment
env_config() {
    if [ "$(uname)" = "Linux" ]; then
        # Check DISPLAY environment variable, set to :0 if not set
        if [ -z "$DISPLAY" ]; then
            export DISPLAY=:0
        fi

        # Check if xhost is installed, install if not
        if ! command -v xhost > /dev/null 2>&1; then
            echo "xhost not found, installing..."
            if command -v apt-get > /dev/null 2>&1; then
                sudo apt-get update && sudo apt-get install -y x11-xserver-utils
            elif command -v yum > /dev/null 2>&1; then
                sudo yum install -y xorg-x11-server-utils
            else
                echo "No supported package manager found for installing xhost." >&2
                return 1 2>/dev/null || exit 1
            fi
        fi
        echo "Enabling xhost for Docker..."
        xhost +local:docker
    fi

    if [ "$(uname)" = "Darwin" ]; then
        # Check if XQuartz is installed, install if not
        if ! [ -d "/Applications/Utilities/XQuartz.app" ]; then
            echo "XQuartz not found, installing via Homebrew..."
            brew install --cask xquartz
        else
            echo "XQuartz is already installed."
        fi

        # Allow connections from network clients
        defaults write org.xquartz.X11 nolisten_tcp -bool false

        # Restart XQuartz
        killall XQuartz 2>/dev/null
        open -a XQuartz

        xhost + 127.0.0.1
    fi
}

# function to build pro emulator
build_pro_emu() {
    # check firmware-pro repository
    if [ ! -d "firmware-pro" ]; then
        echo "firmware-pro directory not found, cloning..."
        git clone --recursive https://github.com/OneKeyHQ/firmware-pro.git
        cd firmware-pro
        git checkout emulator
        git submodule update --init --recursive
        cd ..
    fi
    REPO_PATH="firmware-pro"

    if [ "$(uname)" = "Linux" ]; then
        # Run interactive Docker container with X11 forwarding and current directory mounted
        docker run -it --rm \
        --env DISPLAY=$DISPLAY \
        --env XAUTHORITY=$XAUTHORITY \
        -e XDG_RUNTIME_DIR=/tmp/$(id -u)-runtime-dir \
        -v /tmp/.X11-unix:/tmp/.X11-unix \
        -v $(pwd):/home \
        --privileged --network=host "$IMAGE_NAME" bash -c \
        "source \$HOME/.cargo/env && \
        cd /home/$REPO_PATH && \
        git config --global --add safe.directory '*' && \
        git lfs pull && git lfs checkout && \
        cd / && \
        poetry run make -C /home/$REPO_PATH/core build_unix && \
        poetry run /home/$REPO_PATH/core/emu.py && \
        exec bash"
    elif [ "$(uname)" = "Darwin" ]; then
        docker run -it --rm \
        -e DISPLAY=host.docker.internal:0 \
        -e XDG_RUNTIME_DIR=/tmp/$(id -u)-runtime-dir \
        -v $(pwd):/home \
        --privileged --network=host "$IMAGE_NAME" bash -c \
        "source \$HOME/.cargo/env && \
        cd /home/$REPO_PATH && \
        git config --global --add safe.directory '*' && \
        git lfs pull && git lfs checkout && \
        cd / && \
        poetry run make -C /home/$REPO_PATH/core build_unix && \
        poetry run /home/$REPO_PATH/core/emu.py && \
        exec bash"
    fi
}

# function to build 1s emulator
build_1s_emu() {
    # check firmware-classic1s repository
    if [ ! -d "firmware-classic1s" ]; then
        echo "firmware-classic1s directory not found."
        git clone --recursive https://github.com/OneKeyHQ/firmware-classic1s.git
        cd firmware-classic1s
        git checkout emulator
        git submodule update --init --recursive
        cd ..
    fi
    REPO_PATH="firmware-classic1s"

    if [ "$(uname)" = "Linux" ]; then
        docker run -it --rm \
        --env DISPLAY=$DISPLAY \
        --env XAUTHORITY=$XAUTHORITY \
        -e XDG_RUNTIME_DIR=/tmp/$(id -u)-runtime-dir \
        -v /tmp/.X11-unix:/tmp/.X11-unix \
        -v $(pwd):/home \
        --privileged --network=host "$IMAGE_NAME" bash -c \
        "source \$HOME/.cargo/env && \
        cd /home/$REPO_PATH && \
        git config --global --add safe.directory '*' && \
        cd / && \
        export EMULATOR=1 DEBUG_LINK=0 && \
        poetry run make -C /home/$REPO_PATH/legacy build_emu && \
        ./home/$REPO_PATH/legacy/firmware/onekey_emu.elf\
        exec bash"
    elif [ "$(uname)" = "Darwin" ]; then
        docker run -it --rm \
        -e DISPLAY=host.docker.internal:0 \
        -e XDG_RUNTIME_DIR=/tmp/$(id -u)-runtime-dir \
        -v $(pwd):/home \
        --privileged --network=host "$IMAGE_NAME" bash -c \
        "source \$HOME/.cargo/env && \
        cd /home/$REPO_PATH && \
        git config --global --add safe.directory '*' && \
        cd / && \
        export EMULATOR=1 DEBUG_LINK=0 && \
        poetry run make -C /home/$REPO_PATH/legacy build_emu && \
        ./home/$REPO_PATH/legacy/firmware/onekey_emu.elf\
        exec bash"
    fi
}

env_config

# Check the first argument
if [ "$1" = "pro-emu" ]; then
    build_pro_emu
elif [ "$1" = "1s-emu" ]; then
    build_1s_emu
fi
