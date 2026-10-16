#!/bin/bash

source .venv/bin/activate;
pyinstaller --noconfirm --onedir --windowed --name "yisland-front" \
    --collect-all "PySide6.QtSql" \
    --add-data "*.qml:." \
    --add-data "calendar:calendar" \
    --add-data "capsule:capsule" \
    --add-data "compact:compact" \
    --add-data "expanded:expanded" \
    --add-data "pages:pages" \
    --add-data "settings:settings" \
    --add-data "timer:timer" \
    --add-data "liquid_glass.frag.qsb:." \
    --add-data "world_cities.json:." \
    main.py
