#!/bin/bash
# Скрипт для создания пользователей Kubernetes для PropDevelopment
# Финальная версия - проверена на Minikube

USERS_DIR="./k8s-users"
mkdir -p $USERS_DIR

echo "🚀 Начинаю создание пользователей для PropDevelopment"
echo "========================================================"
echo ""

# Проверяем, что Minikube запущен
if ! minikube status &>/dev/null; then
    echo "❌ Minikube не запущен. Выполните: minikube start"
    exit 1
fi

# Копируем CA сертификаты из контейнера Minikube
setup_ca_certs() {
    echo "📋 Проверка CA сертификатов Minikube..."
    
    mkdir -p ~/.minikube
    
    # Копируем ca.crt
    if [ ! -f ~/.minikube/ca.crt ]; then
        echo "   📥 Копирую ca.crt из контейнера minikube..."
        docker exec minikube cat /var/lib/minikube/ca.crt > ~/.minikube/ca.crt 2>/dev/null
        echo "   ✅ ca.crt скопирован"
    else
        echo "   ✅ ca.crt уже существует"
    fi
    
    # Копируем ca.key
    if [ ! -f ~/.minikube/ca.key ]; then
        echo "   📥 Копирую ca.key из контейнера minikube..."
        docker exec minikube cat /var/lib/minikube/ca.key > ~/.minikube/ca.key 2>/dev/null
        echo "   ✅ ca.key скопирован"
    else
        echo "   ✅ ca.key уже существует"
    fi
    
    echo "✅ CA сертификаты готовы"
    echo ""
}

# Получаем информацию о кластере
MINIKUBE_IP=$(minikube ip)
# ВАЖНО: используем имя кластера "minikube" (не "propdev-cluster")
CLUSTER_NAME="minikube"
echo "📡 Кластер: $CLUSTER_NAME"
echo "🌐 IP: $MINIKUBE_IP"
echo ""

# Настраиваем CA сертификаты
setup_ca_certs

# Функция создания пользователя
create_user() {
    USERNAME=$1
    GROUP=$2
    
    echo "🔧 Создаю пользователя: $USERNAME (группа: $GROUP)"
    
    # 1. Приватный ключ
    openssl genrsa -out $USERS_DIR/${USERNAME}.key 2048 2>/dev/null
    echo "   ✅ Приватный ключ: $USERS_DIR/${USERNAME}.key"
    
    # 2. CSR
    openssl req -new -key $USERS_DIR/${USERNAME}.key \
        -out $USERS_DIR/${USERNAME}.csr \
        -subj "/CN=${USERNAME}/O=${GROUP}" 2>/dev/null
    echo "   ✅ CSR: $USERS_DIR/${USERNAME}.csr"
    
    # 3. Подписанный сертификат
    openssl x509 -req -in $USERS_DIR/${USERNAME}.csr \
        -CA ~/.minikube/ca.crt -CAkey ~/.minikube/ca.key \
        -CAcreateserial -out $USERS_DIR/${USERNAME}.crt -days 365 2>/dev/null
    echo "   ✅ Сертификат: $USERS_DIR/${USERNAME}.crt"
    
    # 4. Создаём kubeconfig
    KUBECONFIG_FILE="$USERS_DIR/${USERNAME}.kubeconfig"
    
    kubectl config set-cluster $CLUSTER_NAME \
        --certificate-authority=/home/banbao/.minikube/ca.crt \
        --embed-certs=true \
        --server=https://${MINIKUBE_IP}:8443 \
        --kubeconfig=$KUBECONFIG_FILE 2>/dev/null
    
    kubectl config set-credentials ${USERNAME} \
        --client-certificate=$USERS_DIR/${USERNAME}.crt \
        --client-key=$USERS_DIR/${USERNAME}.key \
        --embed-certs=true \
        --kubeconfig=$KUBECONFIG_FILE 2>/dev/null
    
    kubectl config set-context ${USERNAME}-context \
        --cluster=$CLUSTER_NAME \
        --user=${USERNAME} \
        --kubeconfig=$KUBECONFIG_FILE 2>/dev/null
    
    kubectl config use-context ${USERNAME}-context \
        --kubeconfig=$KUBECONFIG_FILE 2>/dev/null
    
    echo "   ✅ Kubeconfig: $KUBECONFIG_FILE"
    echo "✅ Пользователь $USERNAME готов"
    echo ""
}

# Создаём всех пользователей
create_user "alex-sre" "sre-team"
create_user "irina-security" "security-team"
create_user "pavel-dev" "dev-team"
create_user "olga-auditor" "auditors"

echo "========================================================"
echo "🎉 Готово! Все пользователи созданы"
echo ""
echo "📁 Содержимое $USERS_DIR/:"
ls -la $USERS_DIR/
echo ""
echo "📌 Проверка доступа:"
echo "   kubectl --kubeconfig=./k8s-users/alex-sre.kubeconfig get nodes"