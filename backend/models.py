# ==========================================
# 📄 File: backend/models.py
# 🌟 系统通知流数据模型 (轻量·高效·线程安全版)
# ==========================================
from typing import Dict, Any, Optional
from PySide6.QtCore import QAbstractListModel, QModelIndex, Qt, Signal, Property, Slot


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

    def __init__(self, parent: Optional[Any] = None):
        super().__init__(parent)
        self._items = []
        self._unread_count = 0
        self._latest_avatar = ""

    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:
        if parent.isValid():
            return 0
        return len(self._items)

    def data(self, index: QModelIndex, role: int = Qt.ItemDataRole.DisplayRole) -> Any:
        if not index.isValid() or not (0 <= index.row() < len(self._items)):
            return None

        item = self._items[index.row()]
        if role == self.IdRole:
            return item.get("id")
        elif role == self.IconRole:
            return item.get("icon", "💬")
        elif role == self.TitleRole:
            return item.get("title", "")
        elif role == self.ContentRole:
            return item.get("content", "")
        elif role == self.AvatarRole:
            return item.get("avatar", "")
        elif role == self.TimeRole:
            return item.get("time", "")
        elif role == self.ReadRole:
            return item.get("read", False)
        return None

    def roleNames(self) -> Dict[int, bytes]:
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
    def count(self) -> int:
        return len(self._items)

    @Property(int, notify=unreadCountChanged)
    def unreadCount(self) -> int:
        return self._unread_count

    @Property(str, notify=unreadCountChanged)
    def latestAvatar(self) -> str:
        return self._latest_avatar

    @Slot(int, result="QVariantMap")
    def get(self, row: int) -> Dict[str, Any]:
        if 0 <= row < len(self._items):
            return dict(self._items[row])
        return {}

    def add_notification(self, item_dict: dict):
        # 3 秒内同标题、同正文的重复消息静默去重
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

        # 保留最近 20 条消息，超出安全剔除
        if len(self._items) > 20:
            last_idx = len(self._items) - 1
            self.beginRemoveRows(QModelIndex(), last_idx, last_idx)
            self._items.pop()
            self.endRemoveRows()

        self.unreadCountChanged.emit(self._unread_count)
        self.countChanged.emit(len(self._items))

    @Slot()
    def markAllRead(self):
        if not self._items or self._unread_count == 0:
            return
        for item in self._items:
            item["read"] = True
        self._unread_count = 0
        top_left = self.index(0, 0)
        bottom_right = self.index(len(self._items) - 1, 0)
        self.dataChanged.emit(top_left, bottom_right, [self.ReadRole])
        self.unreadCountChanged.emit(0)

    @Slot()
    def clearAll(self):
        if not self._items:
            return
        self.beginResetModel()
        self._items.clear()
        self._unread_count = 0
        self._latest_avatar = ""
        self.endResetModel()
        self.unreadCountChanged.emit(0)
        self.countChanged.emit(0)