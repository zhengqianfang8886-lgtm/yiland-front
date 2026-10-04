"""
Alcove Island - 专用高性能 QAbstractListModel 实现
为通知列表与蓝牙设备列表提供行级增量刷新 (Fine-grained Diffing)
"""
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

    @Property(int, notify=unreadCountChanged)
    def unreadCount(self):
        return self._unread_count

    @Property(str, notify=unreadCountChanged)
    def latestAvatar(self):
        return self._latest_avatar

    def add_notification(self, item_dict: dict):
        """向头部插入单条新通知，超出上限自动裁切尾部"""
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

        # 超出最大数量（15条）从末尾移除
        if len(self._items) > 15:
            last_idx = len(self._items) - 1
            self.beginRemoveRows(QModelIndex(), last_idx, last_idx)
            self._items.pop()
            self.endRemoveRows()

        self.unreadCountChanged.emit(self._unread_count)

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


class BluetoothListModel(QAbstractListModel):
    NameRole = Qt.ItemDataRole.UserRole + 1
    MacRole = Qt.ItemDataRole.UserRole + 2
    ConnectedRole = Qt.ItemDataRole.UserRole + 3
    BatteryRole = Qt.ItemDataRole.UserRole + 4
    IconRole = Qt.ItemDataRole.UserRole + 5

    def __init__(self, parent=None):
        super().__init__(parent)
        self._devices = []

    def rowCount(self, parent=QModelIndex()):
        return len(self._devices)

    def data(self, index, role=Qt.ItemDataRole.DisplayRole):
        if not index.isValid() or not (0 <= index.row() < len(self._devices)):
            return None
        dev = self._devices[index.row()]
        if role == self.NameRole:
            return dev.get("name", "未知设备")
        elif role == self.MacRole:
            return dev.get("mac", "")
        elif role == self.ConnectedRole:
            return dev.get("connected", False)
        elif role == self.BatteryRole:
            return dev.get("battery")
        elif role == self.IconRole:
            return dev.get("icon", "")
        return None

    def roleNames(self):
        return {
            self.NameRole: b"name",
            self.MacRole: b"mac",
            self.ConnectedRole: b"connected",
            self.BatteryRole: b"battery",
            self.IconRole: b"icon",
        }

    def sync_devices(self, new_devices: list):
        """精准差量更新（Diff）：有增删走增删，仅属性变更只抛 dataChanged，避免 QML 重新创建所有 Delegate"""
        new_mac_map = {d.get("mac"): d for d in new_devices if d.get("mac")}
        curr_mac_map = {d.get("mac"): i for i, d in enumerate(self._devices) if d.get("mac")}

        # 1. 查找被删除的设备
        for i in range(len(self._devices) - 1, -1, -1):
            mac = self._devices[i].get("mac")
            if mac not in new_mac_map:
                self.beginRemoveRows(QModelIndex(), i, i)
                self._devices.pop(i)
                self.endRemoveRows()

        # 重新映射
        curr_mac_map = {d.get("mac"): i for i, d in enumerate(self._devices) if d.get("mac")}

        # 2. 检查更新已有项
        for mac, new_data in new_mac_map.items():
            if mac in curr_mac_map:
                row = curr_mac_map[mac]
                old_data = self._devices[row]
                changed_roles = []
                for key, role in [
                    ("name", self.NameRole),
                    ("connected", self.ConnectedRole),
                    ("battery", self.BatteryRole),
                    ("icon", self.IconRole),
                ]:
                    if old_data.get(key) != new_data.get(key):
                        changed_roles.append(role)
                if changed_roles:
                    self._devices[row] = dict(new_data)
                    idx = self.index(row, 0)
                    self.dataChanged.emit(idx, idx, changed_roles)

        # 3. 检查新增项
        for mac, new_data in new_mac_map.items():
            if mac not in curr_mac_map:
                insert_row = len(self._devices)
                self.beginInsertRows(QModelIndex(), insert_row, insert_row)
                self._devices.append(dict(new_data))
                self.endInsertRows()
                curr_mac_map[mac] = insert_row

# ==========================================
# 📄 修改 models.py 中的 ProcessListModel
# ==========================================
class ProcessListModel(QAbstractListModel):
    IdRole = Qt.ItemDataRole.UserRole + 1
    NameRole = Qt.ItemDataRole.UserRole + 2
    CwdRole = Qt.ItemDataRole.UserRole + 3
    CmdRole = Qt.ItemDataRole.UserRole + 4
    StatusRole = Qt.ItemDataRole.UserRole + 5
    PidRole = Qt.ItemDataRole.UserRole + 6

    # 🚀 必须定义标准无参通知信号供 Q_PROPERTY 监听
    countChanged = Signal()
    runningCountChanged = Signal()

    def __init__(self, service, parent=None):
        super().__init__(parent)
        self._service = service
        self._service.taskListChanged.connect(self._sync_all)
        self._service.taskStatusChanged.connect(self._sync_status)

    def rowCount(self, parent=QModelIndex()):
        return len(self._service.get_tasks())

    def data(self, index, role=Qt.ItemDataRole.DisplayRole):
        tasks = self._service.get_tasks()
        if not index.isValid() or not (0 <= index.row() < len(tasks)):
            return None
        t = tasks[index.row()]
        if role == self.IdRole: return t.get("id")
        elif role == self.NameRole: return t.get("name")
        elif role == self.CwdRole: return t.get("cwd")
        elif role == self.CmdRole: return t.get("cmd")
        elif role == self.StatusRole: return t.get("status")
        elif role == self.PidRole: return t.get("pid", 0)
        return None

    def roleNames(self):
        return {
            self.IdRole: b"taskId",
            self.NameRole: b"name",
            self.CwdRole: b"cwd",
            self.CmdRole: b"cmd",
            self.StatusRole: b"status",
            self.PidRole: b"pid"
        }

    # 🚀 核心关键 1：暴露带 NOTIFY 信号的 count 属性
    @Property(int, notify=countChanged)
    def count(self):
        return len(self._service.get_tasks())

    # 🚀 核心关键 2：暴露带 NOTIFY 信号的 runningCount 属性
    @Property(int, notify=runningCountChanged)
    def runningCount(self):
        return sum(1 for t in self._service.get_tasks() if t.get("status") == "running")

    def _sync_all(self):
        self.beginResetModel()
        self.endResetModel()
        # 广播数量变化，驱动 QML 界面毫秒级重绘
        self.countChanged.emit()
        self.runningCountChanged.emit()

    def _sync_status(self, task_id, status, pid):
        tasks = self._service.get_tasks()
        for row, t in enumerate(tasks):
            if t["id"] == task_id:
                idx = self.index(row, 0)
                self.dataChanged.emit(idx, idx, [self.StatusRole, self.PidRole])
                break
        # 状态变更驱动运行中计数器毫秒级刷新
        self.runningCountChanged.emit()