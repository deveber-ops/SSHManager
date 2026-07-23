#!/bin/bash
# SSH Manager — снятие карантина Gatekeeper
# Дважды кликните этот файл после установки SSH Manager.app в /Applications

APP="/Applications/SSHManager.app"

if [ ! -d "$APP" ]; then
    echo "ОШИБКА: SSHManager.app не найден в /Applications"
    echo "Сначала перетащите SSHManager.app в папку Applications"
    read -p "Нажмите Enter для выхода..."
    exit 1
fi

echo "Снимаю карантин с $APP..."
xattr -dr com.apple.quarantine "$APP" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✓ Готово! Приложение можно запускать."
else
    echo "⚠ Не удалось снять карантин. Попробуйте:"
    echo "  xattr -dr com.apple.quarantine '$APP'"
fi

read -p "Нажмите Enter для выхода..."
