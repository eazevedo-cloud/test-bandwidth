#!/bin/bash

# Usage: ./download_timing.sh <url>
URL=$1

if [[ -z "$URL" ]]; then
  echo "Usage: $0 <url>"
  exit 1
fi

echo

# Show banner with machine hostname
echo "===== Download Timing Script on Host: $(hostname) ====="
echo

# Extract hostname for DNS resolving timing
HOSTNAME=$(echo "$URL" | awk -F/ '{print $3}')

# Measure DNS resolution time using dig
dns_time=$(dig +time=1 +tries=1 +stats "$HOSTNAME" | awk '/Query time:/{print $4}')

# Measure connection time and download time using curl's time variables
# -o /dev/null: discard output, -s: silent, -w: format output with timers
curl_times=$(curl -o /dev/null -s -w "%{time_connect} %{time_starttransfer}" "$URL")

# Split times into variables
time_connect=$(echo "$curl_times" | awk '{print $1}')
time_starttransfer=$(echo "$curl_times" | awk '{print $2}')

# time_starttransfer is the time until the first byte is received (connection + server response)
# To get pure download time, we measure total time minus time_starttransfer

# Measure total time with curl
total_time=$(curl -o /dev/null -s -w "%{time_total}" "$URL")

# Calculate download time
download_time=$(echo "$total_time $time_starttransfer" | awk '{print $1 - $2}')

echo "Download timing details for $URL:"
echo "DNS resolving time: ${dns_time} ms"
echo "Connection time: ${time_connect} seconds"
echo "Time to first byte (server response): ${time_starttransfer} seconds"
echo "Download time after first byte: ${download_time} seconds"
echo "Total time: ${total_time} seconds"
