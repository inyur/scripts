🟢 1. Объявление и использование

name="Igor"
echo "Hello, $name"
echo "Hello, ${name}"  # фигурные скобки нужны, если рядом символы

🟡 2. Чтение переменных окружения

echo "$HOME"
echo "$PATH"

Задать временно:
MYVAR="123" command   # только для этой команды

Задать глобально:
export MYVAR="123"

🔵 3. Проверка наличия переменной

if [ -z "$VAR" ]; then
echo "VAR is empty or not set"
fi

if [ -n "$VAR" ]; then
echo "VAR is set and not empty"
fi

🟣 4. Значения по умолчанию

echo "${VAR:-default}"     # использовать "default", если VAR пуст
echo "${VAR:=default}"     # установить "default", если VAR пуст
echo "${VAR:+nonempty}"    # использовать "nonempty", если VAR не пуст

🟠 5. Обрезка и замена

filename="src/index.js"

echo "${filename%.*}"   # src/index   (удалить суффикс после первой точки)
echo "${filename##*/}"  # index.js    (удалить путь, оставить имя)
echo "${filename%%/*}"  # src         (удалить всё после первого /)

path="/usr/local/bin"
echo "${path//\//_}"    # _usr_local_bin  (заменить все / на _)

🔴 6. Арифметика

a=5
b=3
sum=$((a + b))
echo "$sum"  # 8

⚫ 7. Проверка и вывод переменных

set | grep MYVAR        # все переменные (включая shell)
env | grep MYVAR        # только окружение
declare -p VAR           # отладочный вывод значения

⚪ 8. Автоматическое завершение при ошибках

set -euo pipefail
# -e  → выход при ошибке
# -u  → ошибка при обращении к unset переменной
# -o pipefail → выход, если любая команда в пайпе упала

