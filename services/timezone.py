from PySide6.QtCore import QDateTime, QTimeZone, QByteArray


def get_world_time(tz_name: str, is_24h: bool = True) -> dict:
    try:
        tz = QTimeZone(QByteArray(tz_name.encode("utf-8"))) if tz_name else QTimeZone.systemTimeZone()
        if not tz.isValid():
            tz = QTimeZone.systemTimeZone()
        now_utc = QDateTime.currentDateTimeUtc()
        target_dt = now_utc.toTimeZone(tz)
        local_dt = QDateTime.currentDateTime()
        local_tz = QTimeZone.systemTimeZone()
        h = target_dt.time().hour()
        m = target_dt.time().minute()
        time_str = f"{h:02d}:{m:02d}" if is_24h else f"{h%12 or 12:02d}:{m:02d}{' PM' if h>=12 else ' AM'}"
        diff_hours = round((tz.offsetFromUtc(now_utc) - local_tz.offsetFromUtc(now_utc)) / 3600.0, 1)
        day_diff = local_dt.date().daysTo(target_dt.date())
        day_str = "今天" if day_diff == 0 else ("明天" if day_diff > 0 else "昨天")
        diff_str = "与本地同时" if diff_hours == 0 else (f"快 {diff_hours:g}h · {day_str}" if diff_hours > 0 else f"慢 {abs(diff_hours):g}h · {day_str}")
        return {"time": time_str, "diff": diff_str, "isDay": 6 <= h < 18, "isWorking": 9 <= h < 18}
    except Exception:
        return {"time": "--:--", "diff": "", "isDay": True, "isWorking": False}


def get_tz_offset_str(tz_name: str) -> str:
    try:
        tz = QTimeZone(QByteArray(tz_name.encode("utf-8"))) if tz_name else None
        if not tz or not tz.isValid():
            return "UTC"
        off_sec = tz.offsetFromUtc(QDateTime.currentDateTimeUtc())
        off_h = off_sec // 3600
        off_m = abs((off_sec % 3600) // 60)
        sign = "+" if off_sec >= 0 else ""
        return f"UTC{sign}{off_h}" if off_m == 0 else f"UTC{sign}{off_h}:{off_m:02d}"
    except Exception:
        return "UTC"