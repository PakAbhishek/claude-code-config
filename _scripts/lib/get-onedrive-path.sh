#!/bin/bash
# ============================================
# get-onedrive-path.sh
# Utility function to auto-detect OneDrive path
# Works on both personal (OneDrive) and work (OneDrive - PakEnergy) machines
# ============================================

# Get the OneDrive path for this machine
# Checks in order:
# 1. "OneDrive - PakEnergy" (work machine - more specific)
# 2. "OneDrive" (personal machine)
# Returns the path via stdout, or returns 1 if not found
get_onedrive_path() {
    local candidates=(
        "OneDrive - PakEnergy"  # Work machine (more specific, check first)
        "OneDrive"              # Personal machine
    )

    for candidate in "${candidates[@]}"; do
        local full_path="$HOME/$candidate"
        if [ -d "$full_path" ]; then
            echo "$full_path"
            return 0
        fi
    done

    # Not found
    return 1
}

# If sourced, just define the function
# If executed directly, run the function and print result
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    result=$(get_onedrive_path)
    if [ $? -eq 0 ]; then
        echo "$result"
    else
        echo "ERROR: OneDrive folder not found" >&2
        echo "Checked: OneDrive - PakEnergy, OneDrive" >&2
        exit 1
    fi
fi
