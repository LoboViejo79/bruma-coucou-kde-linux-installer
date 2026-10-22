#pragma once

#include "sysmon.h"

#include <QAbstractListModel>
#include <QSet>

// Nombre e icono "bonitos" de un programa, sacados de sus archivos .desktop
struct AppEntry {
    QString name, icon, comment, id;
};

class AppIndex
{
public:
    AppIndex();
    const AppEntry *forProcess(const ProcInfo &p) const;
    const AppEntry *forId(const QString &desktopId) const;

private:
    QHash<QString, AppEntry> m_byExec, m_byId;
};

// Filas de las pestañas Procesos (agrupadas como Windows) y Detalles (lista plana)
class ProcessModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(SysMon *monitor READ monitor WRITE setMonitor NOTIFY monitorChanged)
    Q_PROPERTY(bool details READ details WRITE setDetails NOTIFY monitorChanged)
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged)
    Q_PROPERTY(int sortColumn READ sortColumn NOTIFY sortChanged)
    Q_PROPERTY(bool sortDescending READ sortDescending NOTIFY sortChanged)
    Q_PROPERTY(int appCount READ appCount NOTIFY countsChanged)
    Q_PROPERTY(QVariantList appHistory READ appHistory NOTIFY countsChanged)

public:
    enum Columns { Name, Status, Cpu, Memory, Disk, Network, Pid, User, Description, Gpu, GpuEngine };
    Q_ENUM(Columns)
    enum Roles {
        KindRole = Qt::UserRole + 1, KeyRole, NameRole, IconRole, PidRole, CountRole, ExpandedRole, StatusRole,
        EfficiencyRole, CpuRole, MemRole, DiskRole, NetRole, UserRole, DescriptionRole, DepthRole, WindowRole, GpuRole, GpuEngineRole
    };

    explicit ProcessModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    SysMon *monitor() const { return m_mon; }
    void setMonitor(SysMon *m);
    bool details() const { return m_details; }
    void setDetails(bool d);
    QString filter() const { return m_filter; }
    void setFilter(const QString &f);
    int sortColumn() const { return m_sortColumn; }
    bool sortDescending() const { return m_sortDesc; }
    int appCount() const { return m_appCount; }
    QVariantList appHistory() const { return m_appHistory; }

    // Ventanas abiertas (desde TasksModel): [{pid, appId, name, window}]
    Q_INVOKABLE void setApps(const QVariantList &apps);
    Q_INVOKABLE void sortBy(int column);
    Q_INVOKABLE void toggle(const QString &key);
    Q_INVOKABLE void endTask(const QString &key);
    Q_INVOKABLE void endTree(int pid);
    Q_INVOKABLE void setEfficiency(const QString &key, bool on);
    Q_INVOKABLE void setPriority(int pid, int nice);
    Q_INVOKABLE void openLocation(int pid);
    Q_INVOKABLE void searchOnline(const QString &name);
    Q_INVOKABLE bool runTask(const QString &command, bool admin);
    Q_INVOKABLE QVariantMap info(int pid) const;

Q_SIGNALS:
    void monitorChanged();
    void filterChanged();
    void sortChanged();
    void countsChanged();

private:
    struct Row {
        int kind = 0;   // 0 cabecera de sección, 1 grupo/proceso, 2 proceso dentro de un grupo
        QString key, name, icon, status, user, description, gpuEngine;
        int pid = 0, count = 0, depth = 0, window = -1;
        bool expanded = false, efficiency = false;
        double cpu = 0, mem = 0, disk = 0, net = 0, gpu = 0;
        QList<int> pids;
    };

    void rebuild();
    void buildGrouped(QVector<Row> &rows);
    void buildDetails(QVector<Row> &rows);
    QString processName(const ProcInfo &p) const;
    QString processIcon(const ProcInfo &p) const;
    QList<int> pidsFor(const QString &key) const;
    void signalPids(const QList<int> &pids, int sig);
    bool lessThan(const Row &a, const Row &b) const;
    bool matches(const Row &r) const;

    SysMon *m_mon = nullptr;
    AppIndex m_index;
    QVector<Row> m_rows;
    QHash<int, QVariantMap> m_apps;   // pid -> ventana
    QSet<QString> m_expanded;
    QString m_filter;
    bool m_details = false;
    int m_sortColumn = Name;
    bool m_sortDesc = false;
    int m_appCount = 0;
    QVariantList m_appHistory;
    QHash<QString, double> m_netAccum;   // red acumulada por app desde que se abrió el administrador
};
