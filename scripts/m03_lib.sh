#!/usr/bin/env bash
URL=${URL:-http://emi.local/api/emi}

# Send one request every 0.2s: "HH:MM:SS HTTPCODE POD"
req_loop() {
  while true; do
    R=$(curl -s -m 8 -w ' HTTP%{http_code}' -X POST "$URL" -H 'Content-Type: application/json' -d '{"P":500000,"rate":12,"n":24}')
    CODE=${R##* HTTP}
    P=$(echo "$R" | grep -o '"servedBy":"[^"]*"' | cut -d'"' -f4)
    echo "$(date +%T) ${CODE} ${P:-none}"
    sleep 0.2
  done
}

# Timestamped output of kubectl get pods -w
pod_watch() {
  kubectl get pods -n emi -w --no-headers | while read -r l; do echo "$(date +%T) $l"; done
}

stop_bg() {
  pkill -f "kubectl get pods -n emi -w" 2>/dev/null
  kill "$@" 2>/dev/null
}

req_summary() {
  local tot bad
  tot=$(wc -l < "$1"); bad=$(awk '$2!=200' "$1" | wc -l)
  echo "Total requests: $tot    Failed (non-200): $bad"
  if [ "$bad" -gt 0 ]; then echo "--- failed requests:"; awk '$2!=200' "$1"; fi
  return 0
}
