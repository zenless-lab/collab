ARG BASE_IMAGE_NAME=nvcr.io/nvidia/cuda
ARG BASE_IMAGE_TAG=12.4.1-cudnn-devel-ubuntu22.04

ARG UV_VERSION=0.8.3
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv


FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG} AS base

ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/zsh

RUN --mount=type=bind,source=setup.sh,target=/tmp/setup.sh \
    bash /tmp/setup.sh \
    && rm -rf /var/lib/apt/lists/*

COPY --from=uv /uv /uvx /bin/

ARG PYTHON_VERSION=3.12
RUN uv python install --default ${PYTHON_VERSION}

WORKDIR /workspace
SHELL [ "/bin/zsh", "-c" ]
ENTRYPOINT []

FROM base AS vscode

RUN curl -fsSL https://code-server.dev/install.sh | sh \
    && code-server \
    --install-extension ms-python.python \
    --install-extension ms-toolsai.jupyter \
    --install-extension ms-vscode.hexeditor \
    --install-extension EditorConfig.EditorConfig \
    --install-extension charliermarsh.ruff \
    --install-extension tamasfe.even-better-toml \
    --install-extension redhat.vscode-yaml

ENV SHELL=/bin/zsh
CMD ["code-server", "--bind-addr=0.0.0.0:8080", "--auth=none", "--disable-telemetry", "--disable-update-check"]
EXPOSE 8080
VOLUME [ "/workspace" ]

FROM base AS notebook

ARG PYTHON_VERSION=3.12
RUN --mount=type=bind,source=requirements.notebook.txt,target=/tmp/requirements.notebook.txt \
    uv venv -p ${PYTHON_VERSION} \
    && echo "source /workspace/.venv/bin/activate" >> /root/.zshrc \
    && echo "source /workspace/.venv/bin/activate" >> /root/.bashrc \
    && uv pip install --no-cache-dir -r /tmp/requirements.notebook.txt \
    && sed -i "s/ZSH_THEME=\".*\"/ZSH_THEME=\"minimal\"/" /root/.zshrc

ENV SHELL=/bin/zsh
CMD ["uv", "run", "jupyter", "lab", "--ip='*'", "--port=8888", "--no-browser", "--allow-root", "--NotebookApp.token=''", "--NotebookApp.password=''"]
EXPOSE 8888
VOLUME [ "/workspace" ]


FROM notebook AS datascience

ARG DEPS_FILE=datascience
RUN --mount=type=bind,source=requirements.${DEPS_FILE}.txt,target=/tmp/requirements.${DEPS_FILE}.txt \
    uv pip install --no-cache-dir -r /tmp/requirements.${DEPS_FILE}.txt

FROM notebook AS torch

ARG DEPS_FILE=torch
RUN --mount=type=bind,source=requirements.${DEPS_FILE}.txt,target=/tmp/requirements.${DEPS_FILE}.txt \
    uv pip install --no-cache-dir -r /tmp/requirements.${DEPS_FILE}.txt

FROM notebook AS jax

ARG DEPS_FILE=jax
RUN --mount=type=bind,source=requirements.${DEPS_FILE}.txt,target=/tmp/requirements.${DEPS_FILE}.txt \
    uv pip install --no-cache-dir -r /tmp/requirements.${DEPS_FILE}.txt

FROM notebook AS nlp

ARG DEPS_FILE=nlp
RUN --mount=type=bind,source=requirements.${DEPS_FILE}.txt,target=/tmp/requirements.${DEPS_FILE}.txt \
    uv pip install --no-cache-dir -r /tmp/requirements.${DEPS_FILE}.txt

FROM notebook AS cv

ARG DEPS_FILE=cv
RUN --mount=type=bind,source=requirements.${DEPS_FILE}.txt,target=/tmp/requirements.${DEPS_FILE}.txt \
    uv pip install --no-cache-dir -r /tmp/requirements.${DEPS_FILE}.txt

FROM notebook AS final

RUN --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
    uv pip install --no-cache-dir -r /tmp/requirements.txt
