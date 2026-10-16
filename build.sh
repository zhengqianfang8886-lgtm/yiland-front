#!/bin/bash

# 1. 尝试激活虚拟环境 (失败则警告并继续使用当前 Python)
if [ -f ".venv/bin/activate" ]; then
    source .venv/bin/activate
    echo "✅ 已激活虚拟环境 .venv"
else
    echo "⚠️ 未找到 .venv/bin/activate，将使用当前环境打包"
fi

# 2. 清理历史构建缓存，防止幽灵 Bug
echo "🧹 正在清理旧的构建缓存..."
rm -rf build/ dist/ *.spec

# 3. 核心打包命令
echo "📦 开始打包 yisland-front (OneDir 模式)..."

pyinstaller --noconfirm --onedir --windowed --name "yisland-front" \
    --collect-all "PySide6.QtSql" \
    --add-data "ui:ui" \
    --add-data "assets:assets" \
    main.py

echo "================================================"
echo "✨ 打包成功！"
echo "🚀 启动程序请运行: ./dist/yisland-front/yisland-front"
echo "================================================"
