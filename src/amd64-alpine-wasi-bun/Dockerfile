# Use an appropriate base image
FROM alpine:3.17

# Install required dependencies
RUN apk add --no-cache curl bash

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash

# Source Bun's environment and set Bun's installation path
ENV BUN_INSTALL="/root/.bun"
ENV PATH="${BUN_INSTALL}/bin:${PATH}"

# Default command
CMD ["bash"]