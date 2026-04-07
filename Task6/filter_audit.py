#!/usr/bin/env python3
"""
Скрипт фильтрации audit.log для обнаружения подозрительных событий
Использование: python3 filter_audit.py /path/to/audit.log
"""

import json
import sys


def is_suspicious_event(event):
    """Определяет, является ли событие подозрительным"""

    # 1. Доступ к secrets
    obj_ref = event.get('objectRef', {})
    if (obj_ref.get('resource') == 'secrets'
            and event.get('verb') in ['get', 'list', 'watch']):
        return True, 'SECRET_ACCESS', 'Доступ к секретам'

    # 2. Создание привилегированных подов
    if (obj_ref.get('resource') == 'pods'
            and event.get('verb') == 'create'):
        request = event.get('requestObject', {})
        containers = request.get('spec', {}).get('containers', [])
        for container in containers:
            sec_ctx = container.get('securityContext', {})
            if sec_ctx.get('privileged') is True:
                return True, 'PRIVILEGED_POD', (
                    'Создание привилегированного пода'
                )

    # 3. kubectl exec в подах
    if (event.get('verb') == 'create'
            and obj_ref.get('subresource') == 'exec'):
        return True, 'EXEC_IN_POD', (
            'Выполнение команд в поде (kubectl exec)'
        )

    # 4. Создание/изменение RoleBinding с опасными правами
    if (obj_ref.get('resource') == 'rolebindings'
            and event.get('verb') in ['create', 'patch', 'update']):
        request = event.get('requestObject', {})
        role_ref = request.get('roleRef', {})
        if role_ref.get('name') in ['cluster-admin', 'admin']:
            return True, 'DANGEROUS_ROLEBINDING', (
                f"Создание RoleBinding с правами {role_ref['name']}"
            )

    # 5. Удаление audit policy
    if (obj_ref.get('resource') == 'configmaps'
            and 'audit' in str(event)):
        return True, 'AUDIT_POLICY_CHANGE', 'Изменение audit политики'

    # 6. Действия от service account monitoring
    user = event.get('user', {}).get('username', '')
    if ('monitoring' in user
            and event.get('verb') in ['create', 'delete', 'patch', 'update']):
        return True, 'SUSPICIOUS_USER', (
            f"Подозрительное действие от {user}"
        )

    return False, None, None


def main():
    if len(sys.argv) < 2:
        print("Использование: python3 filter_audit.py <audit.log> "
              "[--output output.json]")
        sys.exit(1)

    audit_file = sys.argv[1]
    output_file = 'audit-extract.json'

    if '--output' in sys.argv:
        idx = sys.argv.index('--output')
        if idx + 1 < len(sys.argv):
            output_file = sys.argv[idx + 1]

    suspicious_events = []
    total_events = 0

    print(f"🔍 Анализ файла: {audit_file}")
    print("=" * 60)

    try:
        with open(audit_file, 'r') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue

                try:
                    event = json.loads(line)
                    total_events += 1

                    is_susp, category, reason = is_suspicious_event(event)

                    if is_susp:
                        # Добавляем метаинформацию
                        event['_suspicious_category'] = category
                        event['_suspicious_reason'] = reason
                        event['_timestamp'] = event.get(
                            'requestReceivedTimestamp', ''
                        )
                        suspicious_events.append(event)

                        # Выводим информацию в консоль
                        user = event.get('user', {}).get(
                            'username', 'unknown'
                        )
                        verb = event.get('verb', 'unknown')
                        obj_ref = event.get('objectRef', {})
                        resource = obj_ref.get('resource', 'unknown')
                        namespace = obj_ref.get('namespace', 'unknown')

                        print(f"\n⚠️  [{category}] {reason}")
                        print(f"   Пользователь: {user}")
                        print(f"   Действие: {verb} {resource}")
                        print(f"   Namespace: {namespace}")

                except json.JSONDecodeError:
                    continue

    except FileNotFoundError:
        print(f"❌ Файл {audit_file} не найден!")
        sys.exit(1)

    # Сохраняем результаты
    with open(output_file, 'w') as f:
        json.dump(suspicious_events, f, indent=2, ensure_ascii=False,
                  default=str)

    print("\n" + "=" * 60)
    print("📊 Статистика:")
    print(f"   Всего событий: {total_events}")
    print(f"   Подозрительных событий: {len(suspicious_events)}")
    print(f"   Результат сохранён в: {output_file}")
    print("=" * 60)


if __name__ == "__main__":
    main()
