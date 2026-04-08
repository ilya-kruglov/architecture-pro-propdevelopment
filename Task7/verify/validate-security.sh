#!/bin/bash
# Скрипт для проверки работы Gatekeeper

echo "=========================================="
echo "Проверка Gatekeeper политик"
echo "=========================================="

# Проверка установки Gatekeeper
if ! kubectl get ns gatekeeper-system &>/dev/null; then
    echo "❌ Gatekeeper не установлен!"
    exit 1
fi
echo "✅ Gatekeeper установлен"
echo ""

# Создаём тестовый namespace
echo "📁 Создаю тестовый namespace: gatekeeper-test"
kubectl create namespace gatekeeper-test --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null

echo ""
echo "📋 Тест 1: Привилегированный под (ДОЛЖЕН быть ЗАБЛОКИРОВАН Gatekeeper)"
timeout 5 kubectl apply -f ../gatekeeper-test-manifests/01-privileged-pod.yaml 2>&1
if [ $? -eq 0 ]; then
    echo "   ❌ НЕ ЗАБЛОКИРОВАН (проблема)"
    kubectl delete -f ../gatekeeper-test-manifests/01-privileged-pod.yaml --ignore-not-found 2>/dev/null
else
    echo "   ✅ Заблокирован Gatekeeper"
fi

echo ""
echo "📋 Тест 2: HostPath под (ДОЛЖЕН быть ЗАБЛОКИРОВАН Gatekeeper)"
timeout 5 kubectl apply -f ../gatekeeper-test-manifests/02-hostpath-pod.yaml 2>&1
if [ $? -eq 0 ]; then
    echo "   ❌ НЕ ЗАБЛОКИРОВАН (проблема)"
    kubectl delete -f ../gatekeeper-test-manifests/02-hostpath-pod.yaml --ignore-not-found 2>/dev/null
else
    echo "   ✅ Заблокирован Gatekeeper"
fi

echo ""
echo "📋 Тест 3: Root user под (ДОЛЖЕН быть ЗАБЛОКИРОВАН Gatekeeper)"
timeout 5 kubectl apply -f ../gatekeeper-test-manifests/03-root-user-pod.yaml 2>&1
if [ $? -eq 0 ]; then
    echo "   ❌ НЕ ЗАБЛОКИРОВАН (проблема)"
    kubectl delete -f ../gatekeeper-test-manifests/03-root-user-pod.yaml --ignore-not-found 2>/dev/null
else
    echo "   ✅ Заблокирован Gatekeeper"
fi

echo ""
echo "📋 Тест 4: Безопасные поды (ДОЛЖНЫ быть РАЗРЕШЕНЫ)"
kubectl apply -f ../gatekeeper-test-manifests/01-secure.yaml 2>/dev/null && echo "   ✅ 01-secure.yaml разрешён" || echo "   ❌ 01-secure.yaml заблокирован"
kubectl delete -f ../gatekeeper-test-manifests/01-secure.yaml --ignore-not-found 2>/dev/null

kubectl apply -f ../gatekeeper-test-manifests/02-secure.yaml 2>/dev/null && echo "   ✅ 02-secure.yaml разрешён" || echo "   ❌ 02-secure.yaml заблокирован"
kubectl delete -f ../gatekeeper-test-manifests/02-secure.yaml --ignore-not-found 2>/dev/null

kubectl apply -f ../gatekeeper-test-manifests/03-secure.yaml 2>/dev/null && echo "   ✅ 03-secure.yaml разрешён" || echo "   ❌ 03-secure.yaml заблокирован"
kubectl delete -f ../gatekeeper-test-manifests/03-secure.yaml --ignore-not-found 2>/dev/null

echo ""
echo "=========================================="
echo "✅ Проверка Gatekeeper завершена"
echo "=========================================="
