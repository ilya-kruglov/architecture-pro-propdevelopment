#!/bin/bash
# Скрипт для проверки работы PodSecurity Admission

set -e

echo "=========================================="
echo "Проверка PodSecurity Admission"
echo "=========================================="

# Создаём namespace
kubectl apply -f ../01-create-namespace.yaml

echo ""
echo "📋 Тест 1: Привилегированный под (ДОЛЖЕН быть ЗАБЛОКИРОВАН)"
if kubectl apply -f ../insecure-manifests/01-privileged-pod.yaml 2>&1 | grep -q "Forbidden"; then
    echo "   ✅ Заблокирован (ожидаемо)"
else
    echo "   ❌ НЕ ЗАБЛОКИРОВАН (ошибка)"
fi

echo ""
echo "📋 Тест 2: HostPath под (ДОЛЖЕН быть ЗАБЛОКИРОВАН)"
if kubectl apply -f ../insecure-manifests/02-hostpath-pod.yaml 2>&1 | grep -q "Forbidden"; then
    echo "   ✅ Заблокирован (ожидаемо)"
else
    echo "   ❌ НЕ ЗАБЛОКИРОВАН (ошибка)"
fi

echo ""
echo "📋 Тест 3: Root user под (ДОЛЖЕН быть ЗАБЛОКИРОВАН)"
if kubectl apply -f ../insecure-manifests/03-root-user-pod.yaml 2>&1 | grep -q "Forbidden"; then
    echo "   ✅ Заблокирован (ожидаемо)"
else
    echo "   ❌ НЕ ЗАБЛОКИРОВАН (ошибка)"
fi

echo ""
echo "=========================================="
echo "✅ Проверка PodSecurity Admission завершена"
echo "=========================================="