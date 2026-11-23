#!/usr/bin/env bash
cd "$(dirname "$0")/.."
mkdir -p results/m02
{
URI_ALL="mongodb://mongo-0.mongo:27017,mongo-1.mongo:27017,mongo-2.mongo:27017/emidb?replicaSet=rs0"
URI_M1="mongodb://mongo-1.mongo:27017/emidb?directConnection=true&readPreference=secondaryPreferred"
count_all() { kubectl exec -n emi mongo-0 -- mongosh "$URI_ALL" --quiet --eval 'db.calculations.countDocuments()'; }
count_m1()  { kubectl exec -n emi mongo-0 -- mongosh "$URI_M1" --quiet --eval 'db.calculations.countDocuments()'; }

echo "################ BEFORE deleting mongo-1 ################"
echo "--- pod mongo-1:"; kubectl get pod mongo-1 -n emi -o wide
echo "--- pod UID : $(kubectl get pod mongo-1 -n emi -o jsonpath='{.metadata.uid}')"
echo "--- PVCs:";        kubectl get pvc -n emi
echo "--- PVC data-mongo-1 UID : $(kubectl get pvc data-mongo-1 -n emi -o jsonpath='{.metadata.uid}')"
echo "--- documents in calculations (replica set): $(count_all)"
echo "--- documents seen on mongo-1: $(count_m1)"

echo
echo "################ DELETING mongo-1 ################"
kubectl delete pod mongo-1 -n emi
sleep 5
kubectl wait --for=condition=Ready pod/mongo-1 -n emi --timeout=240s
sleep 10

echo
echo "################ AFTER (pod re-created by StatefulSet) ################"
echo "--- pod mongo-1:"; kubectl get pod mongo-1 -n emi -o wide
echo "--- pod UID : $(kubectl get pod mongo-1 -n emi -o jsonpath='{.metadata.uid}')   (different = new pod)"
echo "--- PVCs:";        kubectl get pvc -n emi
echo "--- PVC data-mongo-1 UID : $(kubectl get pvc data-mongo-1 -n emi -o jsonpath='{.metadata.uid}')   (same = same disk)"
echo "--- documents in calculations (replica set): $(count_all)"
echo "--- documents seen on mongo-1: $(count_m1)"
echo "--- replica set members:"
kubectl exec -n emi mongo-0 -- mongosh --quiet --eval 'rs.status().members.forEach(m => print(m.name + "  " + m.stateStr))'
} 2>&1 | tee results/m02/persistence.txt
