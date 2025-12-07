@echo off
echo === Исправление проблем с Gradle кэшем ===
echo.

echo [1/5] Завершение процессов Gradle...
taskkill /F /IM java.exe /FI "WINDOWTITLE eq *gradle*" 2>nul
echo.

echo [2/5] Очистка кэша Gradle...
if exist "%USERPROFILE%\.gradle\caches\8.9\transforms" (
    rmdir /S /Q "%USERPROFILE%\.gradle\caches\8.9\transforms" 2>nul
    echo Директория transforms очищена
)
if exist "%USERPROFILE%\.gradle\caches\8.9\tmp" (
    rmdir /S /Q "%USERPROFILE%\.gradle\caches\8.9\tmp" 2>nul
    echo Временные файлы очищены
)
echo.

echo [3/5] Очистка локального кэша проекта...
if exist "android\.gradle" (
    rmdir /S /Q "android\.gradle" 2>nul
    echo Локальный кэш проекта очищен
)
if exist "android\build" (
    rmdir /S /Q "android\build" 2>nul
    echo Директория build очищена
)
echo.

echo [4/5] Очистка кэша Flutter...
call flutter clean
echo.

echo [5/5] Готово!
echo.
echo Теперь попробуйте выполнить сборку:
echo   flutter build appbundle --release
echo.
pause

