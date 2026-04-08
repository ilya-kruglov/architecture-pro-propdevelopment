#!/bin/bash
# Скрипт для создания RBAC ролей в Kubernetes для PropDevelopment

set -e

echo "📌 Создаю ClusterRole: cluster-viewer (только чтение, без секретов)"
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-viewer
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "persistentvolumeclaims", "nodes", "namespaces", "events"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets", "daemonsets", "replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch"]
EOF

echo "📌 Создаю ClusterRole: security-auditor (чтение секретов и audit-логов)"
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: security-auditor
rules:
- apiGroups: [""]
  resources: ["secrets", "pods/log"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "namespaces"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["policy"]
  resources: ["podsecuritypolicies", "poddisruptionbudgets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["audit.k8s.io"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
EOF

echo "📌 Создаю Role: namespace-editor (внутри конкретных namespace, без секретов)"

# Создаём namespace dev-services
kubectl create namespace dev-services --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: namespace-editor
  namespace: dev-services
rules:
- apiGroups: ["", "apps", "networking.k8s.io", "batch"]
  resources: ["pods", "services", "deployments", "configmaps", "ingresses", "jobs", "cronjobs"]
  verbs: ["create", "update", "patch", "delete", "get", "list", "watch"]
# secrets не включены в правила → доступ запрещён по умолчанию
EOF

# Создаём namespace prod-services
kubectl create namespace prod-services --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: namespace-editor
  namespace: prod-services
rules:
- apiGroups: ["", "apps", "networking.k8s.io", "batch"]
  resources: ["pods", "services", "deployments", "configmaps", "ingresses", "jobs", "cronjobs"]
  verbs: ["create", "update", "patch", "delete", "get", "list", "watch"]
# secrets не включены в правила → доступ запрещён по умолчанию
EOF

echo "📌 ClusterRole 'cluster-admin' уже существует в Kubernetes (пропускаю)"

echo ""
echo "✅ Роли созданы:"
kubectl get clusterroles | grep -E "cluster-viewer|security-auditor|cluster-admin"
kubectl get roles -n dev-services
kubectl get roles -n prod-services