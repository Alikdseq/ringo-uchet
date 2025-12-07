# Secrets Management для Ringo Uchet

Этот модуль содержит конфигурацию для управления секретами с использованием SOPS и GitHub Secrets.

## Методы управления секретами

### 1. GitHub Secrets (рекомендуется для CI/CD)

GitHub Secrets используются для хранения секретов, которые нужны в CI/CD pipelines.

#### Настройка GitHub Secrets

1. Перейдите в Settings → Secrets and variables → Actions
2. Добавьте следующие секреты:

**Backend секреты:**
- `STAGING_HOST` - IP адрес staging сервера
- `STAGING_USER` - Пользователь для SSH
- `STAGING_SSH_KEY` - Приватный SSH ключ
- `STAGING_DB_HOST`, `STAGING_DB_PORT`, `STAGING_DB_NAME`, `STAGING_DB_USER`, `STAGING_DB_PASSWORD`
- `STAGING_CELERY_BROKER_URL`, `STAGING_CELERY_RESULT_BACKEND`
- `STAGING_AWS_S3_ENDPOINT_URL`, `STAGING_AWS_ACCESS_KEY_ID`, `STAGING_AWS_SECRET_ACCESS_KEY`, `STAGING_AWS_BUCKET`

**Production секреты (аналогично с префиксом `PROD_`):**
- `PROD_HOST`, `PROD_USER`, `PROD_SSH_KEY`
- `PROD_DB_HOST`, `PROD_DB_PORT`, `PROD_DB_NAME`, `PROD_DB_USER`, `PROD_DB_PASSWORD`
- И т.д.

**Mobile секреты:**
- `FIREBASE_APP_ID_ANDROID` - Firebase App ID для Android
- `FIREBASE_SERVICE_ACCOUNT` - JSON сервисного аккаунта Firebase
- `IOS_CERTIFICATE_BASE64` - iOS сертификат (base64)
- `IOS_CERTIFICATE_PASSWORD` - Пароль для iOS сертификата
- `IOS_PROVISIONING_PROFILE_BASE64` - Provisioning profile (base64)

**Frontend секреты:**
- `VERCEL_TOKEN` - Vercel API token
- `VERCEL_ORG_ID` - Vercel Organization ID
- `VERCEL_PROJECT_ID` - Vercel Project ID
- `NEXT_PUBLIC_API_URL_STAGING` - URL staging API

#### Ротация секретов

GitHub Secrets можно ротировать вручную через веб-интерфейс или через GitHub CLI:

```bash
# Установка секрета
gh secret set SECRET_NAME --body "secret-value"

# Просмотр списка секретов
gh secret list

# Удаление секрета
gh secret delete SECRET_NAME
```

### 2. SOPS (Mozilla SOPS) для локального хранения

SOPS позволяет хранить зашифрованные файлы секретов в репозитории.

#### Установка SOPS

**macOS:**
```bash
brew install sops
```

**Linux:**
```bash
wget https://github.com/mozilla/sops/releases/download/v3.8.0/sops-v3.8.0.linux
chmod +x sops-v3.8.0.linux
sudo mv sops-v3.8.0.linux /usr/local/bin/sops
```

**Windows:**
```powershell
choco install sops
```

#### Настройка PGP ключей

1. Создайте PGP ключ (если нет):
```bash
gpg --full-generate-key
```

2. Экспортируйте публичный ключ:
```bash
gpg --export --armor YOUR_EMAIL > public-key.asc
```

3. Добавьте fingerprint в `.sops.yaml`

#### Использование SOPS

1. Скопируйте пример файла секретов:
```bash
cp staging/secrets.yaml.example staging/secrets.yaml
```

2. Заполните реальными значениями

3. Зашифруйте файл:
```bash
sops -e staging/secrets.yaml > staging/secrets.enc.yaml
```

4. Удалите незашифрованный файл:
```bash
rm staging/secrets.yaml
```

5. Для расшифровки:
```bash
sops -d staging/secrets.enc.yaml
```

6. Для редактирования:
```bash
sops staging/secrets.enc.yaml
```

#### Интеграция с Terraform

Можно использовать SOPS для расшифровки секретов в Terraform:

```hcl
data "sops_file" "secrets" {
  source_file = "secrets.enc.yaml"
}

locals {
  secrets = yamldecode(data.sops_file.secrets.raw)
}
```

### 3. HashiCorp Vault (опционально, для enterprise)

Для production окружений можно использовать HashiCorp Vault:

1. Установите Vault
2. Настройте backend (consul, etcd, etc.)
3. Создайте секреты через Vault CLI или UI
4. Используйте Vault provider в Terraform или Vault Agent для автоматической ротации

## Автоматическая ротация секретов

### Скрипт ротации для GitHub Secrets

Создайте GitHub Action для автоматической ротации:

```yaml
# .github/workflows/rotate-secrets.yml
name: Rotate Secrets
on:
  schedule:
    - cron: '0 0 1 * *'  # Каждый месяц
  workflow_dispatch:
```

### Ротация через SOPS

Используйте скрипт для автоматической ротации ключей:

```bash
#!/bin/bash
# rotate-secrets.sh
# Генерирует новые секреты и обновляет зашифрованные файлы

# Генерация нового Django SECRET_KEY
NEW_SECRET_KEY=$(openssl rand -hex 32)

# Обновление через SOPS
sops --set "[\"django\"][\"secret_key\"] \"$NEW_SECRET_KEY\"" staging/secrets.enc.yaml
```

## Безопасность

⚠️ **ВАЖНЫЕ ПРАВИЛА:**

1. **Никогда не коммитьте незашифрованные секреты** в git
2. Используйте `.gitignore` для исключения файлов с секретами
3. Ограничьте доступ к секретам только необходимым людям
4. Регулярно ротируйте секреты (рекомендуется каждые 90 дней)
5. Используйте разные секреты для staging и production
6. Аудит доступа к секретам (логирование всех операций)
7. Используйте минимальные права доступа (principle of least privilege)

## Проверка безопасности

Проверьте, что секреты не попали в git:

```bash
# Поиск потенциальных секретов в истории
git log --all --full-history --source -- "*secrets*" "*password*" "*key*"

# Использование git-secrets или truffleHog
git-secrets --scan-history
```

## Миграция секретов

При переходе между методами управления секретами:

1. Экспортируйте секреты из старого хранилища
2. Импортируйте в новое хранилище
3. Обновите все сервисы для использования нового хранилища
4. Удалите старые секреты после подтверждения работы

