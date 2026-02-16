#!/bin/bash
set -eu
set -o pipefail

# --- Configuration ---
BASENAME="${1:-main}"
OUTPUT_DIR="${2:-/mnt/user-data/outputs/}"
TEX_FILE="${BASENAME}.tex"
PDF_FILE="${BASENAME}.pdf"
LOG_FILE="${BASENAME}.log"
HTML_TEMPLATE_FILE="/app/preview-pdf.min.html"

# --- Function Definitions ---
handle_success() {
    mkdir -p "$OUTPUT_DIR"
    cat entrypoint.sh
    # --- 1. Input Validation ---
    if [ ! -r "$PDF_FILE" ]; then
        echo "Error: PDF file '$PDF_FILE' not found or is not readable. Cannot generate preview." >&2
        exit 1
    fi
    
    if [ ! -f "$HTML_TEMPLATE_FILE" ]; then
        echo "Warning: HTML template '$HTML_TEMPLATE_FILE' not found. Skipping preview generation." >&2
        mv "$PDF_FILE" "$OUTPUT_DIR/"
        latexmk -c "$BASENAME" >/dev/null 2>&1
        return
    fi
    
    # --- 2. Safe Data Preparation ---
    DATA_URL_FILE=$(mktemp)
    trap 'rm -f "$DATA_URL_FILE"' EXIT
    
    (printf "data:application/pdf;base64," && base64 -w 0 "$PDF_FILE") > "$DATA_URL_FILE"
    
    if [ ! -s "$DATA_URL_FILE" ]; then
        echo "Error: Failed to create Base64 data file from '$PDF_FILE'." >&2
        exit 1
    fi
    
    # --- 3. Robust Replacement with awk ---
    awk \
        -v placeholder="__PDF_URL_PLACEHOLDER__" \
        '
        FNR==NR {
            replacement = $0
            next
        }
        {
            gsub(placeholder, replacement)
            print
        }
        ' "$DATA_URL_FILE" "$HTML_TEMPLATE_FILE" > "$OUTPUT_DIR/preview.html"
    
    # --- 4. Final Cleanup ---
    mv "$PDF_FILE" "$OUTPUT_DIR/"
    latexmk -c "$BASENAME" >/dev/null 2>&1
}

handle_failure() {
    compilation_output="$1"
    {
        echo "LATEX COMPILATION FAILED. Generating structured error analysis..."
        echo ""
        echo "--- ERROR ANALYSIS ---"
        
        # Extract specific error line
        line_error=$(echo "$compilation_output" | grep -m 1 -E '(^[^:]+):\d+: ' || true)
        if [ -n "$line_error" ]; then
            echo "[Precise Location]"
            echo "$line_error"
            echo ""
        fi
        
        # Extract fatal error block
        if [ -f "$LOG_FILE" ]; then
            fatal_error_block=$(sed -n '/^! /,/^l\. [0-9]/p' "$LOG_FILE" || true)
            if [ -n "$fatal_error_block" ]; then
                echo "[Fatal Error Message]"
                echo "$fatal_error_block"
                echo ""
            fi
        fi
        
        # Show source code context
        if [ -n "$line_error" ]; then
            line_num=$(echo "$line_error" | cut -d':' -f2)
            if [ -n "$line_num" ] && [ "$line_num" -gt 0 ]; then
                echo "[Source Code Context]"
                awk -v line="$line_num" 'NR >= line - 3 && NR <= line + 3 { printf "%-5d %s%s\n", NR, (NR == line ? ">" : " "), $0 }' "$TEX_FILE"
                echo ""
            fi
        fi
        
        # Extract relevant log context
        if [ -f "$LOG_FILE" ]; then
            log_context=$(grep -B 20 -m 1 '^! ' "$LOG_FILE" || true)
            if [ -n "$log_context" ]; then
                echo "[Relevant Log Context (preceding fatal error)]"
                echo "$log_context"
                echo ""
            fi
        fi
        
        echo "--- FULL LOG FILE ---"
        if [ -f "$LOG_FILE" ]; then
            cat "$LOG_FILE"
        else
            echo "Log file ($LOG_FILE) not found."
        fi
        echo ""
    } >&2
    
    exit 1
}

# --- Main Execution ---
main() {
    cat > "$TEX_FILE"
    
    if compilation_output=$(latexmk -r /app/.latexmkrc -interaction=nonstopmode "$BASENAME" 2>&1); then
        handle_success
    else
        handle_failure "$compilation_output"
    fi
}

main "$@"
