# Task4: Защита доступа к кластеру Kubernetes

**Компания:** PropDevelopment  
**Задание:** Организация ролевого доступа (RBAC) к кластеру Kubernetes  
**Контекст:** В рамках аудита безопасности необходимо разграничить доступ к управлению кластером для различных групп пользователей.

## Структура ролевой модели

| Роль | Права | Группы пользователей |
|------|-------|---------------------|
| **cluster-admin** | Полный доступ ко всем ресурсам кластера | `sre-team` |
| **security-auditor** | Чтение секретов и audit-логов | `security-team` |
| **namespace-editor** | Управление ресурсами в namespace `dev-services` и `prod-services` (без секретов) | `dev-team` |
| **cluster-viewer** | Только чтение ресурсов (без секретов) | `auditors` |


## Скрипты

| Файл | Назначение |
|------|------------|
| `setup-minikube.sh` | Поднятие пустого кластера Minikube |
| `create_users.sh` | Создание пользователей (сертификаты + kubeconfig) |
| `create_roles.sh` | Создание ClusterRole и Role |
| `bind_roles.sh` | Привязка пользователей к ролям |
| `RBAC_table.md` | Детальная таблица ролей с обоснованием |

## Команды для выполнения

```bash
cd Task4/

# Шаг 1: поднять пустой Minikube
bash setup-minikube.sh

# Шаг 2: создать пользователей
bash create_users.sh

# Шаг 3: создать роли
bash create_roles.sh

# Шаг 4: связать пользователей с ролями
bash bind_roles.sh
```

## Проверка результатов
После выполнения всех скриптов проверьте доступ через kubeconfig файлы:

#### Проверка auditor (только чтение, без секретов)
`kubectl --kubeconfig=./k8s-users/olga-auditor.kubeconfig auth can-i get pods`
`kubectl --kubeconfig=./k8s-users/olga-auditor.kubeconfig auth can-i get secrets`

#### Проверка security-team (чтение секретов)
`kubectl --kubeconfig=./k8s-users/irina-security.kubeconfig auth can-i get secrets`

#### Проверка dev-team (создание pods в dev-services, но без секретов)
`kubectl --kubeconfig=./k8s-users/pavel-dev.kubeconfig auth can-i create pods --namespace=dev-services`
`kubectl --kubeconfig=./k8s-users/pavel-dev.kubeconfig auth can-i get secrets --namespace=dev-services`

#### Проверка sre-team (полный доступ)
`kubectl --kubeconfig=./k8s-users/alex-sre.kubeconfig auth can-i create namespaces`
`kubectl --kubeconfig=./k8s-users/alex-sre.kubeconfig auth can-i get nodes`

Предупреждения `Warning: resource 'namespaces' is not namespace scoped` — это нормально, просто информирует, что команда работает на уровне кластера.

#### Ожидаемые результаты

| Пользователь | Команда проверки | Ожидаемый результат |
|-------------|------------------|---------------------|
| `olga-auditor` | `get pods` | `yes` |
| `olga-auditor` | `get secrets` | `no` |
| `irina-security` | `get secrets` | `yes` |
| `pavel-dev` | `create pods` в `dev-services` | `yes` |
| `pavel-dev` | `get secrets` в `dev-services` | `no` |
| `alex-sre` | `create namespaces` | `yes` |
| `alex-sre` | `get nodes` | `yes` |

## Остановка кластера
`minikube stop`

## Очистка кластера

`minikube delete`