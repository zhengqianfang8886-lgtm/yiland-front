# ==========================================
# 📄 File: services/utils.py
# ==========================================
import socket

# 密码管理器剪贴板防泄密类型
CONCEAL_MIME_TYPES = {
    "application/x-vnd.passwordmanager-conceal",
    "x-kde-passwordManagerHint",
    "application/x-1password-conceal",
    "application/x-keepassxc-conceal",
    "application/x-encpass",
    "text/x-private",
    "application/x-moz-url-priv",
}


def get_local_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"