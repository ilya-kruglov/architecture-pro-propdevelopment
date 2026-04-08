# Task7: Аудит и обеспечение соответствия политике безопасности контейнеров

**Компания:** PropDevelopment  
**Задание:** Настройка PodSecurity Admission и OPA Gatekeeper

## Структура файлов

Task7/
├── 01-create-namespace.yaml # Namespace с PodSecurity restricted
├── insecure-manifests/ # Небезопасные поды (должны быть заблокированы)
│ ├── 01-privileged-pod.yaml
│ ├── 02-hostpath-pod.yaml
│ └── 03-root-user-pod.yaml
├── secure-manifests/ # Безопасные поды (должны быть разрешены)
│ ├── 01-secure.yaml
│ ├── 02-secure.yaml
│ └── 03-secure.yaml
├── gatekeeper/
│ ├── constraint-templates/ # Rego шаблоны для Gatekeeper
│ │ ├── privileged-template.yaml
│ │ ├── hostpath-template.yaml
│ │ └── runasnonroot-template.yaml
│ └── constraints/ # Применение политик
│ ├── privileged-constraint.yaml
│ ├── hostpath-constraint.yaml
│ └── runasnonroot-constraint.yaml
├── gatekeeper-test-manifests/ # Манифесты для тестирования Gatekeeper
│ ├── 01-privileged-pod.yaml
│ ├── 02-hostpath-pod.yaml
│ ├── 03-root-user-pod.yaml
│ ├── 01-secure.yaml
│ ├── 02-secure.yaml
│ └── 03-secure.yaml
├── verify/
│ ├── verify-admission.sh # Проверка PodSecurity Admission
│ └── validate-security.sh # Проверка Gatekeeper
└── README_FOR_REVIEWER.md

---

## Почему созданы дополнительные файлы и папки?
| Файл/Папка | Назначение | Причина создания |
|------------|------------|------------------|
| `gatekeeper-test-manifests/` | Тестовые манифесты для проверки Gatekeeper | PodSecurity Admission блокирует небезопасные поды в `audit-zone`, но Gatekeeper нужно проверить в отдельном namespace без PodSecurity. Создана для изоляции тестов Gatekeeper. |
| `01-secure.yaml` (в gatekeeper-test-manifests) | Безопасные поды для проверки Gatekeeper | Проверка, что Gatekeeper НЕ блокирует поды, соответствующие политикам безопасности. |
| `01-privileged-pod.yaml` (в gatekeeper-test-manifests) | Небезопасный под для проверки Gatekeeper | Проверка, что Gatekeeper блокирует привилегированные поды. |
| `02-hostpath-pod.yaml` (в gatekeeper-test-manifests) | Небезопасный под для проверки Gatekeeper | Проверка, что Gatekeeper блокирует поды с hostPath. |
| `03-root-user-pod.yaml` (в gatekeeper-test-manifests) | Небезопасный под для проверки Gatekeeper | Проверка, что Gatekeeper блокирует поды от root. |

### Обоснование создания отдельной папки

1. **PodSecurity Admission** в `audit-zone` (restricted уровень) автоматически блокирует небезопасные поды на раннем этапе
2. **Gatekeeper** не получает запросы на проверку, если под уже заблокирован PodSecurity
3. Для проверки именно **Gatekeeper** необходимо создать отдельный namespace (`gatekeeper-test`) **без PodSecurity**
4. Манифесты в `gatekeeper-test-manifests/` являются копиями манифестов из `insecure-manifests/` и `secure-manifests/`, но применяются в `gatekeeper-test`

**Без этой папки невозможно проверить, что Gatekeeper действительно работает и блокирует небезопасные поды.**

---

## Запуск проверки

### 1. Подготовка кластера
```bash
# Запуск Minikube с Calico CNI (поддержка Network Policies)
minikube start --driver=docker --cpus=2 --memory=4096 --cni=calico
# Установка Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml

# Ожидание готовности Gatekeeper
kubectl wait --for=condition=ready pod -l control-plane=controller-manager -n gatekeeper-system --timeout=60s
```

### 2. Проверка PodSecurity Admission
```bash
cd Task7/verify
chmod +x verify-admission.sh
bash verify-admission.sh
```
**Ожидаемый вывод:**
```
==========================================
Проверка PodSecurity Admission
==========================================
namespace/audit-zone created

📋 Тест 1: Привилегированный под (ДОЛЖЕН быть ЗАБЛОКИРОВАН)
   ✅ Заблокирован (ожидаемо)

📋 Тест 2: HostPath под (ДОЛЖЕН быть ЗАБЛОКИРОВАН)
   ✅ Заблокирован (ожидаемо)

📋 Тест 3: Root user под (ДОЛЖЕН быть ЗАБЛОКИРОВАН)
   ✅ Заблокирован (ожидаемо)

==========================================
✅ Проверка PodSecurity Admission завершена
==========================================
```

### 3. Проверка Gatekeeper
```bash
cd Task7/verify
chmod +x validate-security.sh
bash validate-security.sh
```
**Ожидаемый вывод:**
```
==========================================
Проверка Gatekeeper политик
==========================================
✅ Gatekeeper установлен

📁 Создаю тестовый namespace: gatekeeper-test
namespace/gatekeeper-test unchanged

📋 Тест 1: Привилегированный под (ДОЛЖЕН быть ЗАБЛОКИРОВАН Gatekeeper)
Error from server (Forbidden): ... admission webhook "validation.gatekeeper.sh" denied the request: [run-as-non-root] Container nginx in pod pod-privileged must set runAsNonRoot=true
[privileged-pods] Pod pod-privileged uses privileged container: nginx
   ✅ Заблокирован Gatekeeper

📋 Тест 2: HostPath под (ДОЛЖЕН быть ЗАБЛОКИРОВАН Gatekeeper)
Error from server (Forbidden): ... admission webhook "validation.gatekeeper.sh" denied the request: [run-as-non-root] Container nginx in pod pod-hostpath must set runAsNonRoot=true
[hostpath-volumes] Pod pod-hostpath uses hostPath volume: host-volume
   ✅ Заблокирован Gatekeeper

📋 Тест 3: Root user под (ДОЛЖЕН быть ЗАБЛОКИРОВАН Gatekeeper)
Error from server (Forbidden): ... admission webhook "validation.gatekeeper.sh" denied the request: [run-as-non-root] Container nginx in pod pod-root-user must set runAsNonRoot=true
[run-as-non-root] Container nginx in pod pod-root-user runs as root (UID 0)
   ✅ Заблокирован Gatekeeper

📋 Тест 4: Безопасные поды (ДОЛЖНЫ быть РАЗРЕШЕНЫ)
pod/pod-secure created
   ✅ 01-secure.yaml разрешён
pod/pod-no-hostpath created
   ✅ 02-secure.yaml разрешён
pod/pod-nonroot created
   ✅ 03-secure.yaml разрешён

==========================================
✅ Проверка Gatekeeper завершена
==========================================
```

## Политики безопасности

### PodSecurity (01-create-namespace.yaml)
```yaml
labels:
  pod-security.kubernetes.io/enforce: restricted
  pod-security.kubernetes.io/enforce-version: latest
```

### Gatekeeper Constraints
| Constraint | Запрещает | Rego правило |
|------------|-----------|--------------|
| `privilegedpods` | `privileged: true` | `container.securityContext.privileged == true` |
| `hostpathvolumes` | `hostPath` volumes | `volume.hostPath` |
| `runasnonroot` | `runAsUser: 0` и отсутствие `runAsNonRoot: true` | `runAsUser == 0` или `runAsNonRoot != true` |

## Очистка
```bash
# Удалить тестовые ресурсы
kubectl delete namespace audit-zone --ignore-not-found
kubectl delete namespace gatekeeper-test --ignore-not-found

# Удалить Gatekeeper
kubectl delete -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml

# Остановить Minikube
minikube stop

# Удалить кластер
minikube delete
```
---
## Примечания для ревьюера
1. **PodSecurity Admission** — встроенный механизм Kubernetes, проверяет поды при создании
2. **Gatekeeper** — внешний admission controller, добавляет дополнительные проверки через Rego
3. Оба механизма работают параллельно: PodSecurity проверяет общие политики, Gatekeeper — специфические
4. Папка `gatekeeper-test-manifests/` **создана дополнительно** для проверки работы Gatekeeper в изолированном namespace без PodSecurity
5. Все небезопасные поды блокируются, безопасные — успешно создаются