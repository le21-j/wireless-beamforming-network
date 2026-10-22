#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Resolve external lwIP sources and the requested compiler/output
# -----------------------------------------------------------------------------
project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
LWIP_SRC=${LWIP_SRC:-"$project_dir/../../../build/deps/lwip-STABLE-2_1_3_RELEASE/src"}
CC=${CC:-arm-linux-gnueabihf-gcc}
output=${1:-"$project_dir/build/lwip_ethernet"}
if [[ ! -f "$LWIP_SRC/include/lwip/init.h" ]]; then
    printf 'LWIP_SRC must point to the lwIP src directory: %s\n' "$LWIP_SRC" >&2
    exit 1
fi
LWIP_SRC=$(cd -- "$LWIP_SRC" && pwd)
mkdir -p -- "$(dirname -- "$output")"

# lwIP requires these include names. Generate them beside this build's output.
config_dir="$output.config"
mkdir -p -- "$config_dir/arch"
config_dir=$(cd -- "$config_dir" && pwd)
cp -- "$project_dir/sw_lwipopts.h" "$config_dir/lwipopts.h"
cp -- "$project_dir/arch/sw_cc.h" "$config_dir/arch/cc.h"

# -----------------------------------------------------------------------------
# Compile the adapter and upstream stack into one static executable
# -----------------------------------------------------------------------------
sources=("$project_dir/sw_main.c" "$LWIP_SRC"/core/*.c "$LWIP_SRC"/core/ipv4/*.c
         "$LWIP_SRC/netif/ethernet.c")
source_tag=$(sha256sum "$project_dir/sw_main.c" "$project_dir/sw_lwipopts.h" \
    "$project_dir/arch/sw_cc.h" "$LWIP_SRC/include/lwip/init.h" | sha256sum | cut -c1-16)
flags=(-std=c11 -D_POSIX_C_SOURCE=200809L -O2 -g -Wall -Wextra
       -I"$config_dir" -I"$LWIP_SRC/include" -DCAPSTONE_BUILD_TAG=\""$source_tag"\")
# A static binary avoids relying on a newer host glibc than Pluto's firmware.
"$CC" "${flags[@]}" "${sources[@]}" -static -o "$output"

# -----------------------------------------------------------------------------
# Record this build and retain upstream license notices
# -----------------------------------------------------------------------------
# Each manifest describes this executable, not a previous hardware run.
{
    printf 'source_root=%s\nconfig_dir=%s\ncompiler=%s\n' "$LWIP_SRC" "$config_dir" "$CC"
    printf 'source_tag=%s\n' "$source_tag"
    "$CC" --version
    printf '\nversion_definitions\n'
    grep '^#define LWIP_VERSION_' "$LWIP_SRC/include/lwip/init.h"
    printf '\ncommand\n'
    printf '%q ' "$CC" "${flags[@]}" "${sources[@]}" -static -o "$output"
    printf '\n\ninput_hashes\n'
    sha256sum "$project_dir/sw_main.c" "$project_dir/sw_lwipopts.h" \
        "$project_dir/arch/sw_cc.h" "$project_dir/sw_build.sh"
    find "$LWIP_SRC" -type f -name '*.h' -print0 | sort -z | xargs -0 sha256sum
    sha256sum "${sources[@]:1}"
    printf '\ngenerated_configuration_hashes\n'
    sha256sum "$config_dir/lwipopts.h" "$config_dir/arch/cc.h"
    printf '\noutput_hash\n'
    sha256sum "$output"
} > "$output.manifest.txt"
# Ship the unchanged license and source notices with a copied binary.
{
    cat "$LWIP_SRC/../COPYING"
    for source in "${sources[@]:1}"; do
        printf '\nSource: %s\n' "$source"
        # Preserve each leading comment, including copyright and license text.
        sed '/^#include/q' "$source"
    done
} > "$output.lwip-notice.txt"
printf 'Built %s\nManifest %s.manifest.txt\n' "$output" "$output"
