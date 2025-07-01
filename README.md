# Docker Emulator Scripts

This folder contains scripts and helper files for running hardware wallet emulators (such as OneKey Pro and Classic 1s) in Docker containers with GUI or VNC support.

## Features
- Run emulators in Docker on Linux and macOS
- Automatic environment setup for X11 forwarding (Linux GUI display)
- VNC remote desktop support (recommended for macOS)

## Usage

### Linux (X11 GUI, recommended for local use)
To build and run the `firmware-pro` or `firmware-classic1s` emulator with native X11 GUI (Linux only):
```bash
bash build-emu.sh pro-emu --x11
# or
bash build-emu.sh 1s-emu --x11
```
> Requires a local X11 environment. The script will automatically configure DISPLAY and xhost.

### Linux/macOS (VNC, recommended for remote or macOS)
To build and run the emulator using VNC (default, and the only option for macOS):
```bash
bash build-emu.sh pro-emu
# or
bash build-emu.sh 1s-emu
```
> The script will pull the Docker image, clone the firmware source, and start a VNC server inside the container.

#### Accessing the Emulator via VNC
- Open your browser and go to: `http://localhost:6088` (web VNC client)
- Or use a VNC client to connect to `localhost:6088` (no password)
- The OneKey Bridge service is available on port `21333`

## Parameters
- `pro-emu`: Run the OneKey Pro emulator
- `1s-emu`: Run the Classic 1s emulator
- `--x11`: Enable X11 GUI mode (Linux only; not supported on macOS)

## Notes
- The script will automatically clone the required firmware repositories if missing.
- On macOS, X11 is not supported due to compatibility issues. Please use VNC mode.
- On Linux, you can use either X11 GUI (`--x11`) or VNC (default, recommended for remote/headless use).
- VNC port is `6088`, OneKey Bridge port is `21333`. 