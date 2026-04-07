#!/bin/bash
# Полный скрипт для настройки Task5 с поддержкой Network Policies

set -e

echo "=========================================="
echo "Task5: Управление трафиком внутри кластера"
echo "=========================================="

# Проверка наличия Calico CNI
if ! kubectl get pods -n kube-system 2>/dev/null | grep -q calico; then
    echo "❌ CNI Calico не найден!"
    echo "   Network Policies не будут работать."
    echo ""
    echo "   Решение:"
    echo "   minikube delete"
    echo "   minikube start --driver=docker --cpus=2 --memory=4096 --cni=calico"
    echo "   kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=60s"
    echo ""
    exit 1
fi

echo "✅ CNI Calico найден. Network Policies будут работать."

# Проверка наличия файла с политиками
if [ ! -f "non-admin-api-allow.yaml" ]; then
    echo "❌ Файл non-admin-api-allow.yaml не найден!"
    echo "   Убедитесь, что файл находится в текущей директории"
    exit 1
fi

echo "✅ Файл non-admin-api-allow.yaml найден"
echo ""

# Создаём namespace
echo "📁 Создаю namespace task5..."
kubectl create namespace task5 --dry-run=client -o yaml | kubectl apply -f -
kubectl config set-context --current --namespace=task5

echo ""
echo "🚀 Создаю 4 сервиса с метками..."

kubectl run front-end-app --image=nginx --labels="role=front-end" --expose --port 80
kubectl run back-end-api-app --image=nginx --labels="role=back-end-api" --expose --port 80
kubectl run admin-front-end-app --image=nginx --labels="role=admin-front-end" --expose --port 80
kubectl run admin-back-end-api-app --image=nginx --labels="role=admin-back-end-api" --expose --port 80

echo ""
echo "⏳ Ожидаем запуска подов (15 секунд)..."
sleep 15

echo ""
echo "📋 Созданные поды:"
kubectl get pods --show-labels

echo ""
echo "📋 Созданные сервисы:"
kubectl get services

echo ""
echo "🔒 Применяю сетевые политики..."
kubectl apply -f non-admin-api-allow.yaml

echo ""
echo "⏳ Ожидаем применения политик (5 секунд)..."
sleep 5

echo ""
echo "📋 Сетевые политики:"
kubectl get networkpolicies

# Проверяем, что все 3 политики созданы
POLICY_COUNT=$(kubectl get networkpolicies -o name | wc -l)
if [ "$POLICY_COUNT" -ne 3 ]; then
    echo ""
    echo "⚠️  Внимание: Создано $POLICY_COUNT политик вместо 3"
    echo "   Ожидаются: frontend-backend-allow, admin-frontend-backend-allow, deny-all-ingress"
else
    echo ""
    echo "✅ Все 3 политики созданы успешно"
fi

echo ""
echo "=========================================="
echo "✅ Готово!"
echo ""
echo "📌 Для тестирования выполните команды:"
echo ""
echo "   # Тест 1: front-end -> back-end-api (ДОЛЖЕН работать)"
echo "   kubectl run test1 --rm -i --image=alpine --labels='role=front-end' --restart=Never -- sh -c 'wget -qO- --timeout=5 http://back-end-api-app:80 | head -1'"
echo ""
echo "   # Тест 2: front-end -> admin-back-end-api (НЕ ДОЛЖЕН работать)"
echo "   kubectl run test2 --rm -i --image=alpine --labels='role=front-end' --restart=Never -- sh -c 'wget -qO- --timeout=5 http://admin-back-end-api-app:80 2>&1 | grep -E \"timed out|failed\"'"
echo ""
echo "   # Тест 3: admin-front-end -> admin-back-end-api (ДОЛЖЕН работать)"
echo "   kubectl run test3 --rm -i --image=alpine --labels='role=admin-front-end' --restart=Never -- sh -c 'wget -qO- --timeout=5 http://admin-back-end-api-app:80 | head -1'"
echo ""
echo "   # Тест 4: admin-front-end -> back-end-api (НЕ ДОЛЖЕН работать)"
echo "   kubectl run test4 --rm -i --image=alpine --labels='role=admin-front-end' --restart=Never -- sh -c 'wget -qO- --timeout=5 http://back-end-api-app:80 2>&1 | grep -E \"timed out|failed\"'"
echo ""
echo "=========================================="
echo ""
echo "📌 Ожидаемые результаты:"
echo "   test1: HTML-код (<!DOCTYPE html>)"
echo "   test2: download timed out"
echo "   test3: HTML-код (<!DOCTYPE html>)"
echo "   test4: download timed out"
echo "=========================================="