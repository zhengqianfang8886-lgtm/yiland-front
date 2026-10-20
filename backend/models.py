# ==========================================
# 📄 File: backend/models.py
# 🌟 统一数据模型套件 (新增 SNI 托盘模型与内存图像通道)
# ==========================================
import hashlib
from PySide6.QtCore import QAbstractListModel, QModelIndex, Qt, Signal, Property, Slot, QSize
from PySide6.QtGui import QImage, QIcon
from PySide6.QtQuick import QQuickImageProvider


class TrayImageProvider(QQuickImageProvider):
    """内存级零落盘托盘图像提供者: image://tray/{item_id}/{type}?v={revision}"""

    def __init__(self):
        super().__init__(QQuickImageProvider.ImageType.Image)
        self._pixmap_cache = {}

    def update_pixmap(self, key: str, qimage: QImage):
        self._pixmap_cache[key] = qimage

    def remove_item(self, key_prefix: str):
        keys_to_del = [k for k in self._pixmap_cache if k.startswith(key_prefix)]
        for k in keys_to_del:
            self._pixmap_cache.pop(k, None)

    def requestImage(self, id_str: str, size: QSize, requestedSize: QSize) -> QImage:
        # id_str 形式: "{item_id}/{icon_type}"
        clean_id = id_str.split("?")[0]
        if clean_id in self._pixmap_cache:
            img = self._pixmap_cache[clean_id]
            if requestedSize.isValid() and (requestedSize.width() > 0 and requestedSize.height() > 0):
                return img.scaled(requestedSize, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
            return img

        # 降级尝试：从系统主题加载图标
        parts = clean_id.split("/")
        icon_name = parts[-1] if parts else clean_id
        if QIcon.hasThemeIcon(icon_name):
            target_w = requestedSize.width() if requestedSize.isValid() and requestedSize.width() > 0 else 32
            target_h = requestedSize.height() if requestedSize.isValid() and requestedSize.height() > 0 else 32
            return QIcon.fromTheme(icon_name).pixmap(target_w, target_h).toImage()

        # 空白透明保底
        empty = QImage(32, 32, QImage.Format.Format_ARGB32_Premultiplied)
        empty.fill(Qt.GlobalColor.transparent)
        return empty


class TrayItemListModel(QAbstractListModel):
    IdRole = Qt.ItemDataRole.UserRole + 1
    ServiceRole = Qt.ItemDataRole.UserRole + 2
    TitleRole = Qt.ItemDataRole.UserRole + 3
    StatusRole = Qt.ItemDataRole.UserRole + 4
    CategoryRole = Qt.ItemDataRole.UserRole + 5
    IconUrlRole = Qt.ItemDataRole.UserRole + 6
    AttentionIconUrlRole = Qt.ItemDataRole.UserRole + 7
    TooltipTitleRole = Qt.ItemDataRole.UserRole + 8
    TooltipSubRole = Qt.ItemDataRole.UserRole + 9
    HasMenuRole = Qt.ItemDataRole.UserRole + 10
    IsAttentionRole = Qt.ItemDataRole.UserRole + 11

    countChanged = Signal(int)
    attentionCountChanged = Signal(int)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._items = []  # List[Dict[str, Any]]
        self._attention_count = 0

    def rowCount(self, parent=QModelIndex()):
        return len(self._items)

    def data(self, index, role=Qt.ItemDataRole.DisplayRole):
        if not index.isValid() or not (0 <= index.row() < len(self._items)):
            return None
        item = self._items[index.row()]
        if role == self.IdRole: return item.get("id", "")
        elif role == self.ServiceRole: return item.get("service", "")
        elif role == self.TitleRole: return item.get("title", "")
        elif role == self.StatusRole: return item.get("status", "Active")
        elif role == self.CategoryRole: return item.get("category", "ApplicationStatus")
        elif role == self.IconUrlRole: return item.get("icon_url", "")
        elif role == self.AttentionIconUrlRole: return item.get("attention_icon_url", "")
        elif role == self.TooltipTitleRole: return item.get("tooltip_title", "")
        elif role == self.TooltipSubRole: return item.get("tooltip_sub", "")
        elif role == self.HasMenuRole: return item.get("has_menu", False)
        elif role == self.IsAttentionRole: return item.get("status") == "NeedsAttention"
        return None

    def roleNames(self):
        return {
            self.IdRole: b"itemId",
            self.ServiceRole: b"service",
            self.TitleRole: b"title",
            self.StatusRole: b"status",
            self.CategoryRole: b"category",
            self.IconUrlRole: b"iconUrl",
            self.AttentionIconUrlRole: b"attentionIconUrl",
            self.TooltipTitleRole: b"tooltipTitle",
            self.TooltipSubRole: b"tooltipSub",
            self.HasMenuRole: b"hasMenu",
            self.IsAttentionRole: b"isAttention",
        }

    @Property(int, notify=countChanged)
    def count(self):
        return len(self._items)

    @Property(int, notify=attentionCountChanged)
    def attentionCount(self):
        return self._attention_count

    def _recalc_attention(self):
        cnt = sum(1 for x in self._items if x.get("status") == "NeedsAttention")
        if self._attention_count != cnt:
            self._attention_count = cnt
            self.attentionCountChanged.emit(cnt)

    def upsert_item(self, item_dict: dict):
        service = item_dict.get("service")
        if not service:
            return

        for idx, existing in enumerate(self._items):
            if existing.get("service") == service:
                # 存在即更新角色
                changed_roles = []
                for k, role in [
                    ("title", self.TitleRole),
                    ("status", self.StatusRole),
                    ("icon_url", self.IconUrlRole),
                    ("attention_icon_url", self.AttentionIconUrlRole),
                    ("tooltip_title", self.TooltipTitleRole),
                    ("tooltip_sub", self.TooltipSubRole),
                    ("has_menu", self.HasMenuRole),
                ]:
                    if existing.get(k) != item_dict.get(k):
                        existing[k] = item_dict.get(k)
                        changed_roles.append(role)

                if existing.get("status") != item_dict.get("status"):
                    changed_roles.append(self.IsAttentionRole)

                if changed_roles:
                    m_idx = self.index(idx, 0)
                    self.dataChanged.emit(m_idx, m_idx, changed_roles)
                self._recalc_attention()
                return

        # 不存在则新增插入首行
        self.beginInsertRows(QModelIndex(), len(self._items), len(self._items))
        self._items.append(dict(item_dict))
        self.endInsertRows()
        self.countChanged.emit(len(self._items))
        self._recalc_attention()

    def remove_by_service(self, service: str):
        for idx, item in enumerate(self._items):
            if item.get("service") == service:
                self.beginRemoveRows(QModelIndex(), idx, idx)
                self._items.pop(idx)
                self.endRemoveRows()
                self.countChanged.emit(len(self._items))
                self._recalc_attention()
                return

    @Slot(int, result="QVariantMap")
    def get(self, row: int):
        if 0 <= row < len(self._items):
            return dict(self._items[row])
        return {}


class NotificationListModel(QAbstractListModel):
    IdRole = Qt.ItemDataRole.UserRole + 1
    IconRole = Qt.ItemDataRole.UserRole + 2
    TitleRole = Qt.ItemDataRole.UserRole + 3
    ContentRole = Qt.ItemDataRole.UserRole + 4
    AvatarRole = Qt.ItemDataRole.UserRole + 5
    TimeRole = Qt.ItemDataRole.UserRole + 6
    ReadRole = Qt.ItemDataRole.UserRole + 7

    unreadCountChanged = Signal(int)
    countChanged = Signal(int)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._items = []
        self._unread_count = 0
        self._latest_avatar = ""

    def rowCount(self, parent=QModelIndex()):
        return len(self._items)

    def data(self, index, role=Qt.ItemDataRole.DisplayRole):
        if not index.isValid() or not (0 <= index.row() < len(self._items)):
            return None
        item = self._items[index.row()]
        if role == self.IdRole: return item.get("id")
        elif role == self.IconRole: return item.get("icon", "💬")
        elif role == self.TitleRole: return item.get("title", "")
        elif role == self.ContentRole: return item.get("content", "")
        elif role == self.AvatarRole: return item.get("avatar", "")
        elif role == self.TimeRole: return item.get("time", "")
        elif role == self.ReadRole: return item.get("read", False)
        return None

    def roleNames(self):
        return {
            self.IdRole: b"id",
            self.IconRole: b"icon",
            self.TitleRole: b"title",
            self.ContentRole: b"content",
            self.AvatarRole: b"avatar",
            self.TimeRole: b"time",
            self.ReadRole: b"read",
        }

    @Property(int, notify=countChanged)
    def count(self): return len(self._items)

    @Property(int, notify=unreadCountChanged)
    def unreadCount(self): return self._unread_count

    @Property(str, notify=unreadCountChanged)
    def latestAvatar(self): return self._latest_avatar

    @Slot(int, result="QVariantMap")
    def get(self, row: int):
        if 0 <= row < len(self._items): return dict(self._items[row])
        return {}

    def add_notification(self, item_dict: dict):
        if self._items:
            top = self._items[0]
            if top.get("title") == item_dict.get("title") and top.get("content") == item_dict.get("content"):
                if (item_dict.get("id", 0) - top.get("id", 0)) < 3000:
                    return

        self.beginInsertRows(QModelIndex(), 0, 0)
        self._items.insert(0, item_dict)
        self.endInsertRows()

        self._unread_count += 1
        if item_dict.get("avatar"):
            self._latest_avatar = item_dict["avatar"]

        if len(self._items) > 15:
            last_idx = len(self._items) - 1
            self.beginRemoveRows(QModelIndex(), last_idx, last_idx)
            self._items.pop()
            self.endRemoveRows()

        self.unreadCountChanged.emit(self._unread_count)
        self.countChanged.emit(len(self._items))

    @Slot()
    def markAllRead(self):
        if not self._items or self._unread_count == 0: return
        for item in self._items: item["read"] = True
        self._unread_count = 0
        top_left = self.index(0, 0)
        bottom_right = self.index(len(self._items) - 1, 0)
        self.dataChanged.emit(top_left, bottom_right, [self.ReadRole])
        self.unreadCountChanged.emit(0)

    @Slot()
    def clearAll(self):
        if not self._items: return
        self.beginResetModel()
        self._items.clear()
        self._unread_count = 0
        self._latest_avatar = ""
        self.endResetModel()
        self.unreadCountChanged.emit(0)
        self.countChanged.emit(0)


class BluetoothListModel(QAbstractListModel):
    NameRole = Qt.ItemDataRole.UserRole + 1
    MacRole = Qt.ItemDataRole.UserRole + 2
    ConnectedRole = Qt.ItemDataRole.UserRole + 3
    BatteryRole = Qt.ItemDataRole.UserRole + 4
    IconRole = Qt.ItemDataRole.UserRole + 5

    devicesChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._devices = []
        self._connected_count = 0
        self._primary_device = {}

    def rowCount(self, parent=QModelIndex()): return len(self._devices)

    def data(self, index, role=Qt.ItemDataRole.DisplayRole):
        if not index.isValid() or not (0 <= index.row() < len(self._devices)): return None
        dev = self._devices[index.row()]
        if role == self.NameRole: return dev.get("name", "未知设备")
        elif role == self.MacRole: return dev.get("mac", "")
        elif role == self.ConnectedRole: return dev.get("connected", False)
        elif role == self.BatteryRole: return dev.get("battery")
        elif role == self.IconRole: return dev.get("icon", "")
        return None

    def roleNames(self):
        return {
            self.NameRole: b"name",
            self.MacRole: b"mac",
            self.ConnectedRole: b"connected",
            self.BatteryRole: b"battery",
            self.IconRole: b"icon",
        }

    @Property(int, notify=devicesChanged)
    def connectedCount(self): return self._connected_count

    @Property("QVariantMap", notify=devicesChanged)
    def primaryDevice(self): return self._primary_device

    @Slot(int, result="QVariantMap")
    def get(self, row: int):
        if 0 <= row < len(self._devices): return dict(self._devices[row])
        return {}

    def _recalc_summary(self):
        cnt = 0
        first_conn = None
        for d in self._devices:
            if d.get("connected", False):
                cnt += 1
                if first_conn is None: first_conn = d
        self._connected_count = cnt
        self._primary_device = dict(first_conn) if first_conn else {}
        self.devicesChanged.emit()