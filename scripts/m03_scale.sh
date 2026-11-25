#!/usr/bin/env bash
cd "$(dirname "$0")/.."
source scripts/m03_lib.sh
OUT=results/m03

echo ">>> Scaling back to 3 replicas..."
kubectl scale deployment emi-web --replicas=3 -n emi
kubectl rollout status deployment/emi-web -n emi
sleep 5

echo ">>> Test A: 3 replicas, 30 requests"
bash scripts/lb_test.sh 3replicas

echo ">>> Starting watch and request loop, then scaling to 5 replicas"
pod_watch > $OUT/scale_pods_watch.txt 2>&1 &
W=$!
req_loop > $OUT/scale_requests.txt &
L=$!
sleep 6
kubectl scale deployment emi-web --replicas=5 -n emi
kubectl rollout status deployment/emi-web -n emi
sleep 12
stop_bg $L $W
wait 2>/dev/null

echo
echo ">>> Test B: 5 replicas, 30 requests"
bash scripts/lb_test.sh 5replicas

{
echo
echo "### Pod readiness vs. first request served"
echo "(for pre-existing pods, Ready at reflects the start of the watch)"
echo "POD | READY AT | FIRST REQUEST SERVED AT"
for p in $(awk '$3!="none"{print $3}' $OUT/scale_requests.txt | sort -u); do
  ready=$(awk -v p="$p" '$2==p && $3=="1/1"{print $1; exit}' $OUT/scale_pods_watch.txt)
  first=$(awk -v p="$p" '$3==p{print $1; exit}' $OUT/scale_requests.txt)
  echo "$p | ${ready:-n/a} | $first"
done
echo
req_summary $OUT/scale_requests.txt
} | tee $OUT/scale_summary.txt

echo
kubectl get pods -n emi -l app=emi-web -o wide
