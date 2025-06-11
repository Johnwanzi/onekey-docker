# Docker Emulator Scripts

This folder contains scripts and helper files for running hardware wallet emulators (such as OneKey Pro and Classic 1s) in Docker containers with GUI support.

## Features
- Run emulators in Docker on Linux and macOS
- Automatic environment setup for X11 forwarding (GUI display)

## Setup

### Prerequisites
- Docker
- (macOS only) [XQuartz](https://www.xquartz.org/) for X11 display
- (Linux only) xhost and X11 server

## Usage

### Linux
1. Ensure your X11 server is running and `xhost +local:docker` is enabled.
2. Run the emulator script:
   ```bash
   bash build-emu.sh pro-emu
   # or
   bash build-emu.sh 1s-emu
   ```

### macOS
1. Install and start XQuartz. In XQuartz preferences, enable "Allow connections from network clients".
2. In a terminal, run:
   ```bash
   xhost + 127.0.0.1
   bash build-emu.sh pro-emu
   # or
   bash build-emu.sh 1s-emu
   ```

## Notes
- The script will automatically clone required firmware repositories if missing.
- On macOS, GUI output is forwarded to XQuartz using `DISPLAY=host.docker.internal:0`.
- On Linux, GUI output is forwarded using the local X11 socket. 