#!/usr/bin/env bash
# Send 30 requests through Ingress and count per pod. Usage: bash scripts/lb_test.sh 3replicas
cd "$(dirname "$0")/.."
LABEL=${1:-run}
URL=${URL:-http://emi.local/api/emi}
mkdir -p results/m03
TMP=$(mktemp); FAIL=0
for i in $(seq 1 30); do
  R=$(curl -s -m 5 -X POST "$URL" -H 'Content-Type: application/json' -d '{"P":500000,"rate":12,"n":24}')
  P=$(echo "$R" | grep -o '"servedBy":"[^"]*"' | cut -d'"' -f4)
  if [ -z "$P" ]; then FAIL=$((FAIL+1)); P="FAILED"; fi
  echo "$P" >> "$TMP"
done
{
  echo "### 30 requests via Ingress ($LABEL)  -  $(date)"
  echo "Requests  Pod"
  sort "$TMP" | uniq -c | sort -rn
  echo "Total: $(wc -l < "$TMP")   Failed: $FAIL"
} | tee results/m03/lb_${LABEL}.txt
rm -f "$TMP"
