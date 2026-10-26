#!/bin/sh
# Builds the fit page: dogma-cli compiled to WebAssembly with its resources, stripped and gzipped, into Web/build.
set -eu

SELF=$(cd "$(dirname "$0")/.." && pwd)
TOOLCHAIN=${SWIFT_TOOLCHAIN:-6.4.1}
SDK=${SWIFT_WASM_SDK:-swift-$TOOLCHAIN-RELEASE_wasm}
BUILD=$SELF/.build-wasm
OUT=$SELF/Web/build

usage() {
    cat <<USAGE
Usage: Scripts/build-web.sh [-h]

Builds dogma-cli for WebAssembly and lays out Web/build:
  dogma-cli.wasm   debug info stripped
  sde.bin          engine data, taken from the DogmaKit sources
  text-en.bin      English names
and a .gz next to each file for Web/serve.py. On WebAssembly DogmaKit reads the data files from the directory of
the executable, as there are no resource bundles.

Needs the open-source Swift toolchain and its Wasm SDK; Xcode's toolchain cannot target WebAssembly. With swiftly
installed the script runs its toolchain; without it, the swift in PATH (as in the swift Docker images).
  \$SWIFT_TOOLCHAIN  toolchain for swiftly (default 6.4.1)
  \$SWIFT_WASM_SDK   Swift SDK name (default swift-<toolchain>-RELEASE_wasm)
  \$OBJCOPY          llvm-objcopy to strip the module (default: next to swift, then in PATH)
Install them with:
  swiftly install $TOOLCHAIN
  swiftly run swift sdk install <Wasm SDK URL from swift.org> --checksum <checksum> +$TOOLCHAIN
USAGE
}

case ${1:-} in
    -h|--help) usage; exit 0 ;;
    '') ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
esac

if command -v swiftly >/dev/null; then
    swift() {
        swiftly run swift "$@" "+$TOOLCHAIN"
    }
    SWIFT_BIN=$(dirname "$(swiftly run which swift "+$TOOLCHAIN")")
else
    command -v swift >/dev/null || { echo "Neither swiftly nor swift found; see Scripts/build-web.sh --help" >&2; exit 1; }
    SWIFT_BIN=$(dirname "$(command -v swift)")
fi

swift sdk list | grep -qx "$SDK" || { echo "Swift SDK $SDK is not installed; see Scripts/build-web.sh --help" >&2; exit 1; }

cd "$SELF"
swift build -c release --product dogma-cli --swift-sdk "$SDK" --build-path "$BUILD"

# llvm-objcopy ships with the toolchain on macOS; elsewhere it may come from the system's LLVM.
if [ -z "${OBJCOPY:-}" ]; then
    if [ -x "$SWIFT_BIN/llvm-objcopy" ]; then
        OBJCOPY=$SWIFT_BIN/llvm-objcopy
    else
        OBJCOPY=$(command -v llvm-objcopy) || { echo "llvm-objcopy not found; set \$OBJCOPY" >&2; exit 1; }
    fi
fi
# The data files live in DogmaKit's resource targets, which WebAssembly builds leave out.
DOGMAKIT=$(swift package --build-path "$BUILD" show-dependencies --format json | python3 -c '
import json, sys
def find(node):
    for dependency in node.get("dependencies", []):
        if dependency["identity"] == "dogmakit":
            return dependency["path"]
        found = find(dependency)
        if found:
            return found
print(find(json.load(sys.stdin)) or "")
')
[ -n "$DOGMAKIT" ] || { echo "DogmaKit is not among the dependencies" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"
"$OBJCOPY" --strip-all "$BUILD/release/dogma-cli.wasm" "$OUT/dogma-cli.wasm"
cp "$DOGMAKIT/Sources/DogmaKitResources/Resources/sde.bin" "$OUT/"
cp "$DOGMAKIT/Sources/DogmaTextResources/Resources/text-en.bin" "$OUT/"
for file in "$OUT"/*; do
    gzip -9 -k "$file"
done

for file in "$OUT/dogma-cli.wasm" "$OUT/sde.bin" "$OUT/text-en.bin"; do
    printf '%-16s %10s bytes, gzip %10s\n' "${file#"$OUT"/}" "$(wc -c <"$file" | tr -d ' ')" \
        "$(wc -c <"$file.gz" | tr -d ' ')"
done
