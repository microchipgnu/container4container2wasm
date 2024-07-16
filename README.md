# container2container2wasm

![image](https://github.com/user-attachments/assets/b8335f4a-adaf-4d58-ba6e-3d75e4b13239)

This project provides a workflow to convert Docker images to WebAssembly (WASM) modules using the `container2wasm` tool. The conversion process is encapsulated in a Docker container, and the output files are copied to the local machine after the conversion is complete.

## Prerequisites

- Docker
- Bash

## Project Structure

```plaintext
.
├── Dockerfile
├── docker-entrypoint.sh
├── run_conversion.sh
└── src
    ├── example1
    │   ├── Dockerfile
    │   ├── arch
    │   └── target
    └── example2
        ├── image
        ├── arch
        └── target
```

- **Dockerfile**: Builds the Docker image with necessary dependencies.
- **docker-entrypoint.sh**: Entrypoint script that performs the Docker image to WASM conversion.
- **run_conversion.sh**: Bash script to automate the entire workflow.
- **src**: Directory containing source Dockerfiles or image references along with target architecture and target type files.

## Usage

### Step 1: Prepare the Source Directory

Ensure your `src` directory contains subdirectories for each conversion task. Each subdirectory should contain:

- `Dockerfile` or `image` file specifying the Docker image or Dockerfile to use.
- `arch` file specifying the target architecture (e.g., `amd64`).
- `target` file specifying the target compiler (`wasi` or `emscripten`).

### Step 2: Run the Conversion Script

Execute the `run_conversion.sh` script to build the Docker image, run the container, perform the conversion, and copy the output files to the local `out` directory.

```sh
./run_conversion.sh
```

### Step 3: Verify the Output

The output files will be copied to the `out` directory in your local machine. Each subdirectory in `src` will have a corresponding subdirectory in `out` with the converted WASM files.

## Example

Assuming you have the following structure in your `src` directory:

```plaintext
src
├── example1
│   ├── Dockerfile 
│   ├── arch
│   └── target
└── example2
    ├── image
    ├── arch
    └── target
```

`example1` uses a Dockerfile for building the image.  
`example2` uses a pre-built image specified in the `image` file.

Run the conversion script:

```sh
./run_conversion.sh
```

The output files will be copied to the `out` directory:


```
out
├── example1-container
│   ├── part-00.wasm
│   ├── part-01.wasm
│   └── ...
└── example2-container
    ├── part-00.wasm
    ├── part-01.wasm
    └── ...
```
