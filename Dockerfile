FROM ubuntu:22.04

USER root

# install dependencies
RUN apt-get update && apt-get install --no-install-recommends -y \
    scons libsdl2-dev libsdl2-image-dev llvm-dev libclang-dev clang \
    python3-pip build-essential git curl protobuf-compiler xvfb git-lfs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir poetry
RUN ln -s /usr/bin/python3 /usr/bin/python

# install rustup (and cargo, rustc)
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

RUN rustup default nightly && rustup update

# clone firmware-pro project
RUN git clone --recursive https://github.com/OneKeyHQ/firmware-pro.git /firmware-pro

WORKDIR /firmware-pro
RUN git checkout emulator
RUN git lfs pull && git lfs checkout
RUN git config --global --add safe.directory /firmware-pro

RUN poetry install --no-roo

ENV XDG_RUNTIME_DIR="/root/.xdg_runtime"
RUN mkdir -p /root/.xdg_runtime


CMD ["bash"] 