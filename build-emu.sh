#!/bin/sh

# Default image name
SRC_IMAGE_NAME="johnwanzi/onekey-emu:latest"
IMAGE_NAME="onekey-emu:latest"
REPO_PATH=""
EMU_TYPE=""
X11_ENABLED=0

# Ports for VNC mode
VNC_WEBSOCKET_PORT=6088
VNC_DEV_UDP_PORT=54395

if [ -n "$BASH_SOURCE" ]; then
  cd "$(dirname "${BASH_SOURCE[0]}")"
else
  cd "$(dirname "$0")"
fi

# Argument parsing
for arg in "$@"; do
  case $arg in
    pro-emu|1s-emu)
      if [ -n "$EMU_TYPE" ]; then
        echo "Error: Only one of 'pro-emu' or '1s-emu' can be specified." >&2
        return 1 2>/dev/null || exit 1
      fi
      EMU_TYPE="$arg"
      ;;
    --x11)
      X11_ENABLED=1
      ;;
    *)
      echo "Usage: $0 [pro-emu|1s-emu] [--x11]" >&2
      return 1 2>/dev/null || exit 1
      ;;
  esac
done

if [ -z "$EMU_TYPE" ]; then
  echo "Usage: $0 [pro-emu|1s-emu] [--x11]" >&2
  return 1 2>/dev/null || exit 1
fi

# Check if IMAGE_NAME image exists
if ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
    echo "$IMAGE_NAME not found! pulling $SRC_IMAGE_NAME..."
    docker pull "$SRC_IMAGE_NAME"
    docker tag "$SRC_IMAGE_NAME" "$IMAGE_NAME"
    docker rmi "$SRC_IMAGE_NAME"
else
    echo "Found $IMAGE_NAME"
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
        echo "X11 has compatible problems on macOS, please use VNC to connect to the emulator."
        return 1 2>/dev/null || exit 1
    fi
}

# function to build pro emulator
build_pro_emu_x11() {
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
        echo "X11 has compatible problems on macOS, please use VNC to connect to the emulator."
        return 1 2>/dev/null || exit 1
    fi
}

# function to build 1s emulator
build_1s_emu_x11() {
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
        echo "X11 has compatible problems on macOS, please use VNC to connect to the emulator."
        return 1 2>/dev/null || exit 1
    fi
}

# function to build pro emulator using VNC
build_pro_emu_vnc() {
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

    docker run -it --rm \
        -e REPO_PATH=$REPO_PATH \
        -p $VNC_WEBSOCKET_PORT:6080 \
        -p $VNC_DEV_UDP_PORT:54395 \
        -e DISPLAY=$DISPLAY \
        -e XDG_RUNTIME_DIR=/tmp/$(id -u)-runtime-dir \
        -v $(pwd):/home "$IMAGE_NAME" bash -c \
        "source \$HOME/.cargo/env && \
        cd /home/$REPO_PATH && \
        git config --global --add safe.directory '*' && \
        git lfs pull && git lfs checkout && \
        cd / && \
        poetry run make -C /home/$REPO_PATH/core build_unix && \
        DISPLAY=:1 /startup-pro-emu.sh && \
        exec bash"
}

# function to build 1s emulator using VNC
build_1s_emu_vnc() {
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

    docker run -it --rm \
        -e REPO_PATH=$REPO_PATH \
        -p $VNC_WEBSOCKET_PORT:6080 \
        -p $VNC_DEV_UDP_PORT:54395 \
        -v $(pwd):/home "$IMAGE_NAME" bash -c \
        "source \$HOME/.cargo/env && \
        cd /home/$REPO_PATH && \
        git config --global --add safe.directory '*' && \
        cd / && \
        export EMULATOR=1 DEBUG_LINK=0 && \
        poetry run make -C /home/$REPO_PATH/legacy build_emu && \
        DISPLAY=:1 /startup-1s-emu.sh && \
        exec bash"
}

if [ "$X11_ENABLED" = "1" ]; then
    env_config
    # Check the first argument
    if [ "$EMU_TYPE" = "pro-emu" ]; then
        build_pro_emu_x11
    elif [ "$EMU_TYPE" = "1s-emu" ]; then
        build_1s_emu_x11
    fi
else
    if [ "$EMU_TYPE" = "pro-emu" ]; then
        build_pro_emu_vnc
    elif [ "$EMU_TYPE" = "1s-emu" ]; then
        build_1s_emu_vnc
    fi
fi
