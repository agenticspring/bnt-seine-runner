#!/usr/bin/env bash
set -Eeuo pipefail

# Download, verify, extract, configure HugePages, and run Seine.
# Requires Linux x86_64 and root privileges.

BASE_URL="https://github.com/zpalmtree/seine/releases/latest/download"
ASSET="seine-linux-x86_64.tar.gz"
POOL_URL="stratum+tcp://bntpool.com:3333"
ADDRESS="PLMGsifmTC9Zn5pHqcMkbayvzSG3SBX6vAwJts3KQCwfGRsznpv2qdyCFyRpnh46TwcQu8mLEu1CVdHdQzsx7Ty637GQc"

PAGES=1024
SYSCTL_CONF="/etc/sysctl.d/99-seine-hugepages.conf"

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

if [[ $EUID -ne 0 ]]; then
    command -v sudo >/dev/null || die "Run as root."
    exec sudo -E bash "$(readlink -f "$0")" "$@"
fi

[[ "$(uname -s)" == Linux ]] || die "Linux is required."
[[ "$(uname -m)" == x86_64 ]] || die "Linux x86_64 is required."

for cmd in tar sha256sum awk grep find install sysctl mktemp; do
    command -v "$cmd" >/dev/null || die "Missing command: $cmd"
done

if ! command -v curl >/dev/null && ! command -v wget >/dev/null; then
    die "Install curl or wget first."
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

download() {
    local url="$1" output="$2"

    if command -v curl >/dev/null; then
        log "Downloading: $url"
        if curl -fLsS --retry 4 --retry-delay 2 \
            --connect-timeout 20 --max-time 600 \
            -o "$output" "$url" && [[ -s "$output" ]]; then
            return 0
        fi
        log "curl failed; trying wget."
    fi

    if command -v wget >/dev/null; then
        rm -f "$output"
        if wget --tries=4 --timeout=30 \
            -O "$output" "$url" && [[ -s "$output" ]]; then
            return 0
        fi
    fi

    return 1
}

# Download archive and official checksum manifest.
download "$BASE_URL/$ASSET" "$WORK/$ASSET" ||
    die "Archive download failed. Check VPS access to github.com."

download "$BASE_URL/SHA256SUMS.txt" "$WORK/SHA256SUMS.txt" ||
    die "Checksum manifest download failed."

# Verify archive before extracting or executing it.
SUM_LINE="$(grep -F "$ASSET" "$WORK/SHA256SUMS.txt" | head -n 1 || true)"
[[ -n "$SUM_LINE" ]] || die "Archive checksum not found in manifest."

EXPECTED="$(printf '%s\n' "$SUM_LINE" | awk '{print $1}')"
ACTUAL="$(sha256sum "$WORK/$ASSET" | awk '{print $1}')"

[[ "$EXPECTED" =~ ^[[:xdigit:]]{64}$ ]] ||
    die "Invalid checksum in manifest."

[[ "${ACTUAL,,}" == "${EXPECTED,,}" ]] ||
    die "SHA-256 mismatch. Archive will not be extracted."

log "SHA-256 verification passed."

# Extract into temporary directory.
mkdir -p "$WORK/extracted"
tar -xzf "$WORK/$ASSET" -C "$WORK/extracted" ||
    die "Extraction failed."

FOUND="$(find "$WORK/extracted" -type f -name seine -print -quit)"
[[ -n "$FOUND" ]] || die "No seine executable found in archive."

# Preserve existing binary before replacing it.
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

if [[ -f ./seine ]]; then
    BACKUP="./seine.backup.$(date '+%Y%m%d-%H%M%S')"
    cp -p ./seine "$BACKUP" || die "Could not back up existing binary."
    log "Existing binary backed up to $BACKUP"
fi

install -m 0755 "$FOUND" ./seine.new
mv -f ./seine.new ./seine
log "Seine installed successfully."

# Persist HugeTLB reservation across reboots.
PAGE_SIZE="$(awk '/^Hugepagesize:/ {print $2}' /proc/meminfo)"
[[ "$PAGE_SIZE" == 2048 ]] ||
    die "Expected 2 MiB huge pages; got ${PAGE_SIZE:-unknown} kB."

cat > "$SYSCTL_CONF" <<EOF
# Seine single-worker HugeTLB reservation
vm.nr_hugepages = $PAGES
EOF
chmod 0644 "$SYSCTL_CONF"
log "Saved HugePages setting to $SYSCTL_CONF"

# Allocate the required pages, compacting memory and retrying if necessary.
free_pages() {
    awk '/^HugePages_Free:/ {print $2}' /proc/meminfo
}

for attempt in 1 2 3; do
    FREE="$(free_pages)"
    (( FREE >= PAGES )) && break

    log "HugePages attempt $attempt/3: free=$FREE; requesting $PAGES."

    echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
    sysctl -w "vm.nr_hugepages=$PAGES" || true
    sleep 2
done

FREE="$(free_pages)"
TOTAL="$(awk '/^HugePages_Total:/ {print $2}' /proc/meminfo)"
AVAILABLE="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"

log "HugePages total=$TOTAL free=$FREE; MemAvailable=${AVAILABLE}kB"

(( FREE >= PAGES )) ||
    die "Insufficient free HugePages. Reboot or investigate VPS memory limits."

# Launch one CPU worker using strict HugePages mode.
log "Starting Seine with one CPU worker."
log "Pool: $POOL_URL"
log "Address: $ADDRESS"
log "Press Ctrl+C to stop."

exec ./seine \
    --pool-url "$POOL_URL" \
    --address "$ADDRESS" \
    --threads 1 \
    --cpu-page-mode large
