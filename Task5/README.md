# Task5: Управление трафиком внутри кластера Kubernetes

**Компания:** PropDevelopment  
**Задание:** Разграничение трафика между сервисами с помощью Network Policies

## Предварительные требования

- Minikube установлен и настроен
- Kubectl установлен
- Кластер Minikube **запущен**

## Структура файлов в Task5
```
Task5/
├── README.md # Инструкция
├── non-admin-api-allow.yaml # Сетевые политики
└── setup-task5.sh # Скрипт автоматической настройки (вместо пошаговой инструкции настройки ниже)
```

## Пошаговое выполнение

### Шаг 1: Запустить Minikube (ещё не запущен)

#### ВАЖНО: Поддержка Network Policies

Minikube с драйвером `docker` по умолчанию НЕ поддерживает Network Policies.

**Перед выполнением задания необходимо запустить Minikube с CNI Calico**

Если этого не сделать, все тесты покажут ложноположительные результаты (трафик будет разрешён везде).

```bash
# Удалить текущий кластер
minikube delete

# Проверить статус Minikube
minikube status

# Если Minikube не запущен, запустить:
minikube start --driver=docker --cpus=2 --memory=4096 --cni=calico

# Дождаться готовности Calico
kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=60s

# Убедиться, что кластер работает
kubectl get nodes
```

### Шаг 2: Создать namespace для задания

```bash
# Создаём отдельное пространство для изоляции Task5
kubectl create namespace task5

# Переключаем контекст на это namespace
kubectl config set-context --current --namespace=task5

# Проверяем текущий namespace
kubectl config view --minify | grep namespace:
```

### Шаг 3: Создать 4 сервиса с метками

```bash
# 1. front-end (UI для обычных пользователей)
kubectl run front-end-app --image=nginx --labels="role=front-end" --expose --port 80

# 2. back-end-api (API для front-end)
kubectl run back-end-api-app --image=nginx --labels="role=back-end-api" --expose --port 80

# 3. admin-front-end (UI для администраторов)
kubectl run admin-front-end-app --image=nginx --labels="role=admin-front-end" --expose --port 80

# 4. admin-back-end-api (API для admin-front-end)
kubectl run admin-back-end-api-app --image=nginx --labels="role=admin-back-end-api" --expose --port 80
```

### Шаг 4: Проверить созданные ресурсы

```bash
# Проверка подов (должно быть 4 пода в статусе Running)
kubectl get pods --show-labels

# Проверка сервисов (должно быть 4 сервиса)
kubectl get services

# Пример ожидаемого вывода:
# NAME                     READY   STATUS    RESTARTS   AGE   LABELS
# front-end-app            1/1     Running   0          10s   role=front-end
# back-end-api-app         1/1     Running   0          10s   role=back-end-api
# admin-front-end-app      1/1     Running   0          10s   role=admin-front-end
# admin-back-end-api-app   1/1     Running   0          10s   role=admin-back-end-api
```

### Шаг 5: Применить сетевые политики

```bash
kubectl apply -f non-admin-api-allow.yaml
```

### Шаг 6: Проверить сетевые политики

```bash
kubectl get networkpolicies

# Ожидаемый вывод:
# NAME                          POD-SELECTOR             AGE
# admin-frontend-backend-allow  role=admin-back-end-api   5s
# deny-all-ingress              {}                        5s
# frontend-backend-allow        role=back-end-api         5s
```

### Шаг 7: Тестирование доступа

#### Тест 1: front-end → back-end-api (ДОЛЖЕН работать)
```bash
kubectl run test1 --rm -i --image=alpine --labels="role=front-end" --restart=Never -- sh -c "wget -qO- --timeout=5 http://back-end-api-app:80 | head -1"
```
**Ожидаемый результат:** HTML-код (должен быть `<!DOCTYPE html>`)

#### Тест 2: front-end → admin-back-end-api (НЕ ДОЛЖЕН работать)
```bash
kubectl run test2 --rm -i --image=alpine --labels="role=front-end" --restart=Never -- sh -c "wget -qO- --timeout=5 http://admin-back-end-api-app:80 2>&1 | grep -E 'timed out|failed'"
```
**Ожидаемый результат:** `wget: download timed out` или `Connection refused`

#### Тест 3: admin-front-end → admin-back-end-api (ДОЛЖЕН работать)
```bash
kubectl run test3 --rm -i --image=alpine --labels="role=admin-front-end" --restart=Never -- sh -c "wget -qO- --timeout=5 http://admin-back-end-api-app:80 | head -1"
```
**Ожидаемый результат:** HTML-код (должен быть `<!DOCTYPE html>`)

#### Тест 4: admin-front-end → back-end-api (НЕ ДОЛЖЕН работать)
```bash
kubectl run test4 --rm -i --image=alpine --labels="role=admin-front-end" --restart=Never -- sh -c "wget -qO- --timeout=5 http://back-end-api-app:80 2>&1 | grep -E 'timed out|failed'"
```
**Ожидаемый результат:** `wget: download timed out` или `Connection refused`

## Полезные команды для отладки
```bash
# Просмотр деталей сетевой политики
kubectl describe networkpolicy frontend-backend-allow

# Просмотр логов подов
kubectl logs front-end-app

# Проверка эндпоинтов сервисов
kubectl get endpoints

# Временное отключение политик (для отладки)
kubectl delete networkpolicy deny-all-ingress
# После отладки: kubectl apply -f non-admin-api-allow.yaml
```

## Очистка после выполнения
```bash
# Удалить namespace task5 (удалит все поды, сервисы и политики)
kubectl delete namespace task5

# Вернуться в namespace default
kubectl config set-context --current --namespace=default

# Остановить Minikube
minikube stop

# Удалить кластер
minikube delete
```
---
##  Скрипт автоматической настройки `setup-task5.sh`

### Шаг 1: Запустить Minikube (ещё не запущен)
```bash
# Удалить текущий кластер
minikube delete

# Проверить статус Minikube
minikube status

# Если Minikube не запущен, запустить:
minikube start --driver=docker --cpus=2 --memory=4096 --cni=calico

# Дождаться готовности Calico
kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=60s

# Убедиться, что кластер работает
kubectl get nodes
```

### Шаг 2: Запустить скрипт автоматической настройки `setup-task5.sh`
```bash
bash setup-task5.sh
```

### Шаг 3: Тестирование доступа
Инструкция по тестированию будет выведена в `output` (в терминале).

### Шаг 4: Очистка после выполнения
```bash
# Удалить namespace task5 (удалит все поды, сервисы и политики)
kubectl delete namespace task5

# Вернуться в namespace default
kubectl config set-context --current --namespace=default

# Остановить Minikube
minikube stop

# Удалить кластер
minikube delete
```