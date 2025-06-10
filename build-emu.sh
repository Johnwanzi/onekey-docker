#!/bin/sh

# set -e -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

# IMAGE_NAME="onkey-emu:latest"
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

# Check the first argument
if [ "$1" = "pro-emu" ]; then
    if [ ! -d "firmware-pro" ]; then
        echo "firmware-pro directory not found, cloning..."
        git clone --recursive https://github.com/OneKeyHQ/firmware-pro.git
        cd firmware-pro
        git checkout emulator
        git submodule update --init --recursive
        cd ..
    fi
    REPO_PATH="firmware-pro"
fi

# Check if IMAGE_NAME image exists
if ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
    echo "$IMAGE_NAME not found! pulling johnwanzi/onekey-emulator:latest..."
    docker pull johnwanzi/onekey-emulator:latest
    docker tag johnwanzi/onekey-emulator:latest "$IMAGE_NAME"
else
    echo "find $IMAGE_NAME"
fi

# If the system is Linux, check if xhost is installed, if true, enable xhost for Docker
if [ "$(uname)" = "Linux" ]; then
    # check DISPLAY environment variable, if not set, set it to :0
    if [ -z "$DISPLAY" ]; then
        export DISPLAY=:0
    fi

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

# If the system is macOS, add a TODO
# if [ "$(uname)" = "Darwin" ]; then
#     # TODO: Add macOS-specific logic here if needed
# fi

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
   git config --global --add safe.directory /home/$REPO_PATH && \
   git lfs pull && git lfs checkout && \
   cd / && \
   poetry run make -C /home/$REPO_PATH/core build_unix && \
   poetry run /home/$REPO_PATH/core/emu.py && \
   exec bash"
