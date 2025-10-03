#!/usr/bin/env bash

# A script to measure the detailed timings of a web request using a single curl command.
# Usage: ./download_timing.sh <url>

URL=$1
HOST=$(hostname)

if [[ -z "$URL" ]]; then
  echo "Usage: $0 <url>"
  exit 1
fi

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed. Please install it to continue."
    exit 1
fi

echo
echo "===== Download Timing Analysis for: $HOST ====="
echo

# Use a multi-line variable for curl's --write-out format for readability.
# We are capturing all necessary timing variables in one go.
# Delimiter is '|' to easily parse the output later.
curl_format=$(cat <<EOF
time_namelookup:%{time_namelookup}|time_connect:%{time_connect}|time_appconnect:%{time_appconnect}|time_pretransfer:%{time_pretransfer}|time_starttransfer:%{time_starttransfer}|time_total:%{time_total}|size_download:%{size_download}|speed_download:%{speed_download}
EOF
)

# Run curl ONCE and capture the formatted output
curl_output=$(curl --location-trusted -o /dev/null -s -w "$curl_format" "$URL")

# --- Process the output ---
# Use an associative array to store the key-value pairs from curl's output.
declare -A timings

# Read the output string into the associative array
IFS='|' read -r -a pairs <<< "$curl_output"
for pair in "${pairs[@]}"; do
    # Split each "key:value" pair
    key="${pair%%:*}"
    value="${pair#*:}"
    timings["$key"]="$value"
done

# --- Calculate the duration of each phase in milliseconds ---
# awk is used for all floating point arithmetic.
dns_ms=$(awk -v T="${timings[time_namelookup]}" 'BEGIN { printf "%.0f", T * 1000 }')
connect_ms=$(awk -v T1="${timings[time_namelookup]}" -v T2="${timings[time_connect]}" 'BEGIN { printf "%.0f", (T2 - T1) * 1000 }')
appconnect_ms=$(awk -v T1="${timings[time_connect]}" -v T2="${timings[time_appconnect]}" 'BEGIN { printf "%.0f", (T2 - T1) * 1000 }')
pretransfer_ms=$(awk -v T1="${timings[time_appconnect]}" -v T2="${timings[time_pretransfer]}" 'BEGIN { printf "%.0f", (T2 - T1) * 1000 }')
starttransfer_ms=$(awk -v T1="${timings[time_pretransfer]}" -v T2="${timings[time_starttransfer]}" 'BEGIN { printf "%.0f", (T2 - T1) * 1000 }')
transfer_ms=$(awk -v T1="${timings[time_starttransfer]}" -v T2="${timings[time_total]}" 'BEGIN { printf "%.0f", (T2 - T1) * 1000 }')
total_ms=$(awk -v T="${timings[time_total]}" 'BEGIN { printf "%.0f", T * 1000 }')

# --- Format download stats ---
size_kb=$(awk -v B="${timings[size_download]}" 'BEGIN { printf "%.2f", B / 1024 }')
speed_kbs=$(awk -v Bps="${timings[speed_download]}" 'BEGIN { printf "%.2f", Bps / 1024 }')


# --- Display the results in a clean, aligned format ---
echo "Timing Breakdown (Phases):"
printf "  %-25s: %s ms\n" "DNS Resolution" "$dns_ms"
printf "  %-25s: %s ms\n" "TCP Connection" "$connect_ms"

# Only show TLS Handshake if it happened (for HTTPS)
if [[ $(awk -v V="${timings[time_appconnect]}" 'BEGIN { print (V > 0) }') -eq 1 ]]; then
    printf "  %-25s: %s ms\n" "TLS Handshake" "$appconnect_ms"
fi

printf "  %-25s: %s ms\n" "Request Sent" "$pretransfer_ms"
printf "  %-25s: %s ms\n" "Server Processing (TTFB)" "$starttransfer_ms"
printf "  %-25s: %s ms\n" "Content Transfer" "$transfer_ms"
printf -- "----------------------------------------\n"
printf "  %-25s: %s ms (%.3f s)\n\n" "Total Time" "$total_ms" "${timings[time_total]}"

echo "Download Stats:"
printf "  %-25s: %s KB\n" "Total Size" "$size_kb"
printf "  %-25s: %s KB/s\n" "Average Speed" "$speed_kbs"
echo
