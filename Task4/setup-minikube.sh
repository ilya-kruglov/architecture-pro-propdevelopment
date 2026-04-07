#!/bin/bash
# Скрипт для поднятия пустого кластера Minikube

set -e

echo "🚀 Подготовка окружения для Task4: Ролевой доступ к Kubernetes"
echo "================================================================"
echo ""

# Проверка наличия Minikube
if ! command -v minikube &> /dev/null; then
    echo "❌ Minikube не установлен!"
    echo "   Установите Minikube: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi

# Проверка наличия kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl не установлен!"
    echo "   Установите kubectl: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Проверка наличия openssl (для создания сертификатов пользователей)
if ! command -v openssl &> /dev/null; then
    echo "❌ openssl не установлен!"
    echo "   Установите: sudo apt install openssl -y"
    exit 1
fi

echo "✅ Все зависимости проверены"
echo ""

# Остановка существующего кластера (если есть)
if minikube status &> /dev/null; then
    echo "⚠️  Обнаружен запущенный кластер Minikube. Останавливаю..."
    minikube stop
    echo "✅ Кластер остановлен"
    echo ""
fi

# Удаление существующего кластера (опционально, для чистоты)
read -p "Удалить существующий кластер Minikube полностью? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Удаляю существующий кластер..."
    minikube delete
    echo "✅ Кластер удалён"
    echo ""
fi

# Запуск нового пустого кластера Minikube
echo "🔄 Запускаю новый пустой кластер Minikube..."
echo "   (использую драйвер docker, 2 CPU, 4GB RAM)"
minikube start \
    --driver=docker \
    --cpus=2 \
    --memory=4096 \
    --kubernetes-version=v1.28.0

echo ""
echo "✅ Minikube запущен:"
minikube status

echo ""
echo "📦 Проверка узлов кластера:"
kubectl get nodes

echo ""
echo "📦 Проверка pods во всех namespace (должно быть пусто или только системные):"
kubectl get pods --all-namespaces

echo ""
echo "📦 Проверка созданных namespace (должны быть только стандартные):"
kubectl get namespaces

echo ""
echo "================================================================"
echo "🎉 Пустой кластер Minikube готов к работе!"
echo ""
echo "📌 Далее выполните скрипты по порядку:"
echo "   1. bash create_users.sh      - создание пользователей"
echo "   2. bash create_roles.sh      - создание ролей RBAC"
echo "   3. bash bind_roles.sh        - привязка пользователей к ролям"
echo ""
echo "🔧 Полезные команды:"
echo "   minikube dashboard           - открыть веб-интерфейс Kubernetes"
echo "   minikube stop                - остановить кластер"
echo "   minikube delete              - удалить кластер"
echo "================================================================"