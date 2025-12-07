# Исправление ошибок Gradle на Windows

## Проблема
При сборке Android App Bundle возникает ошибка:
```
Could not move temporary workspace (...) to immutable location
```

Это классическая проблема Gradle на Windows, связанная с блокировкой файлов в кэше.

## ⚡ БЫСТРОЕ РЕШЕНИЕ (Выполните по порядку)

### Шаг 1: Завершите все процессы Java/Gradle
```powershell
Get-Process java -ErrorAction SilentlyContinue | Stop-Process -Force
```

### Шаг 2: Удалите проблемный кэш
```powershell
Remove-Item -Path "$env:USERPROFILE\.gradle\caches\8.9\transforms" -Recurse -Force -ErrorAction SilentlyContinue
```

### Шаг 3: Очистите проект
```powershell
cd C:\ringo-uchet\mobile
flutter clean
Remove-Item -Path ".\android\.gradle" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".\android\build" -Recurse -Force -ErrorAction SilentlyContinue
```

### Шаг 4: Соберите проект
```powershell
flutter build appbundle --release
```

## Решение 1: Автоматическая очистка

### Вариант A: Batch файл (рекомендуется, не требует изменения политики)
```cmd
cd mobile
scripts\fix-gradle-cache.bat
```

### Вариант B: PowerShell с обходом политики
```powershell
cd mobile
powershell -ExecutionPolicy Bypass -File .\scripts\fix-gradle-cache-manual.ps1
```

### Вариант C: Временное изменение политики
```powershell
# Временно разрешить выполнение скриптов для текущей сессии
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process

# Выполнить скрипт
cd mobile
.\scripts\fix-gradle-cache.ps1
```

## Решение 2: Ручная очистка

### Шаг 1: Завершите все процессы Gradle
```powershell
# Найти и завершить процессы Java, связанные с Gradle
Get-Process java -ErrorAction SilentlyContinue | Stop-Process -Force
```

### Шаг 2: Очистите кэш Gradle
```powershell
# Удалите проблемную директорию transforms
Remove-Item -Path "$env:USERPROFILE\.gradle\caches\8.9\transforms" -Recurse -Force -ErrorAction SilentlyContinue

# Очистите временные файлы
Remove-Item -Path "$env:USERPROFILE\.gradle\caches\8.9\tmp" -Recurse -Force -ErrorAction SilentlyContinue
```

### Шаг 3: Очистите локальный кэш проекта
```powershell
cd mobile\android
Remove-Item -Path ".gradle" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue
cd ..\..
```

### Шаг 4: Очистите кэш Flutter
```powershell
flutter clean
```

## Решение 3: Настройка антивируса (КРИТИЧЕСКИ ВАЖНО!)

Добавьте следующие папки в исключения антивируса:
- `C:\Users\<ВашеИмя>\.gradle`
- `C:\Users\<ВашеИмя>\.android`
- Путь к вашему проекту: `C:\ringo-uchet\mobile`

**Это часто является основной причиной проблемы!**

## Решение 4: Использование Gradle без Daemon

Если проблема сохраняется, попробуйте отключить daemon:
```powershell
cd mobile\android
.\gradlew --stop
.\gradlew --no-daemon clean
```

## Решение 5: Полная переустановка кэша

Если ничего не помогает:

```powershell
# 1. Завершите все процессы
Get-Process java | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

# 2. Удалите весь кэш Gradle
Remove-Item -Path "$env:USERPROFILE\.gradle\caches" -Recurse -Force

# 3. Очистите проект
cd C:\ringo-uchet\mobile
flutter clean
cd android
.\gradlew clean
cd ..\..

# 4. Попробуйте собрать снова
flutter build appbundle --release
```

## Решение 6: Альтернативный подход - использование WSL

Если проблема критична, можно использовать Windows Subsystem for Linux:
```bash
# В WSL
cd /mnt/c/ringo-uchet/mobile
flutter build appbundle --release
```

## Дополнительные настройки

Убедитесь, что в `mobile/android/gradle.properties` есть следующие настройки (уже добавлены):

```properties
# Критически важные настройки для исправления проблемы с перемещением файлов на Windows
org.gradle.workers.max=1
org.gradle.parallel.threads=1
org.gradle.caching=false
org.gradle.daemon=false
org.gradle.vfs.watch=false
```

**Примечание:** Эти настройки замедляют сборку, но решают проблему с блокировкой файлов.

## Если проблема сохраняется

1. **Проверьте права доступа**: Убедитесь, что у вас есть полные права на папку `.gradle`
2. **Закройте IDE**: Закройте все IDE (Android Studio, VS Code, IntelliJ) перед сборкой
3. **Запустите от администратора**: Запустите PowerShell от имени администратора
4. **Проверьте диск**: Убедитесь, что на диске достаточно места
5. **Обновите Gradle**: Проверьте, что используется актуальная версия Gradle
6. **Проверьте антивирус**: Это самая частая причина - добавьте исключения!

## Проверка версий

```powershell
# Проверка версии Flutter
flutter --version

# Проверка версии Gradle
cd mobile\android
.\gradlew --version
```

## Диагностика

Если проблема не решается, выполните:

```powershell
# Проверьте, какие процессы блокируют файлы
Get-Process | Where-Object {$_.Path -like "*gradle*" -or $_.Path -like "*java*"}

# Проверьте права доступа
icacls "$env:USERPROFILE\.gradle"

# Проверьте, не заблокированы ли файлы
Get-ChildItem "$env:USERPROFILE\.gradle\caches\8.9\transforms" -ErrorAction SilentlyContinue | Select-Object Name, IsReadOnly
```

## Контакты для помощи

Если проблема не решается, соберите следующую информацию:
- Версия Flutter: `flutter --version`
- Версия Gradle: `.\gradlew --version`
- Полный лог ошибки
- Информация об антивирусе
- Результат `Get-Process java`
