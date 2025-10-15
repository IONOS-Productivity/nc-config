#!/bin/bash
# SPDX-FileCopyrightText: 2025 STRATO GmbH
# SPDX-License-Identifier: AGPL-3.0-or-later

# Check for config:system:set usage in shell scripts
# This script ensures shell scripts don't use system-wide configuration commands
# which can cause conflicts and instability.

set -e

readonly SCRIPT_NAME="check-shell-config.sh"
readonly CONFIG_COMMAND="config:system:set"
readonly SUCCESS_EMOJI="✅"
readonly ERROR_EMOJI="❌"
readonly WARNING_EMOJI="🚨"
readonly FIX_EMOJI="📝"
readonly CHECKLIST_EMOJI="📋"

# Global variables
found_violations=0
temp_file=""

# Cleanup function
cleanup() {
    if [[ -n "$temp_file" && -f "$temp_file" ]]; then
        rm -f "$temp_file"
    fi
}

# Set up cleanup trap
trap cleanup EXIT

# Print success message
print_success() {
    echo "$SUCCESS_EMOJI SUCCESS: $1"
}

# Print error message
print_error() {
    echo "$ERROR_EMOJI ERROR: $1"
}

# Print workflow failure message
print_workflow_failure() {
    echo "$ERROR_EMOJI WORKFLOW FAILED: $1"
}

# Check if shell scripts exist in the workspace
check_shell_scripts_exist() {
    if ! find . -name "*.sh" -type f | head -1 > /dev/null; then
        print_success "No shell script files (.sh) found to check"
        return 1
    fi
    return 0
}

# Check if file should be skipped
should_skip_file() {
    local file="$1"
    [[ "$(basename "$file")" == "$SCRIPT_NAME" ]]
}

# Find violations in a file
find_violations_in_file() {
    local file="$1"

    # Get lines with config:system:set but exclude our detection logic
    grep -n "$CONFIG_COMMAND" "$file" 2>/dev/null | \
        grep -v "Check if this is a $CONFIG_COMMAND" | \
        grep -v "log_warning.*$CONFIG_COMMAND" | \
        grep -v "if.*$CONFIG_COMMAND" || true
}

# Report violations for a file
report_violations() {
    local file="$1"
    local violations="$2"

    print_error "Found $CONFIG_COMMAND usage in: $file"
    echo "   Lines containing $CONFIG_COMMAND:"

    echo "$violations" | while IFS=: read -r line_num content; do
        echo "     Line $line_num: $content"
    done

    echo ""
    echo "   $FIX_EMOJI FIX PROPOSAL:"
    echo "   - Use partial configuration approach instead of $CONFIG_COMMAND"
    echo "   - Consider using environment variables or app-specific configuration"
    echo ""

    # Record violation
    echo "1" >> "$temp_file"
}

# Process a single shell script file
process_file() {
    local file="$1"

    if should_skip_file "$file"; then
        return 0
    fi

    echo "Checking file: $file"

    local violations
    violations=$(find_violations_in_file "$file")

    if [[ -n "$violations" ]]; then
        report_violations "$file" "$violations"
    fi
}

# Count total violations
count_violations() {
    if [[ -f "$temp_file" ]]; then
        wc -l < "$temp_file"
    else
        echo "0"
    fi
}

# Print final failure report
print_failure_report() {
    local violation_count="$1"

    print_workflow_failure "Found $violation_count file(s) with $CONFIG_COMMAND usage"
    echo ""
    echo "$WARNING_EMOJI POLICY VIOLATION:"
    echo "   $CONFIG_COMMAND should be avoided in favor of partial configuration"
    echo ""
    echo "$CHECKLIST_EMOJI RECOMMENDED ACTIONS:"
    echo "   1. Review each occurrence and determine if it's truly necessary"
    echo "   2. Replace with config:app:set where possible"
    echo "   3. Use environment variables for dynamic configuration"
    echo ""
}

# Main execution function
main() {
    echo "Scanning for $CONFIG_COMMAND usage in shell scripts..."

    # Create temporary file for tracking violations
    temp_file=$(mktemp)

    # Check if any shell scripts exist
    if ! check_shell_scripts_exist; then
        exit 0
    fi

    # Process all shell script files
    while IFS= read -r -d '' file; do
        process_file "$file"
    done < <(find . -name "*.sh" -type f -print0)

    # Count and report violations
    found_violations=$(count_violations)

    if [[ "$found_violations" -gt 0 ]]; then
        print_failure_report "$found_violations"
        exit 1
    else
        print_success "No $CONFIG_COMMAND usage found in shell scripts"
    fi
}

# Run main function
main "$@"
