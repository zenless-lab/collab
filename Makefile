DOCKER_IMAGE_NAME := openlab
BASE_IMAGE_NAME := nvcr.io/nvidia/cuda
BASE_IMAGE_TAG := 12.4.1-cudnn-devel-ubuntu22.04
UV_VERSION := 0.8.3
PYTHON_VERSION := 3.12

.PHONY: all lock build-% build
all: lock build

# Lock image dependencies
# This will generate requirements.txt files from requirements.in files
# using uv pip compile. Install uv if you don't have it:
# ``` bash
# pipx install uv
# ```
requirements.txt: requirements.in
	uv pip compile $< -o $@ --python-platform linux

requirements%.txt: requirements%.in
	uv pip compile $< -o $@ --python-platform linux

DEP_FILES = $(wildcard requirements*.in)
LOCK_FILES = $(DEP_FILES:.in=.txt)

lock: $(LOCK_FILES)

# Build Docker images for different targets
TARGETS := vscode notebook datascience torch jax nlp cv
build-%:
	@echo "Building Docker image: $(DOCKER_IMAGE_NAME)"
	docker build \
		-t $(DOCKER_IMAGE_NAME):$* \
		--target $* \
		--build-arg BASE_IMAGE_NAME=$(BASE_IMAGE_NAME) \
		--build-arg BASE_IMAGE_TAG=$(BASE_IMAGE_TAG) \
		--build-arg UV_VERSION=$(UV_VERSION) \
		--build-arg PYTHON_VERSION=$(PYTHON_VERSION) \
		.
build: $(addprefix build-, $(TARGETS))
