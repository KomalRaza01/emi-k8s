#!/usr/bin/env bash
cd "$(dirname "$0")/.."
source scripts/m03_lib.sh
OUT=results/m03
kubectl scale deployment emi-web --replicas=3 -n emi >/dev/null
kubectl rollout status deployment/emi-web -n emi

echo ">>> Updating footer v1.0 -> v1.1 and building image"
sed -i 's/EMI Calculator v1.0/EMI Calculator v1.1/' app/public/index.html
docker build -t emi-web:1.1 app/
minikube image load emi-web:1.1
echo "Current page version: $(curl -s http://emi.local/ | grep -o 'EMI Calculator v[0-9.]*')"

req_loop > $OUT/rollout_requests.txt &
L=$!
sleep 6

{
echo "################ kubectl set image (1.0 -> 1.1) ################"
kubectl set image deployment/emi-web emi-web=emi-web:1.1 -n emi
kubectl rollout status deployment/emi-web -n emi
echo
echo "################ kubectl rollout history ################"
kubectl rollout history deployment/emi-web -n emi
echo
echo "Page version now: $(curl -s http://emi.local/ | grep -o 'EMI Calculator v[0-9.]*')"
echo "Active image: $(kubectl get deploy emi-web -n emi -o jsonpath='{.spec.template.spec.containers[0].image}')"
} 2>&1 | tee $OUT/rollout_update.txt
sleep 10

{
echo
echo "################ kubectl rollout undo (back to 1.0) ################"
kubectl rollout undo deployment/emi-web -n emi
kubectl rollout status deployment/emi-web -n emi
echo
kubectl rollout history deployment/emi-web -n emi
echo
echo "Page version now: $(curl -s http://emi.local/ | grep -o 'EMI Calculator v[0-9.]*')"
echo "Active image: $(kubectl get deploy emi-web -n emi -o jsonpath='{.spec.template.spec.containers[0].image}')"
} 2>&1 | tee $OUT/rollout_undo.txt
sleep 10
kill $L 2>/dev/null; wait 2>/dev/null

{
echo
echo "################ REQUEST LOOP (during update + rollback) ################"
req_summary $OUT/rollout_requests.txt
} | tee $OUT/rollout_summary.txt

# Restore source file back to v1.0 (cluster is running v1.0)
sed -i 's/EMI Calculator v1.1/EMI Calculator v1.0/' app/public/index.html
