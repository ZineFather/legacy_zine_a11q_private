#!/usr/bin/env bash
# Fetch pinned Samsung firmware directly from Samsung FUS with the official-source
# Samloader client, validate the decrypted ZIP and Odin MD5 trailers, then extract
# one device at a time to keep peak disk usage down on GitHub-hosted runners.
set -euo pipefail

: "${SRC_DIR:?Source the repository buildenv.sh before running this script}"
: "${OUT_DIR:?OUT_DIR is not set}"
: "${ODIN_DIR:?ODIN_DIR is not set}"
command -v samloader >/dev/null || { echo "samloader executable is required" >&2; exit 1; }

SOURCE_MODEL="SM-A736B"
SOURCE_CSC="TUR"
SOURCE_VERSION="A736BXXSCGZH1/A736BOJMCGZH1/A736BXXSCGZH1/A736BXXSCGZH1"
TARGET_MODEL="SM-A528B"
TARGET_CSC="BTU"
TARGET_VERSION="A528BXXSBGYI3/A528BOXMBGYI3/A528BXXSBGYI3/A528BXXSBGYI3"

export SAMFW_PINNED_FIRMWARES="${SOURCE_MODEL}/${SOURCE_CSC}=${SOURCE_VERSION}
${TARGET_MODEL}/${TARGET_CSC}=${TARGET_VERSION}"

verify_archive_members() {
    local zip_path="$1" model="$2" version="$3" csc_version="$4"
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
            if not any(n.startswith(prefix + version.split("/")[0]) for n in tar_names):
                raise ValueError(f"missing expected {prefix} payload for {model} {version}")
        csc_build = csc_version.split("/")[1]
        for prefix in ("CSC_OXM_", "HOME_CSC_OXM_"):
            if not any(n.startswith(prefix + csc_build) for n in tar_names):
                raise ValueError(f"missing expected {prefix} payload for {model} {csc_build}")
        if any(not (n.endswith(".tar.md5") or n.startswith("_FirmwareInfo_")) for n in names):
            raise ValueError("unexpected file in firmware archive")
        print(f"Validated Samsung FUS archive for {model}/{csc_version}: {len(tar_names)} Odin payloads")
        for item in members:
            if item.filename.endswith(".tar.md5"):
                print(f"  {item.filename} ({item.file_size} bytes)")
except Exception as exc:
    print(f"Firmware archive validation failed: {exc}", file=sys.stderr)
    sys.exit(1)
PY
}

verify_odin_md5() {
    local dir="$1" fw_file file_name tail_len stored_hash calculated_hash found=0
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
    [[ "$found" -eq 1 ]] || { echo "No Odin tar.md5 payloads found in $dir" >&2; return 1; }
}

import_one() {
    local label="$1" model="$2" csc="$3" version="$4"
    local target_dir="$ODIN_DIR/${model}_${csc}"
    local zip_path="$OUT_DIR/tmp/${model}_${csc}_samloader.zip"

    mkdir -p "$OUT_DIR/tmp"
    rm -rf "$target_dir"
    mkdir -p "$target_dir"
    rm -f "$zip_path" "$zip_path.part"
    echo "Downloading pinned $label firmware from Samsung FUS: $model/$csc"
    samloader download --model "$model" --region "$csc" --version "$version" \
        --threads 8 --out-file "$zip_path"

    verify_archive_members "$zip_path" "$model" "$version" "$version"
    unzip -q -o "$zip_path" -d "$target_dir"
    rm -f "$zip_path" "$zip_path.part"
    verify_odin_md5 "$target_dir"
    printf '%s' "$version" > "$target_dir/.downloaded"
    echo "Imported and verified $label firmware: $model/$csc"
}

# Extract each package immediately after import. extract_fw removes the Odin package
# on GitHub Actions after extracting the needed images, reducing peak disk usage.
import_one "source" "$SOURCE_MODEL" "$SOURCE_CSC" "$SOURCE_VERSION"
"$SRC_DIR/scripts/extract_fw.sh" --ignore-target

import_one "target" "$TARGET_MODEL" "$TARGET_CSC" "$TARGET_VERSION"
"$SRC_DIR/scripts/extract_fw.sh" --ignore-source
