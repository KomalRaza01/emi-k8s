#!/usr/bin/env bash
cd "$(dirname "$0")/.."
source scripts/m03_lib.sh
OUT=results/m03
URI_ALL="mongodb://mongo-0.mongo:27017,mongo-1.mongo:27017,mongo-2.mongo:27017/emidb?replicaSet=rs0"
count()   { kubectl exec -n emi "$1" -- mongosh "$URI_ALL" --quiet --eval 'db.calculations.countDocuments()'; }
members() { kubectl exec -n emi "$1" -- mongosh --quiet --eval 'rs.status().members.forEach(m => print(m.name + "  " + m.stateStr))'; }

PRIMARY_FQDN=$(kubectl exec -n emi mongo-0 -- mongosh --quiet --eval 'db.hello().primary')
PRIMARY=${PRIMARY_FQDN%%.*}
for c in mongo-0 mongo-1 mongo-2; do [ "$c" != "$PRIMARY" ] && SURVIVOR=$c && break; done

{
echo "################ BEFORE ################"
echo "Current PRIMARY: $PRIMARY_FQDN"
members $SURVIVOR
echo "Documents before: $(count $SURVIVOR)"
} 2>&1 | tee $OUT/heal_mongo.txt

pod_watch > $OUT/heal_mongo_watch.txt 2>&1 &
W=$!
req_loop > $OUT/heal_mongo_requests.txt &
L=$!
sleep 6

{
echo
echo "################ DELETING PRIMARY POD: $PRIMARY ################"
kubectl delete pod "$PRIMARY" -n emi
} 2>&1 | tee -a $OUT/heal_mongo.txt

sleep 5
kubectl wait --for=condition=Ready pod/$PRIMARY -n emi --timeout=240s
sleep 15
stop_bg $L $W
wait 2>/dev/null

{
echo
echo "################ AFTER ################"
echo "New PRIMARY: $(kubectl exec -n emi $SURVIVOR -- mongosh --quiet --eval 'db.hello().primary')"
members $SURVIVOR
echo "Documents after (includes requests written during loop): $(count $SURVIVOR)"
echo
echo "### Request summary during/after election:"
req_summary $OUT/heal_mongo_requests.txt
echo
echo "### Timestamped pod watch (mongo pods):"
grep "mongo-" $OUT/heal_mongo_watch.txt
echo
kubectl get pods -n emi
} 2>&1 | tee -a $OUT/heal_mongo.txt
