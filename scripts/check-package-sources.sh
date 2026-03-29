#!/bin/bash
# check-package-sources.sh — Verify Package.swift source list matches BigPigFarm/ contents.
#
# Exits 0 if Package.swift is in sync, 1 if files are missing or stale.
# Run: bash scripts/check-package-sources.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$REPO_ROOT/Package.swift"
SRC="$REPO_ROOT/BigPigFarm"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# --- Parse Package.swift sources array ---
# Extracts quoted strings from the sources: [...] block.
# Entries without .swift are directory includes; entries with .swift are individual files.

parse_package_sources() {
    local in_sources=false
    while IFS= read -r line; do
        if [[ "$line" =~ sources:\ *\[ ]]; then
            in_sources=true
            continue
        fi
        if $in_sources; then
            if [[ "$line" =~ \] ]]; then
                break
            fi
            local entry
            entry=$(echo "$line" | sed -n 's/.*"\([^"]*\)".*/\1/p')
            if [[ -n "$entry" ]]; then
                echo "$entry"
            fi
        fi
    done < "$PKG"
}

# --- Check if a file is platform-dependent ---

is_platform_dependent() {
    local file="$1"
    local relpath="${file#"$SRC"/}"

    # Root-level app files
    if [[ "$relpath" == "BigPigFarmApp.swift" || "$relpath" == "ContentView.swift" ]]; then
        return 0
    fi

    # Everything in Views/ is SwiftUI
    if [[ "$relpath" == Views/* ]]; then
        return 0
    fi

    # Check imports for platform frameworks
    if head -30 "$file" | grep -qE '^\s*import (UIKit|SwiftUI|SpriteKit|Network)'; then
        return 0
    fi

    # Check for debug-only conditional compilation wrapping the entire file
    local first_code
    first_code=$(sed '/^[[:space:]]*$/d; /^[[:space:]]*\/\//d' "$file" | head -1)
    if [[ "$first_code" == '#if DEBUG'* ]]; then
        return 0
    fi

    return 1
}

# --- Build the expected set: files Package.swift will compile ---

pkg_list="$TMP_DIR/pkg.txt"
dir_includes="$TMP_DIR/dirs.txt"
: > "$pkg_list"
: > "$dir_includes"

while IFS= read -r entry; do
    if [[ "$entry" == *.swift ]]; then
        echo "$entry" >> "$pkg_list"
    else
        echo "$entry" >> "$dir_includes"
        if [[ -d "$SRC/$entry" ]]; then
            find "$SRC/$entry" -name "*.swift" -type f | while IFS= read -r f; do
                echo "${f#"$SRC"/}" >> "$pkg_list"
            done
        fi
    fi
done < <(parse_package_sources)

sort -o "$pkg_list" "$pkg_list"

# --- Build the actual set: platform-agnostic files on disk ---

disk_list="$TMP_DIR/disk.txt"
: > "$disk_list"

find "$SRC" -name "*.swift" -type f | while IFS= read -r f; do
    if ! is_platform_dependent "$f"; then
        echo "${f#"$SRC"/}"
    fi
done | sort > "$disk_list"

# --- Compare ---

missing_file="$TMP_DIR/missing.txt"
stale_file="$TMP_DIR/stale.txt"

# Files on disk but not in Package.swift
comm -23 "$disk_list" "$pkg_list" > "$missing_file"

# Files in Package.swift but not on disk
comm -13 "$disk_list" "$pkg_list" | while IFS= read -r relpath; do
    if [[ ! -f "$SRC/$relpath" ]]; then
        echo "$relpath"
    fi
done > "$stale_file"

# --- Check directory includes for platform-dependent contamination ---

contaminated_file="$TMP_DIR/contaminated.txt"
: > "$contaminated_file"

while IFS= read -r dir; do
    if [[ -d "$SRC/$dir" ]]; then
        find "$SRC/$dir" -name "*.swift" -type f | while IFS= read -r f; do
            if is_platform_dependent "$f"; then
                echo "${f#"$SRC"/} (in directory include \"$dir\")"
            fi
        done >> "$contaminated_file"
    fi
done < "$dir_includes"

sort -o "$contaminated_file" "$contaminated_file"

# --- Report ---

missing_count=$(wc -l < "$missing_file" | tr -d ' ')
stale_count=$(wc -l < "$stale_file" | tr -d ' ')
contaminated_count=$(wc -l < "$contaminated_file" | tr -d ' ')

if [[ "$missing_count" -gt 0 || "$stale_count" -gt 0 || "$contaminated_count" -gt 0 ]]; then
    echo "ERROR: Package.swift source list is out of sync with BigPigFarm/ contents."
    echo ""

    if [[ "$missing_count" -gt 0 ]]; then
        echo "Missing from Package.swift (platform-agnostic files not listed):"
        while IFS= read -r f; do
            echo "  + $f"
        done < "$missing_file"
        echo ""
    fi

    if [[ "$stale_count" -gt 0 ]]; then
        echo "Stale entries in Package.swift (files no longer exist):"
        while IFS= read -r f; do
            echo "  - $f"
        done < "$stale_file"
        echo ""
    fi

    if [[ "$contaminated_count" -gt 0 ]]; then
        echo "Platform-dependent files in directory-included folders:"
        while IFS= read -r f; do
            echo "  ! $f"
        done < "$contaminated_file"
        echo ""
    fi

    echo "Fix: Update the sources array in Package.swift to match."
    exit 1
fi

pkg_count=$(wc -l < "$pkg_list" | tr -d ' ')
disk_count=$(wc -l < "$disk_list" | tr -d ' ')
echo "OK: Package.swift source list is in sync with BigPigFarm/ contents."
echo "  Files tracked by SPM: $pkg_count"
echo "  Platform-agnostic on disk: $disk_count"
