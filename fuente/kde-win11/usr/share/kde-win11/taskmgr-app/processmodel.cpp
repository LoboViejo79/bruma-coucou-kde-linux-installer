#include "processmodel.h"

#include <QDesktopServices>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QLocale>
#include <QProcess>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>

#include <cerrno>
#include <functional>
#include <csignal>
#include <pwd.h>
#include <sys/resource.h>
#include <unistd.h>

// ---------------- Índice de aplicaciones (.desktop) ----------------

AppIndex::AppIndex()
{
    QStringList dirs = QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation);
    dirs << QDir::homePath() + QStringLiteral("/.local/share/flatpak/exports/share/applications")
         << QStringLiteral("/var/lib/flatpak/exports/share/applications");
    for (const QString &dir : std::as_const(dirs)) {
        QDirIterator it(dir, {QStringLiteral("*.desktop")}, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString file = it.next();
            QSettings d(file, QSettings::IniFormat);
            d.beginGroup(QStringLiteral("Desktop Entry"));
            if (d.value(QStringLiteral("Hidden")).toBool())
                continue;
            AppEntry e;
            const QString lang = QLocale().name().left(2);
            e.name = d.value(QStringLiteral("Name[%1]").arg(lang), d.value(QStringLiteral("Name"))).toString();
            e.comment = d.value(QStringLiteral("Comment[%1]").arg(lang), d.value(QStringLiteral("Comment"))).toString();
            e.icon = d.value(QStringLiteral("Icon")).toString();
            e.id = QFileInfo(file).completeBaseName();
            if (e.name.isEmpty())
                continue;
            const bool shown = !d.value(QStringLiteral("NoDisplay")).toBool();
            if (!m_byId.contains(e.id))
                m_byId.insert(e.id, e);
            // Primera palabra de Exec (sin variables de entorno ni comillas)
            QStringList exec = d.value(QStringLiteral("Exec")).toString().split(QLatin1Char(' '), Qt::SkipEmptyParts);
            while (!exec.isEmpty() && (exec.first() == QLatin1String("env") || exec.first().contains(QLatin1Char('='))))
                exec.removeFirst();
            if (exec.isEmpty())
                continue;
            QString bin = QFileInfo(exec.first().remove(QLatin1Char('"'))).fileName();
            if (bin == QLatin1String("flatpak"))
                bin = e.id.section(QLatin1Char('.'), -1).toLower();
            for (const QString &k : {bin, d.value(QStringLiteral("StartupWMClass")).toString().toLower()}) {
                if (k.isEmpty())
                    continue;
                // Las entradas visibles ganan a las ocultas (p. ej. "Firefox" frente a un ayudante)
                if (!m_byExec.contains(k) || shown)
                    if (!m_byExec.contains(k) || m_byExec[k].id.contains(QLatin1String("kcm")))
                        m_byExec.insert(k, e);
            }
        }
    }
}

const AppEntry *AppIndex::forProcess(const ProcInfo &p) const
{
    for (const QString &k : {QFileInfo(p.exe).fileName(), p.comm, QFileInfo(p.cmdline.section(QLatin1Char(' '), 0, 0)).fileName()}) {
        const auto it = m_byExec.constFind(k.toLower());
        if (it != m_byExec.constEnd())
            return &*it;
        const auto exact = m_byExec.constFind(k);
        if (exact != m_byExec.constEnd())
            return &*exact;
    }
    return nullptr;
}

const AppEntry *AppIndex::forId(const QString &desktopId) const
{
    QString id = desktopId;
    id.remove(QStringLiteral(".desktop"));
    auto it = m_byId.constFind(id);
    if (it == m_byId.constEnd())
        it = m_byId.constFind(id.toLower());
    return it != m_byId.constEnd() ? &*it : nullptr;
}

// ---------------- Modelo ----------------

ProcessModel::ProcessModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int ProcessModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_rows.size();
}

QHash<int, QByteArray> ProcessModel::roleNames() const
{
    return {{KindRole, "kind"}, {KeyRole, "key"}, {NameRole, "name"}, {IconRole, "iconName"}, {PidRole, "pid"},
            {CountRole, "count"}, {ExpandedRole, "expanded"}, {StatusRole, "status"}, {EfficiencyRole, "efficiency"},
            {CpuRole, "cpu"}, {MemRole, "mem"}, {DiskRole, "disk"}, {NetRole, "net"}, {UserRole, "user"},
            {DescriptionRole, "description"}, {DepthRole, "depth"}, {WindowRole, "window"},
            {GpuRole, "gpu"}, {GpuEngineRole, "gpuEngine"}};
}

QVariant ProcessModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_rows.size())
        return {};
    const Row &r = m_rows[index.row()];
    switch (role) {
    case KindRole: return r.kind;
    case KeyRole: return r.key;
    case NameRole: return r.name;
    case IconRole: return r.icon;
    case PidRole: return r.pid;
    case CountRole: return r.count;
    case ExpandedRole: return r.expanded;
    case StatusRole: return r.status;
    case EfficiencyRole: return r.efficiency;
    case CpuRole: return r.cpu;
    case MemRole: return r.mem;
    case DiskRole: return r.disk;
    case NetRole: return r.net;
    case UserRole: return r.user;
    case DescriptionRole: return r.description;
    case DepthRole: return r.depth;
    case WindowRole: return r.window;
    case GpuRole: return r.gpu;
    case GpuEngineRole: return r.gpuEngine;
    }
    return {};
}

void ProcessModel::setMonitor(SysMon *m)
{
    if (m_mon == m)
        return;
    if (m_mon)
        disconnect(m_mon, nullptr, this, nullptr);
    m_mon = m;
    if (m_mon)
        connect(m_mon, &SysMon::updated, this, &ProcessModel::rebuild);
    rebuild();
    Q_EMIT monitorChanged();
}

void ProcessModel::setDetails(bool d)
{
    if (m_details == d)
        return;
    m_details = d;
    if (d) {
        m_sortColumn = Name;
        m_sortDesc = false;
    }
    rebuild();
    Q_EMIT monitorChanged();
}

void ProcessModel::setFilter(const QString &f)
{
    if (m_filter == f)
        return;
    m_filter = f;
    rebuild();
    Q_EMIT filterChanged();
}

void ProcessModel::setApps(const QVariantList &apps)
{
    m_apps.clear();
    for (const QVariant &v : apps) {
        const QVariantMap a = v.toMap();
        const int pid = a.value(QStringLiteral("pid")).toInt();
        if (pid > 0 && !m_apps.contains(pid))
            m_apps.insert(pid, a);
    }
    rebuild();
}

void ProcessModel::sortBy(int column)
{
    if (m_sortColumn == column) {
        m_sortDesc = !m_sortDesc;
    } else {
        m_sortColumn = column;
        // Los números se ordenan de mayor a menor la primera vez, como en Windows
        m_sortDesc = column == Cpu || column == Memory || column == Disk || column == Network || column == Gpu;
    }
    rebuild();
    Q_EMIT sortChanged();
}

void ProcessModel::toggle(const QString &key)
{
    if (!m_expanded.remove(key))
        m_expanded.insert(key);
    rebuild();
}

QString ProcessModel::processName(const ProcInfo &p) const
{
    if (const AppEntry *e = m_index.forProcess(p))
        return e->name;
    const QString exe = QFileInfo(p.exe).fileName();
    return exe.isEmpty() ? p.comm : exe;
}

QString ProcessModel::processIcon(const ProcInfo &p) const
{
    if (const AppEntry *e = m_index.forProcess(p); e && !e->icon.isEmpty())
        return e->icon;
    return QStringLiteral("application-x-executable");
}

static QString statusText(const ProcInfo &p)
{
    if (p.state == QLatin1Char('T') || p.state == QLatin1Char('t'))
        return QStringLiteral("Suspendido");
    if (p.state == QLatin1Char('Z'))
        return QStringLiteral("Zombi");
    return {};
}

bool ProcessModel::lessThan(const Row &a, const Row &b) const
{
    auto cmp = [&](auto x, auto y) -> int { return x < y ? -1 : (y < x ? 1 : 0); };
    int c = 0;
    switch (m_sortColumn) {
    case Status: c = QString::localeAwareCompare(a.status, b.status); break;
    case Cpu: c = cmp(a.cpu, b.cpu); break;
    case Memory: c = cmp(a.mem, b.mem); break;
    case Disk: c = cmp(a.disk, b.disk); break;
    case Network: c = cmp(a.net, b.net); break;
    case Pid: c = cmp(a.pid, b.pid); break;
    case User: c = QString::localeAwareCompare(a.user, b.user); break;
    case Description: c = QString::localeAwareCompare(a.description, b.description); break;
    case Gpu: c = cmp(a.gpu, b.gpu); break;
    case GpuEngine: c = QString::localeAwareCompare(a.gpuEngine, b.gpuEngine); break;
    default: c = QString::localeAwareCompare(a.name.toLower(), b.name.toLower()); break;
    }
    if (c == 0)   // desempate estable: la lista no "baila" entre muestras
        c = a.name.compare(b.name, Qt::CaseInsensitive) ? a.name.compare(b.name, Qt::CaseInsensitive) : cmp(a.pid, b.pid);
    return m_sortDesc ? c > 0 : c < 0;
}

bool ProcessModel::matches(const Row &r) const
{
    if (m_filter.isEmpty())
        return true;
    if (r.name.contains(m_filter, Qt::CaseInsensitive) || r.description.contains(m_filter, Qt::CaseInsensitive))
        return true;
    for (int pid : r.pids) {
        if (QString::number(pid).startsWith(m_filter))
            return true;
        const ProcInfo &p = m_mon->processes()[pid];
        if (p.comm.contains(m_filter, Qt::CaseInsensitive) || processName(p).contains(m_filter, Qt::CaseInsensitive))
            return true;
    }
    return false;
}

void ProcessModel::buildGrouped(QVector<Row> &rows)
{
    const auto &procs = m_mon->processes();
    const uint me = getuid();

    // ¿A qué ventana (aplicación) pertenece cada proceso? Se sube por los padres.
    QHash<int, int> appOf;
    std::function<int(int, int)> findApp = [&](int pid, int depth) -> int {
        if (pid <= 1 || depth > 64)
            return 0;
        if (m_apps.contains(pid))
            return pid;
        const auto c = appOf.constFind(pid);
        if (c != appOf.constEnd())
            return *c;
        const auto it = procs.constFind(pid);
        const int r = it == procs.constEnd() ? 0 : findApp(it->ppid, depth + 1);
        appOf.insert(pid, r);
        return r;
    };
    // Los demás se agrupan con su padre si es el mismo programa (p. ej. los procesos de un navegador)
    auto rootOf = [&](const ProcInfo &p) {
        const ProcInfo *cur = &p;
        for (int i = 0; i < 64; ++i) {
            const auto parent = procs.constFind(cur->ppid);
            if (parent == procs.constEnd() || parent->kernel || m_apps.contains(parent->pid))
                break;
            const bool same = !cur->exe.isEmpty() ? parent->exe == cur->exe : parent->comm == cur->comm;
            if (!same)
                break;
            cur = &*parent;
        }
        return cur->pid;
    };

    QHash<QString, Row> groups;
    QHash<QString, QVector<Row>> children;
    for (const ProcInfo &p : procs) {
        if (p.kernel)
            continue;
        QString key;
        const int app = findApp(p.pid, 0);
        if (app)
            key = QStringLiteral("app:%1").arg(app);
        else
            key = QStringLiteral("%1:%2").arg(p.uid == me ? QStringLiteral("bg") : QStringLiteral("sys")).arg(rootOf(p));

        Row &g = groups[key];
        if (g.key.isEmpty()) {
            g.kind = 1;
            g.key = key;
            g.pid = key.section(QLatin1Char(':'), 1).toInt();
            g.efficiency = true;
            const auto root = procs.constFind(g.pid);
            if (app) {
                const QVariantMap a = m_apps.value(app);
                const AppEntry *e = m_index.forId(a.value(QStringLiteral("appId")).toString());
                g.name = a.value(QStringLiteral("name")).toString();
                if (g.name.isEmpty())
                    g.name = e ? e->name : processName(*root);
                g.icon = e && !e->icon.isEmpty() ? e->icon : (root != procs.constEnd() ? processIcon(*root) : QString());
                g.window = a.value(QStringLiteral("window")).toInt();
            } else if (root != procs.constEnd()) {
                g.name = processName(*root);
                g.icon = processIcon(*root);
                g.status = statusText(*root);
            }
        }
        g.pids.append(p.pid);
        g.count++;
        g.cpu += p.cpu;
        g.mem += p.privateBytes;
        g.disk += p.disk;
        g.net += p.net;
        if (p.gpu > 0 && p.gpu >= g.gpu)
            g.gpuEngine = p.gpuEngine;
        g.gpu = qMin(100.0, g.gpu + p.gpu);
        g.efficiency = g.efficiency && p.nice >= 19;

        Row c;
        c.kind = 2;
        c.key = QStringLiteral("p:%1").arg(p.pid);
        c.pid = p.pid;
        c.depth = 1;
        c.name = processName(p);
        c.icon = processIcon(p);
        c.status = statusText(p);
        c.efficiency = p.nice >= 19;
        c.cpu = p.cpu;
        c.mem = p.privateBytes;
        c.disk = p.disk;
        c.net = p.net;
        c.gpu = p.gpu;
        c.gpuEngine = p.gpuEngine;
        c.pids = {p.pid};
        children[key].append(c);
    }

    // Historial de aplicaciones: tiempo de CPU, disco y red de lo que es del usuario
    m_appHistory.clear();
    const double hz = sysconf(_SC_CLK_TCK);
    for (auto it = groups.cbegin(); it != groups.cend(); ++it) {
        if (it.key().startsWith(QLatin1String("sys:")))
            continue;
        quint64 ticks = 0, io = 0;
        for (int pid : it->pids) {
            ticks += procs[pid].cpuTicks;
            io += procs[pid].ioBytes;
        }
        double &net = m_netAccum[it->name];
        net += it->net * (m_mon->interval() / 1000.0);
        const qint64 s = qint64(ticks / hz);
        m_appHistory.append(QVariantMap{{QStringLiteral("name"), it->name},
                                        {QStringLiteral("icon"), it->icon},
                                        {QStringLiteral("seconds"), double(s)},
                                        {QStringLiteral("cpuTime"), QStringLiteral("%1:%2:%3").arg(s / 3600).arg((s / 60) % 60, 2, 10, QLatin1Char('0')).arg(s % 60, 2, 10, QLatin1Char('0'))},
                                        {QStringLiteral("disk"), double(io)},
                                        {QStringLiteral("net"), net}});
    }

    const struct { const char *prefix; const char *title; } sections[] = {
        {"app:", "Aplicaciones"}, {"bg:", "Procesos en segundo plano"}, {"sys:", "Procesos del sistema"}};
    m_appCount = 0;
    for (const auto &s : sections) {
        QVector<Row> list;
        for (auto it = groups.begin(); it != groups.end(); ++it) {
            if (it.key().startsWith(QLatin1String(s.prefix)) && matches(*it))
                list.append(*it);
        }
        if (QLatin1String(s.prefix) == QLatin1String("app:"))
            m_appCount = list.size();
        if (list.isEmpty())
            continue;
        std::sort(list.begin(), list.end(), [this](const Row &a, const Row &b) { return lessThan(a, b); });
        Row h;
        h.kind = 0;
        h.key = QStringLiteral("h:") + QLatin1String(s.prefix);
        h.name = QStringLiteral("%1 (%2)").arg(QLatin1String(s.title)).arg(list.size());
        h.count = list.size();
        rows.append(h);
        for (Row &g : list) {
            g.expanded = m_expanded.contains(g.key);
            if (g.count > 1)
                g.name = QStringLiteral("%1 (%2)").arg(g.name).arg(g.count);
            rows.append(g);
            if (g.expanded && g.count > 1) {
                QVector<Row> &kids = children[g.key];
                std::sort(kids.begin(), kids.end(), [this](const Row &a, const Row &b) { return lessThan(a, b); });
                rows.append(kids);
            }
        }
    }
}

void ProcessModel::buildDetails(QVector<Row> &rows)
{
    static QHash<uint, QString> users;
    for (const ProcInfo &p : m_mon->processes()) {
        if (p.kernel)
            continue;
        Row r;
        r.kind = 1;
        r.key = QStringLiteral("p:%1").arg(p.pid);
        r.pid = p.pid;
        const QString exe = QFileInfo(p.exe).fileName();
        r.name = exe.isEmpty() ? p.comm : exe;
        r.icon = processIcon(p);
        r.status = statusText(p);
        if (r.status.isEmpty())
            r.status = QStringLiteral("En ejecución");
        r.efficiency = p.nice >= 19;
        if (!users.contains(p.uid)) {
            const passwd *pw = getpwuid(p.uid);
            users.insert(p.uid, pw ? QString::fromLocal8Bit(pw->pw_name) : QString::number(p.uid));
        }
        r.user = users.value(p.uid);
        const AppEntry *e = m_index.forProcess(p);
        r.description = e ? e->name : p.cmdline.left(120);
        r.cpu = p.cpu;
        r.mem = p.privateBytes;
        r.disk = p.disk;
        r.net = p.net;
        r.gpu = p.gpu;
        r.gpuEngine = p.gpuEngine;
        r.pids = {p.pid};
        if (matches(r))
            rows.append(r);
    }
    std::sort(rows.begin(), rows.end(), [this](const Row &a, const Row &b) { return lessThan(a, b); });
}

void ProcessModel::rebuild()
{
    if (!m_mon)
        return;
    QVector<Row> rows;
    rows.reserve(m_rows.size() + 8);
    if (m_details)
        buildDetails(rows);
    else
        buildGrouped(rows);

    // Misma estructura: solo cambian los valores (la lista no se reconstruye ni pierde el scroll)
    bool same = rows.size() == m_rows.size();
    for (int i = 0; same && i < rows.size(); ++i)
        same = rows[i].key == m_rows[i].key;
    if (same) {
        m_rows = std::move(rows);
        if (!m_rows.isEmpty())
            Q_EMIT dataChanged(index(0), index(m_rows.size() - 1));
    } else {
        beginResetModel();
        m_rows = std::move(rows);
        endResetModel();
    }
    Q_EMIT countsChanged();
}

// ---------------- Acciones ----------------

QList<int> ProcessModel::pidsFor(const QString &key) const
{
    for (const Row &r : m_rows) {
        if (r.key == key)
            return r.pids;
    }
    const int pid = key.section(QLatin1Char(':'), 1).toInt();
    return pid > 0 ? QList<int>{pid} : QList<int>{};
}

// Señal a varios procesos; los que no son del usuario se envían con pkexec (pide la contraseña)
void ProcessModel::signalPids(const QList<int> &pids, int sig)
{
    QStringList denied;
    for (int pid : pids) {
        if (::kill(pid, sig) != 0 && errno == EPERM)
            denied << QString::number(pid);
    }
    if (!denied.isEmpty())
        QProcess::startDetached(QStringLiteral("pkexec"), QStringList{QStringLiteral("kill"), QStringLiteral("-%1").arg(sig)} + denied);
}

void ProcessModel::endTask(const QString &key)
{
    const QList<int> pids = pidsFor(key);
    if (pids.isEmpty())
        return;
    // Primero se pide que cierren; a los 3 s se fuerza a los que sigan (si siguen siendo los mismos)
    QHash<int, quint64> starts;
    for (int pid : pids)
        starts.insert(pid, m_mon->processes().value(pid).startTicks);
    signalPids(pids, SIGTERM);
    QTimer::singleShot(3000, this, [this, starts] {
        QList<int> left;
        QDir proc(QStringLiteral("/proc"));
        for (auto it = starts.cbegin(); it != starts.cend(); ++it) {
            const QByteArray stat = [&] {
                QFile f(QStringLiteral("/proc/%1/stat").arg(it.key()));
                return f.open(QIODevice::ReadOnly) ? f.readAll() : QByteArray();
            }();
            if (stat.isEmpty())
                continue;
            const QList<QByteArray> fields = stat.mid(stat.lastIndexOf(')') + 2).split(' ');
            if (fields.value(19).toULongLong() == it.value() && fields.value(0) != "Z")
                left << it.key();
        }
        if (!left.isEmpty())
            signalPids(left, SIGKILL);
        m_mon->refresh();
    });
    QTimer::singleShot(300, m_mon, &SysMon::refresh);
}

void ProcessModel::endTree(int pid)
{
    QList<int> pids{pid};
    const auto &procs = m_mon->processes();
    for (int i = 0; i < pids.size(); ++i) {
        for (const ProcInfo &p : procs) {
            if (p.ppid == pids[i] && !pids.contains(p.pid))
                pids << p.pid;
        }
    }
    signalPids(pids, SIGKILL);
    QTimer::singleShot(300, m_mon, &SysMon::refresh);
}

void ProcessModel::setEfficiency(const QString &key, bool on)
{
    QStringList denied;
    for (int pid : pidsFor(key)) {
        if (setpriority(PRIO_PROCESS, pid, on ? 19 : 0) != 0)
            denied << QString::number(pid);
    }
    // Bajar la prioridad numérica (volver a 0) solo lo puede hacer el administrador
    if (!denied.isEmpty())
        QProcess::startDetached(QStringLiteral("pkexec"), QStringList{QStringLiteral("renice"), QStringLiteral("-n"), on ? QStringLiteral("19") : QStringLiteral("0"), QStringLiteral("-p")} + denied);
    QTimer::singleShot(200, m_mon, &SysMon::refresh);
}

void ProcessModel::setPriority(int pid, int nice)
{
    if (setpriority(PRIO_PROCESS, pid, nice) != 0)
        QProcess::startDetached(QStringLiteral("pkexec"), {QStringLiteral("renice"), QStringLiteral("-n"), QString::number(nice), QStringLiteral("-p"), QString::number(pid)});
    QTimer::singleShot(200, m_mon, &SysMon::refresh);
}

void ProcessModel::openLocation(int pid)
{
    const QString exe = m_mon->processes().value(pid).exe;
    if (exe.isEmpty())
        return;
    if (!QStandardPaths::findExecutable(QStringLiteral("dolphin")).isEmpty())
        QProcess::startDetached(QStringLiteral("dolphin"), {QStringLiteral("--select"), exe});
    else
        QDesktopServices::openUrl(QUrl::fromLocalFile(QFileInfo(exe).path()));
}

void ProcessModel::searchOnline(const QString &name)
{
    QString n = name;
    n.remove(QRegularExpression(QStringLiteral(" \\(\\d+\\)$")));
    QDesktopServices::openUrl(QUrl(QStringLiteral("https://duckduckgo.com/?q=") + QString::fromUtf8(QUrl::toPercentEncoding(n))));
}

bool ProcessModel::runTask(const QString &command, bool admin)
{
    const QString cmd = command.trimmed();
    if (cmd.isEmpty())
        return false;
    // Rutas y direcciones se abren con su aplicación, como en "Ejecutar" de Windows
    if (!admin && (cmd.contains(QLatin1String("://")) || (cmd.startsWith(QLatin1Char('/')) && QFileInfo(cmd).exists() && !QFileInfo(cmd).isExecutable())))
        return QDesktopServices::openUrl(QUrl::fromUserInput(cmd));
    if (admin)
        return QProcess::startDetached(QStringLiteral("pkexec"), {QStringLiteral("env"), QStringLiteral("DISPLAY=") + qEnvironmentVariable("DISPLAY"),
                                                                  QStringLiteral("WAYLAND_DISPLAY=") + qEnvironmentVariable("WAYLAND_DISPLAY"),
                                                                  QStringLiteral("XDG_RUNTIME_DIR=") + qEnvironmentVariable("XDG_RUNTIME_DIR"),
                                                                  QStringLiteral("sh"), QStringLiteral("-c"), cmd});
    return QProcess::startDetached(QStringLiteral("sh"), {QStringLiteral("-c"), cmd});
}

QVariantMap ProcessModel::info(int pid) const
{
    const ProcInfo p = m_mon->processes().value(pid);
    return {{QStringLiteral("pid"), p.pid}, {QStringLiteral("exe"), p.exe}, {QStringLiteral("cmdline"), p.cmdline},
            {QStringLiteral("nice"), p.nice}, {QStringLiteral("threads"), p.threads}, {QStringLiteral("comm"), p.comm}};
}
