#!/bin/bash

source .venv/bin/activate;
pyinstaller --noconfirm --onedir --windowed --name "yisland-front" \
    --collect-all "PySide6.QtSql" \
    --add-data "*.qml:." \
    --add-data "calendar:calendar" \
    --add-data "capsule:capsule" \
    --add-data "compact:compact" \
    --add-data "control:control" \
    --add-data "expanded:expanded" \
    --add-data "power:power" \
    --add-data "process:process" \
    --add-data "settings:settings" \
    --add-data "timer:timer" \
    --add-data "liquid_glass.frag.qsb:." \
    --add-data "world_cities.json:." \
    main.py
