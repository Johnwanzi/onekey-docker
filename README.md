# Docker Emulator Scripts

This folder contains scripts and helper files for running hardware wallet emulators (such as OneKey Pro and Classic 1s) in Docker containers with GUI support.

## Features
- Run emulators in Docker on Linux and macOS
- Automatic environment setup for X11 forwarding (GUI display)

## Setup

### Prerequisites
the following jobs have already been handled in the build-emu.sh script, so developers do not need to worry about them.
- Docker
- macOS host
   - [XQuartz](https://www.xquartz.org/) for X11 display
   - Make sure `xhost + 127.0.0.1` is set.
- Linux host
   - install xhost and X11 server.
   - Make sure `xhost +local:docker` is enabled.


## Usage

### Linux && macOS
1. Support compile/run emulator of `firmware-pro` and `firmware-classic1s` 
   ```bash
   bash build-emu.sh pro-emu
   # or
   bash build-emu.sh 1s-emu
   ```

## Notes
- The script will automatically clone required firmware repositories if missing.
- On macOS, GUI output is forwarded to XQuartz using `DISPLAY=host.docker.internal:0`.
- On Linux, GUI output is forwarded using the local X11 socket. 