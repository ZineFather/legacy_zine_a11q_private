#!/usr/bin/env bash
# Import exact Samsung firmware archives supplied through protected GitHub Actions secrets.
# Never print the download URLs: SamFW links may be temporary bearer links.
set -euo pipefail

: "${SRC_DIR:?Source the repository buildenv.sh before running this script}"
: "${OUT_DIR:?OUT_DIR is not set}"
: "${ODIN_DIR:?ODIN_DIR is not set}"
: "${SOURCE_FIRMWARE_URL:?Missing SOURCE_FIRMWARE_URL secret}"
: "${TARGET_FIRMWARE_URL:?Missing TARGET_FIRMWARE_URL secret}"

verify_archive_members() {
    local zip_path="$1"
    local model="$2"
    local version="$3"
    local csc_version="$4"

    python3 - "$zip_path" "$model" "$version" "$csc_version" <<'PY'
import pathlib, sys, zipfile
zip_path, model, version, csc_version = sys.argv[1:]
try:
    with zipfile.ZipFile(zip_path) as zf:
        members = [x for x in zf.infolist() if not x.is_dir()]
        names = [x.filename for x in members]
        if not names:
            raise ValueError("empty firmware archive")
        for name in names:
            p = pathlib.PurePosixPath(name)
            if p.is_absolute() or len(p.parts) != 1 or ".." in p.parts or "\\" in name:
                raise ValueError("unsafe archive member path")
        tar_names = [n for n in names if n.endswith(".tar.md5")]
        for prefix in ("AP_", "BL_", "CP_"):
            if not any(n.startswith(prefix + version) for n in tar_names):
                raise ValueError(f"missing expected {prefix} payload for {model} {version}")
        for prefix in ("CSC_OXM_", "HOME_CSC_OXM_"):
            if not any(n.startswith(prefix + csc_version) for n in tar_names):
                raise ValueError(f"missing expected {prefix} payload for {model} {csc_version}")
        if any(not (n.endswith(".tar.md5") or n.startswith("_FirmwareInfo_")) for n in names):
            raise ValueError("unexpected file in firmware archive")
        print(f"Validated ZIP directory for {model} {version}: {len(tar_names)} Odin payloads")
        for item in members:
            if item.filename.endswith(".tar.md5"):
                print(f"  {item.filename} ({item.file_size} bytes)")
except Exception as exc:
    print(f"Firmware archive validation failed: {exc}", file=sys.stderr)
    sys.exit(1)
PY
}

verify_odin_md5() {
    local dir="$1"
    local fw_file file_name tail_len stored_hash calculated_hash
    local found=0

    while IFS= read -r -d '' fw_file; do
        found=1
        file_name="$(basename "$fw_file")"
        file_name="${file_name%.md5}"
        tail_len="$((32 + 2 + ${#file_name} + 1))"
        stored_hash="$(tail -c "$tail_len" "$fw_file" | cut -d ' ' -f 1 -s)"
        if [[ ! "$stored_hash" =~ ^[[:xdigit:]]{32}$ ]]; then
            echo "Invalid embedded MD5 trailer: $file_name" >&2
            return 1
        fi
        calculated_hash="$(head -c-"$tail_len" "$fw_file" | md5sum | cut -d ' ' -f 1)"
        if [[ "${stored_hash,,}" != "${calculated_hash,,}" ]]; then
            echo "Embedded MD5 mismatch: $file_name" >&2
            return 1
        fi
        echo "Verified embedded MD5: $file_name"
    done < <(find "$dir" -maxdepth 1 -type f -name '*.tar.md5' -print0)

    if [[ "$found" -ne 1 ]]; then
        echo "No Odin tar.md5 payloads found in $dir" >&2
        return 1
    fi
}

import_one() {
    local label="$1" model="$2" csc="$3" version="$4" csc_version="$5" cp_version="$6" url="$7"
    local target_dir="$ODIN_DIR/${model}_${csc}"
    local zip_path="$OUT_DIR/tmp/${model}_${csc}_samfw.zip"

    mkdir -p "$OUT_DIR/tmp"
    rm -rf "$target_dir"
    mkdir -p "$target_dir"
    rm -f "$zip_path"
    echo "Downloading pinned $label firmware: $model/$csc $version"
    curl --fail --location --silent --show-error --progress-bar \
        --retry 4 --retry-all-errors --retry-delay 5 --connect-timeout 30 --continue-at - \
        --output "$zip_path" "$url"

    verify_archive_members "$zip_path" "$model" "$version" "$csc_version"
    unzip -q -o "$zip_path" -d "$target_dir"
    rm -f "$zip_path"
    verify_odin_md5 "$target_dir"
    printf '%s/%s/%s' "$version" "$csc_version" "$cp_version" > "$target_dir/.downloaded"
    echo "Imported and verified $label firmware: $model/$csc $version"
}

import_one "source" "SM-S911B" "BTB" "S911BXXS8DYI3" "S911BOXM8DYI3" "CP31479988" "$SOURCE_FIRMWARE_URL"
import_one "target" "SM-A528B" "BTU" "A528BXXSBGYI3" "A528BOXMBGYI3" "CP31566566" "$TARGET_FIRMWARE_URL"
