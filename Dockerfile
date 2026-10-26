# The Discord bot. Platforms that deploy from a GitHub repository build this file; the container needs
# DISCORD_TOKEN and DOGMA_WEB_URL in its environment and listens on no port.

# MARK: - Build

FROM swift:6.4.1-noble AS build
WORKDIR /build

# The manifest names every target, tests included, and SwiftPM checks their directories when it loads it.
COPY Package.swift Package.resolved ./
COPY Sources ./Sources
COPY Tests ./Tests
RUN swift build -c release --product DogmaBot --static-swift-stdlib

# The executable, the resource bundles it loads next to itself (DogmaKit's sde.bin, text-en.bin) and the static
# backtracer for crash reports. The bundles are named *.bundle by the swift-build build system, the default since
# Swift 6.4, and *.resources by the native one; the build fails if the data files are missing.
WORKDIR /staging
RUN BIN="$(swift build --package-path /build -c release --show-bin-path)" \
    && cp "$BIN/DogmaBot" ./ \
    && find -L "$BIN/" -maxdepth 1 \( -name '*.bundle' -o -name '*.resources' \) -exec cp -Ra {} ./ \; \
    && ls ./*/sde.bin ./*/text-en.bin \
    && cp /usr/libexec/swift/linux/swift-backtrace-static ./

# MARK: - Run

FROM ubuntu:noble

# Root certificates for TLS to Discord; libxml2 for FoundationXML, which reads fits in the game's XML format.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tzdata libxml2 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app bot
WORKDIR /app
COPY --from=build --chown=bot:bot /staging /app

ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no,swift-backtrace=./swift-backtrace-static

USER bot:bot
ENTRYPOINT ["./DogmaBot"]
