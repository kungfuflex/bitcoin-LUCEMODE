# Use a Debian-based image as the build environment
FROM debian:bookworm-slim as builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libtool \
    autotools-dev \
    automake \
    pkg-config \
    bsdmainutils \
    python3 \
    libssl-dev \
    libevent-dev \
    libboost-system-dev \
    libboost-filesystem-dev \
    libboost-chrono-dev \
    libboost-program-options-dev \
    libboost-test-dev \
    libboost-thread-dev \
    libsqlite3-dev \
    libminiupnpc-dev \
    libzmq3-dev \
    ca-certificates \
    git

# Copy the source code
COPY . /usr/src/libre-relay

# Build libre-relay
WORKDIR /usr/src/libre-relay
RUN ./autogen.sh
RUN ./configure --disable-wallet --with-gui=no
RUN make -j$(nproc)
RUN make install

# Use a slim Debian image for the final image
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 \
    libevent-2.1-7 \
    libboost-system1.74.0 \
    libboost-filesystem1.74.0 \
    libboost-chrono1.74.0 \
    libboost-program-options1.74.0 \
    libboost-thread1.74.0 \
    libsqlite3-0 \
    libminiupnpc17 \
    libzmq5 \
    && rm -rf /var/lib/apt/lists/*

# Copy the built binaries from the builder stage
COPY --from=builder /usr/local/bin/bitcoind /usr/local/bin/
COPY --from=builder /usr/local/bin/bitcoin-cli /usr/local/bin/
COPY --from=builder /usr/local/bin/bitcoin-tx /usr/local/bin/

# Create a dedicated user and group for bitcoind
RUN groupadd --system bitcoin && useradd --system -g bitcoin bitcoin

# Create Bitcoin data directory and set permissions
RUN mkdir -p /home/bitcoin/.bitcoin && chown -R bitcoin:bitcoin /home/bitcoin/.bitcoin

# Expose the default Bitcoin P2P and RPC ports
EXPOSE 8333 18333 8332 18332

# Set the data directory for bitcoind
ENV BITCOIN_DATA=/home/bitcoin/.bitcoin

# Switch to the bitcoin user
USER bitcoin

# Define the entrypoint for the container
ENTRYPOINT ["bitcoind", "-datadir=/home/bitcoin/.bitcoin"]

# Default command to run bitcoind
CMD ["-printtoconsole"]
