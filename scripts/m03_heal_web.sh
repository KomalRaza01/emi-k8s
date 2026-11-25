#!/usr/bin/env bash
cd "$(dirname "$0")/.."
source scripts/m03_lib.sh
OUT=results/m03
kubectl scale deployment emi-web --replicas=3 -n emi >/dev/null
kubectl rollout status deployment/emi-web -n emi
VICTIM=$(kubectl get pods -n emi -l app=emi-web -o jsonpath='{.items[0].metadata.name}')
echo ">>> Deleting web pod: $VICTIM"

pod_watch > $OUT/heal_web_watch.txt 2>&1 &
W=$!
req_loop > $OUT/heal_web_requests.txt &
L=$!
sleep 6
kubectl delete pod "$VICTIM" -n emi
sleep 5
kubectl rollout status deployment/emi-web -n emi
sleep 12
stop_bg $L $W
wait 2>/dev/null

{
echo
echo "### Self-healing test (deleted web pod $VICTIM)"
req_summary $OUT/heal_web_requests.txt
echo
echo "### Timestamped pod watch (emi-web pods):"
grep emi-web $OUT/heal_web_watch.txt
echo
kubectl get pods -n emi -l app=emi-web -o wide
} | tee $OUT/heal_web_summary.txt
