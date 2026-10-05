// ==========================================
// 📄 File: calendar/HabitStorage.js
// ==========================================
.pragma library

function getDb(LocalStorage) {
    var db = null;
    try {
        db = LocalStorage.openDatabaseSync("AlcoveIslandHabits", "", "Habits Storage", 100000);
    } catch (e1) {
        try {
            db = LocalStorage.openDatabaseSync("AlcoveIslandHabits", "1.0", "Habits Storage", 100000);
        } catch (e2) {
            db = LocalStorage.openDatabaseSync("AlcoveIslandHabits_v2", "", "Habits Storage", 100000);
        }
    }
    if (db) {
        db.transaction(function(tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS habits (id TEXT PRIMARY KEY, name TEXT, icon TEXT, created_at INTEGER)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS habit_logs (habit_id TEXT, date_str TEXT, PRIMARY KEY(habit_id, date_str))");
        });
    }
    return db;
}

function loadHabits(LocalStorage) {
    var db = getDb(LocalStorage);
    var list = [];
    if (!db) return list;
    try {
        db.readTransaction(function(tx) {
            var rs = tx.executeSql("SELECT id, name, icon FROM habits ORDER BY created_at ASC");
            for (var i = 0; i < rs.rows.length; i++) {
                var item = rs.rows.item(i);
                list.push({ id: item.id, name: item.name, icon: item.icon || "📌" });
            }
        });
    } catch(err) {
        console.error("[HabitStorage] 查询事项失败:", err);
    }
    return list;
}

function addHabit(LocalStorage, name, icon) {
    var db = getDb(LocalStorage);
    if (!db) return [];
    var id = "h_" + Date.now();
    try {
        db.transaction(function(tx) {
            tx.executeSql("INSERT INTO habits (id, name, icon, created_at) VALUES (?, ?, ?, ?)", [id, name.trim(), icon || "📌", Date.now()]);
        });
    } catch(err) {
        console.error("[HabitStorage] 插入事项失败:", err);
    }
    return loadHabits(LocalStorage);
}

function deleteHabit(LocalStorage, habitId) {
    var db = getDb(LocalStorage);
    if (!db) return [];
    try {
        db.transaction(function(tx) {
            tx.executeSql("DELETE FROM habits WHERE id = ?", [habitId]);
            tx.executeSql("DELETE FROM habit_logs WHERE habit_id = ?", [habitId]);
        });
    } catch(err) {
        console.error("[HabitStorage] 删除事项失败:", err);
    }
    return loadHabits(LocalStorage);
}

function getMonthRecords(LocalStorage, habitId, year, month) {
    var db = getDb(LocalStorage);
    var result = {};
    if (!db || !habitId) return result;
    var mStr = (month + 1 < 10 ? "0" : "") + (month + 1);
    var prefix = year + "-" + mStr + "-%";
    try {
        db.readTransaction(function(tx) {
            var rs = tx.executeSql("SELECT date_str FROM habit_logs WHERE habit_id = ? AND date_str LIKE ?", [habitId, prefix]);
            for (var i = 0; i < rs.rows.length; i++) {
                result[rs.rows.item(i).date_str] = true;
            }
        });
    } catch(err) {
        console.error("[HabitStorage] 读取月份记录失败:", err);
    }
    return result;
}

function toggleRecord(LocalStorage, habitId, dateStr) {
    var db = getDb(LocalStorage);
    if (!db || !habitId) return false;
    var exists = false;
    try {
        db.readTransaction(function(tx) {
            var rs = tx.executeSql("SELECT date_str FROM habit_logs WHERE habit_id = ? AND date_str = ?", [habitId, dateStr]);
            exists = rs.rows.length > 0;
        });
        db.transaction(function(tx) {
            if (exists) {
                tx.executeSql("DELETE FROM habit_logs WHERE habit_id = ? AND date_str = ?", [habitId, dateStr]);
            } else {
                tx.executeSql("INSERT INTO habit_logs (habit_id, date_str) VALUES (?, ?)", [habitId, dateStr]);
            }
        });
    } catch(err) {
        console.error("[HabitStorage] 打卡状态切换失败:", err);
    }
    return !exists;
}