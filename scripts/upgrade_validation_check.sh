#!/bin/bash

# Upgrade validation helper (Linux/bash version)
# Usage: bash ./scripts/upgrade_validation_check.sh
# 
# Behavior:
# - Runs the main upgrade checks
# - Prints PASS / FAIL / SKIPPED for each item
# - Exits with 0 if all items PASS or SKIPPED; non-zero if any FAIL
#
# Notes:
# - This script is intentionally conservative
# - Run manually and attach logs to upgrade PR

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$REPO_ROOT"

# Color codes
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

results=()
fail_count=0

# Function to report test result
report() {
    local name="$1"
    local status="$2"
    local note="${3:-}"
    
    results+=("$name|$status|$note")
    
    local color
    case "$status" in
        PASS) color="$GREEN" ;;
        FAIL) color="$RED"; ((fail_count++)) ;;
        SKIPPED) color="$YELLOW" ;;
    esac
    
    printf "${color}%-50s %s${NC}\n" "$name" "$status"
    if [[ -n "$note" ]]; then
        echo "  Note: $note"
    fi
}

# Function to find package manager
get_runner_cmd() {
    if command -v pnpm &> /dev/null; then
        echo "pnpm"
    elif command -v npm &> /dev/null; then
        echo "npm"
    else
        echo "none"
    fi
}

# ============================================================================
# STEP 0 — CONFIRMATION (DO NOT SKIP)
# ============================================================================

echo "STEP 0 — CONFIRMATION: reporting current branch and git status"
echo ""

# Current branch
if branch=$(git rev-parse --abbrev-ref HEAD 2>&1); then
    echo "Current branch: $branch"
    report "current branch" "PASS"
else
    report "current branch" "FAIL" "git not available or not a repo: $branch"
    exit 2
fi

# Git status
gst=$(git status --porcelain 2>&1 || echo "")
if [[ -z "$gst" ]]; then
    report "git status is clean" "PASS"
else
    # Check if there are untracked files only (OK) vs modified tracked files (NOT OK)
    modified=$(git status --porcelain 2>&1 | grep -E '^ [AM]|^[AMR] ' || true)
    if [[ -n "$modified" ]]; then
        report "git status is clean" "FAIL" "Modified tracked files found. Commit or stash and re-run."
        exit 2
    else
        report "git status is clean" "PASS" "Only untracked files present (OK)"
    fi
fi

# Check for running dev servers (mcp_server pid files)
pid_candidates=("runtime/current/mcp_server.pid" "runtime/mcp_server.pid")
dev_server_running=false

for pfile in "${pid_candidates[@]}"; do
    if [[ -f "$pfile" ]]; then
        pid=$(cat "$pfile" 2>/dev/null)
        if [[ "$pid" =~ ^[0-9]+$ ]]; then
            if kill -0 "$pid" 2>/dev/null; then
                proc_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
                report "No dev server running" "FAIL" "PID $pid from $pfile is running (process: $proc_name). Please stop it and re-run."
                exit 2
            fi
        else
            report "No dev server running" "FAIL" "Found pid file $pfile but content is not a valid pid"
            exit 2
        fi
    fi
done

report "No dev server running" "PASS"

# Branch validation
branch_pattern='^upgrade/docling-[0-9]{4}-[0-9]{2}-[0-9]{2}$'
if [[ ! "$branch" =~ $branch_pattern ]]; then
    report "Current branch" "FAIL" "Current branch must be upgrade/docling-YYYY-MM-DD format"
    exit 2
else
    report "Current branch format" "PASS"
fi

echo ""

# ============================================================================
# STEP 1+ — MAIN CHECKS
# ============================================================================

# Load runner command
runner=$(get_runner_cmd)

if [[ ! -f "package.json" ]]; then
    report "package.json exists" "FAIL" "No package.json found"
    exit 2
else
    report "package.json exists" "PASS"
fi

# Lint
if command -v "$runner" &> /dev/null; then
    echo "Running lint: $runner lint"
    lint_out=$("$runner" lint 2>&1 || true)
    lint_exit=$?
    
    if [[ $lint_exit -eq 0 ]]; then
        if echo "$lint_out" | grep -iq "warning"; then
            report "Lint passes with no new errors" "PASS" "Warnings detected; please review"
        else
            report "Lint passes with no new errors" "PASS"
        fi
    else
        report "Lint passes with no new errors" "FAIL" "Exit code $lint_exit"
    fi
else
    report "Lint passes with no new errors" "SKIPPED" "No package runner (pnpm/npm) found"
fi

# Build/dev starts successfully
dev_out_file="$REPO_ROOT/upgrade_dev_out.txt"
dev_err_file="$REPO_ROOT/upgrade_dev_err.txt"

if [[ -n "$runner" && "$runner" != "none" ]]; then
    echo "Starting dev: $runner dev (short check, will stop after 8s)"
    
    if $runner dev > "$dev_out_file" 2> "$dev_err_file" &
    then
        dev_pid=$!
        sleep 8
        
        if ! kill -0 "$dev_pid" 2>/dev/null; then
            # Process exited early
            err_msg=$(head -20 "$dev_err_file" 2>/dev/null || echo "")
            report "Build/dev starts successfully" "FAIL" "Process exited. Check $dev_err_file. Error: $err_msg"
        else
            report "Build/dev starts successfully" "PASS"
            # Kill the process
            kill "$dev_pid" 2>/dev/null || true
            wait "$dev_pid" 2>/dev/null || true
        fi
    else
        report "Build/dev starts successfully" "FAIL" "Could not start dev process"
    fi
else
    report "Build/dev starts successfully" "SKIPPED" "No package runner available"
fi

# No new warnings introduced
warnings_found=false
if [[ -f "$dev_out_file" ]] && grep -iq "warning" "$dev_out_file"; then
    warnings_found=true
fi
if [[ -n "$lint_out" ]] && echo "$lint_out" | grep -iq "warning"; then
    warnings_found=true
fi

if [[ "$warnings_found" == true ]]; then
    report "No new warnings introduced" "FAIL" "Warnings found in output; search in $dev_out_file"
else
    report "No new warnings introduced" "PASS"
fi

# Application behavior unchanged (unit tests)
if [[ -n "$runner" && "$runner" != "none" ]]; then
    # Check if test:unit exists in package.json
    if grep -q '"test:unit"' package.json 2>/dev/null; then
        echo "Running unit tests (smoke check)..."
        if $runner test:unit 2>&1 > /dev/null; then
            report "Application behavior unchanged" "PASS"
        else
            report "Application behavior unchanged" "FAIL" "Unit tests returned non-zero exit"
        fi
    else
        report "Application behavior unchanged" "SKIPPED" "No test:unit script in package.json"
    fi
else
    report "Application behavior unchanged" "SKIPPED" "No package runner available"
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "========================================================================="
echo "Upgrade Validation Summary"
echo "========================================================================="
echo ""

printf "%-50s %s\n" "Check" "Status"
echo "------------------------------------------------------------------------"
for result in "${results[@]}"; do
    IFS='|' read -r name status note <<< "$result"
    printf "%-50s %s\n" "$name" "$status"
    if [[ -n "$note" ]]; then
        echo "  Note: $note"
    fi
done

echo ""

if [[ $fail_count -gt 0 ]]; then
    echo -e "${RED}✗ One or more checks FAILED. Fix issues and re-run.${NC}"
    exit 2
else
    echo -e "${GREEN}✓ All checks PASS or SKIPPED. Good to proceed.${NC}"
    exit 0
fi
