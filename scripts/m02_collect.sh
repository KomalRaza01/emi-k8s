#!/usr/bin/env bash
cd "$(dirname "$0")/.."
mkdir -p results/m02
echo "##### kubectl get all,pvc,configmap -n emi -o wide" | tee results/m02/kubectl_get_all.txt
kubectl get all,pvc,configmap -n emi -o wide | tee -a results/m02/kubectl_get_all.txt
echo
echo "##### rs.status() (members and states)" | tee results/m02/rs_status.txt
kubectl exec -n emi mongo-0 -- mongosh --quiet --eval 'rs.status().members.forEach(m => print(m.name + "  " + m.stateStr))' | tee -a results/m02/rs_status.txt
echo
echo "##### kubectl logs job/mongo-init -n emi" | tee results/m02/mongo_init_log.txt
kubectl logs job/mongo-init -n emi | tee -a results/m02/mongo_init_log.txt
