#!/bin/bash
# Скрипт для привязки пользователей (групп) к ролям в PropDevelopment

set -e

echo "🔗 Привязываю группу auditors к cluster-viewer"
kubectl create clusterrolebinding auditors-view-binding \
  --clusterrole=cluster-viewer \
  --group=auditors \
  --dry-run=client -o yaml | kubectl apply -f -

echo "🔗 Привязываю группу security-team к security-auditor"
kubectl create clusterrolebinding security-auditor-binding \
  --clusterrole=security-auditor \
  --group=security-team \
  --dry-run=client -o yaml | kubectl apply -f -

echo "🔗 Привязываю группу dev-team к namespace-editor в namespace dev-services"
kubectl create rolebinding dev-editor-binding-dev \
  --role=namespace-editor \
  --group=dev-team \
  --namespace=dev-services \
  --dry-run=client -o yaml | kubectl apply -f -

echo "🔗 Привязываю группу dev-team к namespace-editor в namespace prod-services"
kubectl create rolebinding dev-editor-binding-prod \
  --role=namespace-editor \
  --group=dev-team \
  --namespace=prod-services \
  --dry-run=client -o yaml | kubectl apply -f -

echo "🔗 Привязываю группу sre-team к cluster-admin"
kubectl create clusterrolebinding sre-admin-binding \
  --clusterrole=cluster-admin \
  --group=sre-team \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "✅ Все привязки созданы:"
kubectl get clusterrolebindings | grep -E "auditors-view-binding|security-auditor-binding|sre-admin-binding"
kubectl get rolebindings -n dev-services
kubectl get rolebindings -n prod-services

echo ""
echo "🔍 Проверка доступа для разных пользователей:"
echo ""
echo "1. oleg-auditor (группа auditors) — должен видеть pods, но НЕ secrets:"
kubectl auth can-i get pods --as=oleg-auditor
kubectl auth can-i get secrets --as=oleg-auditor

echo ""
echo "2. irina-security (группа security-team) — должна видеть secrets:"
kubectl auth can-i get secrets --as=irina-security

echo ""
echo "3. pavel-dev (группа dev-team) — должен создавать pods в dev-services, но НЕ secrets:"
kubectl auth can-i create pods --as=pavel-dev --namespace=dev-services
kubectl auth can-i get secrets --as=pavel-dev --namespace=dev-services

echo ""
echo "4. pavel-dev (группа dev-team) — НЕ должен создавать pods в kube-system:"
kubectl auth can-i create pods --as=pavel-dev --namespace=kube-system

echo ""
echo "5. alex-sre (группа sre-team) — должен иметь полный доступ:"
kubectl auth can-i '*' '*' --as=alex-sre