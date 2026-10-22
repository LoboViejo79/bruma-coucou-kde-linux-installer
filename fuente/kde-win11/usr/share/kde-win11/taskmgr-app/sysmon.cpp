#include "sysmon.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QLocale>
#include <QNetworkInterface>
#include <QSet>
#include <QStandardPaths>
#include <array>
#include <cstring>
#include <functional>

#include <pwd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <memory>
#include <sys/statvfs.h>
#include <unistd.h>

static constexpr int HISTORY = 60;

// Lectura rápida de un archivo pequeño de /proc o /sys (sin QFile ni señales)
static QByteArray readSmall(const char *path)
{
    QByteArray out;
    const int fd = ::open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0)
        return out;
    char buf[8192];
    ssize_t n;
    while ((n = ::read(fd, buf, sizeof buf)) > 0)
        out.append(buf, n);
    ::close(fd);
    return out;
}
static QByteArray readSmall(const QString &path)
{
    return readSmall(QFile::encodeName(path).constData());
}
static QString readLine(const QString &path)
{
    return QString::fromUtf8(readSmall(path)).trimmed();
}

SysMon::SysMon(QObject *parent)
    : QObject(parent)
{
    m_pageSize = sysconf(_SC_PAGESIZE);
    m_hz = sysconf(_SC_CLK_TCK);
    for (int i = 0; i < HISTORY; ++i) {
        m_cpuHistory.append(0.0);
        m_memHistory.append(0.0);
    }
    loadCpuInfo();
    loadGpuInfo();
    startNvidia();
    startNetHelper();
    m_timer.setInterval(1000);
    connect(&m_timer, &QTimer::timeout, this, &SysMon::refresh);
    refresh();
    m_timer.start();
}

SysMon::~SysMon()
{
    if (m_netHelper) {
        m_netHelper->kill();
        m_netHelper->waitForFinished(500);
    }
}

void SysMon::setInterval(int ms)
{
    m_timer.setInterval(ms);
    Q_EMIT intervalChanged();
}

void SysMon::setPaused(bool p)
{
    if (p)
        m_timer.stop();
    else
        m_timer.start();
    Q_EMIT intervalChanged();
}

QString SysMon::userName() const
{
    return qEnvironmentVariable("USER");
}

void SysMon::push(QVariantList &history, double v)
{
    if (history.size() >= HISTORY)
        history.removeFirst();
    while (history.size() < HISTORY - 1)
        history.prepend(0.0);
    history.append(v);
}

void SysMon::refresh()
{
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const double secs = m_lastSample ? qMax(0.05, (now - m_lastSample) / 1000.0) : 1.0;
    m_lastSample = now;
    sampleCpu(secs);
    sampleMemory();
    sampleDisks(secs);
    sampleNets(secs);
    sampleProcesses(secs);
    sampleGpus(secs);
    Q_EMIT updated();
}

// ---------------- CPU ----------------

void SysMon::loadCpuInfo()
{
    const QString info = QString::fromUtf8(readSmall("/proc/cpuinfo"));
    QString model;
    QSet<QString> sockets;
    int logical = 0, coresPerSocket = 0;
    double mhz = 0;
    QString flags;
    for (const QString &line : info.split(QLatin1Char('\n'))) {
        const int c = line.indexOf(QLatin1Char(':'));
        if (c < 0)
            continue;
        const QString k = line.left(c).trimmed(), v = line.mid(c + 1).trimmed();
        if (k == QLatin1String("processor"))
            ++logical;
        else if (k == QLatin1String("model name") && model.isEmpty())
            model = v;
        else if (k == QLatin1String("physical id"))
            sockets.insert(v);
        else if (k == QLatin1String("cpu cores"))
            coresPerSocket = v.toInt();
        else if (k == QLatin1String("cpu MHz") && mhz == 0)
            mhz = v.toDouble();
        else if (k == QLatin1String("flags") && flags.isEmpty())
            flags = v;
    }
    const int nSockets = qMax(1, int(sockets.size()));
    const int cores = coresPerSocket > 0 ? coresPerSocket * nSockets : logical;
    double baseGHz = readLine(QStringLiteral("/sys/devices/system/cpu/cpu0/cpufreq/base_frequency")).toDouble() / 1e6;
    if (baseGHz <= 0)
        baseGHz = readLine(QStringLiteral("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq")).toDouble() / 1e6;
    if (baseGHz <= 0)
        baseGHz = mhz / 1000.0;
    const QStringList fl = flags.split(QLatin1Char(' '));

    // Cachés: tamaño de cada una por los procesadores lógicos que la comparten
    quint64 l1 = 0, l2 = 0, l3 = 0;
    QDir cacheDir(QStringLiteral("/sys/devices/system/cpu/cpu0/cache"));
    for (const QString &idx : cacheDir.entryList({QStringLiteral("index*")}, QDir::Dirs)) {
        const QString base = cacheDir.filePath(idx) + QLatin1Char('/');
        const int level = readLine(base + QStringLiteral("level")).toInt();
        QString size = readLine(base + QStringLiteral("size"));
        quint64 bytes = size.left(size.size() - 1).toULongLong() * (size.endsWith(QLatin1Char('M')) ? 1024 * 1024 : 1024);
        // shared_cpu_list: "0-1" o "0,2" → cuántos lógicos la comparten
        int sharing = 0;
        for (const QString &part : readLine(base + QStringLiteral("shared_cpu_list")).split(QLatin1Char(','))) {
            const QStringList r = part.split(QLatin1Char('-'));
            sharing += r.size() == 2 ? r[1].toInt() - r[0].toInt() + 1 : 1;
        }
        const quint64 total = bytes * quint64(qMax(1, logical / qMax(1, sharing)));
        (level == 1 ? l1 : level == 2 ? l2 : l3) += total;
    }

    m_cpuInfo = {
        {QStringLiteral("model"), model.isEmpty() ? QStringLiteral("Procesador") : model.simplified()},
        {QStringLiteral("baseSpeed"), baseGHz},
        {QStringLiteral("sockets"), nSockets},
        {QStringLiteral("cores"), cores},
        {QStringLiteral("logical"), logical},
        {QStringLiteral("virtualization"), fl.contains(QLatin1String("vmx")) || fl.contains(QLatin1String("svm")) ? QStringLiteral("Habilitado") : QStringLiteral("No disponible")},
        {QStringLiteral("vm"), fl.contains(QLatin1String("hypervisor"))},
        {QStringLiteral("l1"), l1 ? formatBytes(l1) : QString()},
        {QStringLiteral("l2"), l2 ? formatBytes(l2) : QString()},
        {QStringLiteral("l3"), l3 ? formatBytes(l3) : QString()},
    };
    for (int i = 0; i < logical; ++i)
        m_coreUsage.append(0.0);
}

void SysMon::sampleCpu(double)
{
    const QList<QByteArray> lines = readSmall("/proc/stat").split('\n');
    QVector<quint64> total, idle;
    quint64 ctxt = 0;
    for (const QByteArray &l : lines) {
        if (l.startsWith("cpu")) {
            const QList<QByteArray> f = l.simplified().split(' ');
            quint64 t = 0;
            for (int i = 1; i <= 8 && i < f.size(); ++i)
                t += f[i].toULongLong();
            total.append(t);
            idle.append(f.value(4).toULongLong() + f.value(5).toULongLong());
        } else if (l.startsWith("ctxt")) {
            ctxt = l.mid(5).toULongLong();
        }
    }
    Q_UNUSED(ctxt)
    if (m_prevTotal.size() == total.size()) {
        auto usage = [&](int i) {
            const quint64 dt = total[i] - m_prevTotal[i], di = idle[i] - m_prevIdle[i];
            return dt ? qBound(0.0, 100.0 * double(dt - qMin(di, dt)) / double(dt), 100.0) : 0.0;
        };
        m_cpu = usage(0);
        m_cpuTotalDelta = total[0] - m_prevTotal[0];
        m_coreUsage.clear();
        m_coreHist.resize(total.size() - 1);
        for (int i = 1; i < total.size(); ++i) {
            m_coreUsage.append(usage(i));
            push(m_coreHist[i - 1], usage(i));
        }
    }
    m_prevTotal = total;
    m_prevIdle = idle;
    push(m_cpuHistory, m_cpu);

    // Velocidad actual: media de los núcleos
    double sum = 0;
    int n = 0;
    for (int i = 0; i < m_cpuInfo.value(QStringLiteral("logical")).toInt(); ++i) {
        const double f = readLine(QStringLiteral("/sys/devices/system/cpu/cpu%1/cpufreq/scaling_cur_freq").arg(i)).toDouble();
        if (f > 0) {
            sum += f / 1e6;
            ++n;
        }
    }
    const double speed = n ? sum / n : m_cpuInfo.value(QStringLiteral("baseSpeed")).toDouble();

    const double up = QString::fromLatin1(readSmall("/proc/uptime")).section(QLatin1Char(' '), 0, 0).toDouble();
    const qint64 s = qint64(up);
    const QString uptime = QStringLiteral("%1:%2:%3:%4")
                               .arg(s / 86400)
                               .arg((s / 3600) % 24, 2, 10, QLatin1Char('0'))
                               .arg((s / 60) % 60, 2, 10, QLatin1Char('0'))
                               .arg(s % 60, 2, 10, QLatin1Char('0'));
    const quint64 handles = QString::fromLatin1(readSmall("/proc/sys/fs/file-nr")).section(QLatin1Char('\t'), 0, 0).toULongLong();
    m_cpuStats[QStringLiteral("speed")] = speed;
    m_cpuStats[QStringLiteral("uptime")] = uptime;
    m_cpuStats[QStringLiteral("handles")] = handles;
}

// ---------------- Memoria ----------------

void SysMon::sampleMemory()
{
    // RAM instalada: bloques de memoria en línea (lo que no ve el sistema es "hardware reservado")
    if (m_physicalRam == 0) {
        const double block = readLine(QStringLiteral("/sys/devices/system/memory/block_size_bytes")).toULongLong(nullptr, 16);
        int online = 0;
        QDir mem(QStringLiteral("/sys/devices/system/memory"));
        for (const QString &b : mem.entryList({QStringLiteral("memory*")}, QDir::Dirs))
            online += readLine(mem.filePath(b) + QStringLiteral("/online")) == QLatin1String("1");
        m_physicalRam = block * online;
        if (m_physicalRam <= 0)
            m_physicalRam = -1;
    }
    QHash<QByteArray, quint64> m;
    for (const QByteArray &l : readSmall("/proc/meminfo").split('\n')) {
        const int c = l.indexOf(':');
        if (c > 0)
            m.insert(l.left(c), l.mid(c + 1).simplified().split(' ').value(0).toULongLong() * 1024);
    }
    m_memTotal = m.value("MemTotal");
    const quint64 avail = m.value("MemAvailable");
    const quint64 used = m_memTotal - avail;
    const quint64 cached = m.value("Cached") + m.value("Buffers") + m.value("SReclaimable");
    const quint64 modified = m.value("Dirty") + m.value("Writeback");
    m_memory = {
        {QStringLiteral("total"), double(m_memTotal)},
        {QStringLiteral("used"), double(used)},
        {QStringLiteral("available"), double(avail)},
        {QStringLiteral("free"), double(m.value("MemFree"))},
        {QStringLiteral("cached"), double(cached)},
        {QStringLiteral("modified"), double(modified)},
        {QStringLiteral("compressed"), double(m.value("Zswap"))},
        {QStringLiteral("committed"), double(m.value("Committed_AS"))},
        {QStringLiteral("commitLimit"), double(m_memTotal + m.value("SwapTotal"))},
        {QStringLiteral("paged"), double(m.value("SReclaimable"))},
        {QStringLiteral("nonPaged"), double(m.value("SUnreclaim") + m.value("KernelStack") + m.value("PageTables"))},
        {QStringLiteral("swapTotal"), double(m.value("SwapTotal"))},
        {QStringLiteral("swapUsed"), double(m.value("SwapTotal") - m.value("SwapFree"))},
        {QStringLiteral("percent"), m_memTotal ? 100.0 * used / m_memTotal : 0.0},
        {QStringLiteral("reserved"), qMax(0.0, m_physicalRam - double(m_memTotal))},
        {QStringLiteral("physical"), m_physicalRam > 0 ? m_physicalRam : double(m_memTotal)},
    };
    push(m_memHistory, m_memory.value(QStringLiteral("percent")).toDouble());
}

// ---------------- Discos ----------------

void SysMon::sampleDisks(double secs)
{
    // Disco que contiene la raíz del sistema
    static QString systemDisk;
    if (systemDisk.isNull()) {
        systemDisk = QStringLiteral("");
        for (const QString &l : QString::fromUtf8(readSmall("/proc/mounts")).split(QLatin1Char('\n'))) {
            const QStringList f = l.split(QLatin1Char(' '));
            if (f.size() > 1 && f[1] == QLatin1String("/") && f[0].startsWith(QLatin1String("/dev/"))) {
                const QString part = QFileInfo(f[0]).canonicalFilePath().mid(5);
                // /sys/class/block/<partición> -> enlace dentro de su disco
                const QString target = QFileInfo(QStringLiteral("/sys/class/block/") + part).canonicalFilePath();
                const QString parent = QFileInfo(target).dir().dirName();
                systemDisk = QFileInfo::exists(QStringLiteral("/sys/block/") + parent) ? parent : part;
            }
        }
    }

    QVariantList out;
    double total = 0;
    int index = 0;
    for (const QByteArray &l : readSmall("/proc/diskstats").split('\n')) {
        const QList<QByteArray> f = l.simplified().split(' ');
        if (f.size() < 14)
            continue;
        const QString name = QString::fromLatin1(f[2]);
        if (name.startsWith(QLatin1String("loop")) || name.startsWith(QLatin1String("ram")) || name.startsWith(QLatin1String("zram"))
            || name.startsWith(QLatin1String("dm-")) || name.startsWith(QLatin1String("sr")) || name.startsWith(QLatin1String("fd"))
            || !QFileInfo::exists(QStringLiteral("/sys/block/") + name))
            continue;
        const quint64 rd = f[5].toULongLong() * 512, wr = f[9].toULongLong() * 512, ticks = f[12].toULongLong();
        const quint64 ios = f[3].toULongLong() + f[7].toULongLong(), ms = f[6].toULongLong() + f[10].toULongLong();
        IoPrev &p = m_diskPrev[name];
        double r = 0, w = 0, active = 0, response = 0;
        if (p.a || p.b || p.c) {
            r = (rd - p.a) / secs;
            w = (wr - p.b) / secs;
            active = qBound(0.0, (ticks - p.c) / (secs * 10.0), 100.0);
            if (ios > p.ios)
                response = double(ms - p.ms) / double(ios - p.ios);
        }
        p = {rd, wr, ticks, ios, ms};
        // Formateado (sistemas de archivos montados en este disco) y si tiene intercambio
        double formatted = 0;
        bool swap = false;
        QSet<QString> devs;
        for (const QString &l : QString::fromUtf8(readSmall("/proc/mounts")).split(QLatin1Char('\n'))) {
            const QString d = l.section(QLatin1Char(' '), 0, 0);
            if (!d.startsWith(QLatin1String("/dev/")) || devs.contains(d))
                continue;
            const QString part = QFileInfo(d).canonicalFilePath().mid(5);
            if (part == name || QFileInfo::exists(QStringLiteral("/sys/block/%1/%2").arg(name, part))) {
                devs.insert(d);
                struct statvfs vfs;
                if (statvfs(QFile::encodeName(l.section(QLatin1Char(' '), 1, 1)).constData(), &vfs) == 0)
                    formatted += double(vfs.f_blocks) * vfs.f_frsize;
            }
        }
        for (const QString &l : QString::fromUtf8(readSmall("/proc/swaps")).split(QLatin1Char('\n')).mid(1)) {
            const QString d = l.section(QLatin1Char(' '), 0, 0);
            if (d.isEmpty() || d.contains(QLatin1String("zram")))
                continue;
            const QString part = QFileInfo(d).canonicalFilePath().mid(5);
            swap = swap || part == name || QFileInfo::exists(QStringLiteral("/sys/block/%1/%2").arg(name, part)) || !d.startsWith(QLatin1String("/dev/"));
        }
        push(m_diskHist[name], active);
        push(m_diskReadHist[name], r);
        push(m_diskWriteHist[name], w);
        total += r + w;
        const QString sys = QStringLiteral("/sys/block/") + name;
        out.append(QVariantMap{
            {QStringLiteral("name"), name},
            {QStringLiteral("index"), index++},
            {QStringLiteral("model"), readLine(sys + QStringLiteral("/device/model"))},
            {QStringLiteral("type"), readLine(sys + QStringLiteral("/queue/rotational")) == QLatin1String("0") ? QStringLiteral("SSD") : QStringLiteral("HDD")},
            {QStringLiteral("capacity"), readLine(sys + QStringLiteral("/size")).toDouble() * 512},
            {QStringLiteral("system"), name == systemDisk},
            {QStringLiteral("active"), active},
            {QStringLiteral("response"), response},
            {QStringLiteral("formatted"), formatted},
            {QStringLiteral("pagefile"), swap},
            {QStringLiteral("read"), r},
            {QStringLiteral("write"), w},
            {QStringLiteral("history"), m_diskHist[name]},
            {QStringLiteral("readHistory"), m_diskReadHist[name]},
            {QStringLiteral("writeHistory"), m_diskWriteHist[name]},
        });
    }
    m_disks = out;
    m_diskTotal = total;
}

// ---------------- Red ----------------

void SysMon::sampleNets(double secs)
{
    QVariantList out;
    double total = 0;
    for (const QByteArray &l : readSmall("/proc/net/dev").split('\n')) {
        const int c = l.indexOf(':');
        if (c < 0)
            continue;
        const QString name = QString::fromLatin1(l.left(c).trimmed());
        const QString sys = QStringLiteral("/sys/class/net/") + name;
        const bool wifi = QFileInfo::exists(sys + QStringLiteral("/wireless"));
        // Solo adaptadores físicos (ni lo, ni puentes de Docker/VPN)
        if (name == QLatin1String("lo") || (!QFileInfo::exists(sys + QStringLiteral("/device")) && !wifi))
            continue;
        const QList<QByteArray> f = l.mid(c + 1).simplified().split(' ');
        const quint64 rx = f.value(0).toULongLong(), tx = f.value(8).toULongLong();
        IoPrev &p = m_netPrev[name];
        double r = 0, s = 0;
        if (p.a || p.b) {
            r = (rx - p.a) / secs;
            s = (tx - p.b) / secs;
        }
        p = {rx, tx, 0};
        push(m_netHist[name], r * 8 / 1000);       // Kbps
        push(m_netSendHist[name], s * 8 / 1000);
        total += r + s;
        QString v4, v6;
        const QNetworkInterface iface = QNetworkInterface::interfaceFromName(name);
        for (const QNetworkAddressEntry &e : iface.addressEntries()) {
            if (e.ip().protocol() == QAbstractSocket::IPv4Protocol && v4.isEmpty())
                v4 = e.ip().toString();
            else if (e.ip().protocol() == QAbstractSocket::IPv6Protocol && v6.isEmpty())
                v6 = e.ip().toString().section(QLatin1Char('%'), 0, 0);
        }
        const int speed = readLine(sys + QStringLiteral("/speed")).toInt();
        out.append(QVariantMap{
            {QStringLiteral("name"), name},
            {QStringLiteral("type"), wifi ? QStringLiteral("Wi-Fi") : QStringLiteral("Ethernet")},
            {QStringLiteral("up"), readLine(sys + QStringLiteral("/operstate")) == QLatin1String("up")},
            {QStringLiteral("recv"), r},
            {QStringLiteral("send"), s},
            {QStringLiteral("history"), m_netHist[name]},
            {QStringLiteral("sendHistory"), m_netSendHist[name]},
            {QStringLiteral("ipv4"), v4},
            {QStringLiteral("ipv6"), v6},
            {QStringLiteral("linkSpeed"), speed > 0 ? speed : 0},
            {QStringLiteral("mac"), iface.hardwareAddress()},
        });
    }
    m_nets = out;
    m_netTotal = total;
}

// ---------------- GPU ----------------

// Nombre comercial a partir de pci.ids ("VMware SVGA II Adapter", "AMD Radeon RX 6700 XT"...)
static QString pciName(const QString &vendor, const QString &device)
{
    static const QHash<QString, QString> shortVendor{{QStringLiteral("1002"), QStringLiteral("AMD")},
                                                     {QStringLiteral("10de"), QStringLiteral("NVIDIA")},
                                                     {QStringLiteral("8086"), QStringLiteral("Intel(R)")},
                                                     {QStringLiteral("15ad"), QStringLiteral("VMware")},
                                                     {QStringLiteral("80ee"), QStringLiteral("VirtualBox")},
                                                     {QStringLiteral("1af4"), QStringLiteral("Red Hat VirtIO")},
                                                     {QStringLiteral("1b36"), QStringLiteral("QEMU")},
                                                     {QStringLiteral("1234"), QStringLiteral("QEMU")}};
    QString vendorName = shortVendor.value(vendor), deviceName;
    QFile f(QStringLiteral("/usr/share/hwdata/pci.ids"));
    if (f.open(QIODevice::ReadOnly)) {
        bool inVendor = false;
        while (!f.atEnd()) {
            const QByteArray line = f.readLine();
            if (line.startsWith('#') || line.trimmed().isEmpty())
                continue;
            if (line[0] != '\t') {
                if (inVendor)
                    break;
                if (line.startsWith(vendor.toLatin1() + "  ")) {
                    inVendor = true;
                    if (vendorName.isEmpty())
                        vendorName = QString::fromUtf8(line.mid(6)).trimmed();
                }
            } else if (inVendor && line.size() > 1 && line[1] != '\t' && line.mid(1, 4) == device.toLatin1()) {
                deviceName = QString::fromUtf8(line.mid(7)).trimmed();
                break;
            }
        }
    }
    // "Navi 22 [Radeon RX 6700/6700 XT]" -> "Radeon RX 6700/6700 XT"
    const int lb = deviceName.indexOf(QLatin1Char('[')), rb = deviceName.lastIndexOf(QLatin1Char(']'));
    if (lb >= 0 && rb > lb)
        deviceName = deviceName.mid(lb + 1, rb - lb - 1);
    if (deviceName.isEmpty())
        deviceName = QStringLiteral("Adaptador de pantalla");
    return deviceName.startsWith(vendorName) ? deviceName : vendorName + QLatin1Char(' ') + deviceName;
}

void SysMon::loadGpuInfo()
{
    QDir drm(QStringLiteral("/sys/class/drm"));
    int nvidia = 0;
    for (const QString &card : drm.entryList({QStringLiteral("card*")}, QDir::Dirs | QDir::System, QDir::Name)) {
        if (card.contains(QLatin1Char('-')))   // conectores (card0-HDMI-A-1...)
            continue;
        const QString dev = drm.filePath(card) + QStringLiteral("/device");
        GpuCard g;
        g.card = card;
        g.pdev = QFileInfo(dev).canonicalFilePath().section(QLatin1Char('/'), -1);
        g.driver = QFileInfo(QFileInfo(dev + QStringLiteral("/driver")).canonicalFilePath()).fileName();
        const QString vendor = readLine(dev + QStringLiteral("/vendor")).mid(2), device = readLine(dev + QStringLiteral("/device")).mid(2);
        g.name = pciName(vendor, device);
        g.integrated = g.driver == QLatin1String("i915") || g.driver == QLatin1String("xe")
            || readLine(dev + QStringLiteral("/boot_vga")) == QLatin1String("1") && vendor == QLatin1String("8086");
        g.driverVersion = readLine(QStringLiteral("/sys/module/%1/version").arg(g.driver));
        if (g.driverVersion.isEmpty())
            g.driverVersion = QString::fromLatin1(readSmall("/proc/sys/kernel/osrelease")).trimmed();
        // Ubicación PCI como en Windows: "Bus PCI 0, dispositivo 2, función 0"
        const QStringList parts = g.pdev.split(QLatin1Char(':'));
        if (parts.size() == 3) {
            const QStringList df = parts[2].split(QLatin1Char('.'));
            g.location = QStringLiteral("Bus PCI %1, dispositivo %2, función %3")
                             .arg(parts[1].toInt(nullptr, 16)).arg(df.value(0).toInt(nullptr, 16)).arg(df.value(1).toInt());
        }
        // Memoria dedicada: la que informa el controlador; en GPU virtuales, la ventana de vídeo PCI
        g.dedicatedTotal = readLine(dev + QStringLiteral("/mem_info_vram_total")).toDouble();
        if (g.dedicatedTotal <= 0 && !g.integrated && g.driver != QLatin1String("nvidia")) {
            for (const QString &l : QString::fromLatin1(readSmall(dev + QStringLiteral("/resource"))).split(QLatin1Char('\n'))) {
                const QStringList r = l.split(QLatin1Char(' '));
                if (r.size() < 3)
                    continue;
                const quint64 start = r[0].toULongLong(nullptr, 16), end = r[1].toULongLong(nullptr, 16), flags = r[2].toULongLong(nullptr, 16);
                if (start && (flags & 0x200) && (flags & 0x2000))   // memoria, prefetchable
                    g.dedicatedTotal = qMax(g.dedicatedTotal, double(end - start + 1));
            }
        }
        if (g.driver == QLatin1String("nvidia"))
            g.nvidiaIndex = nvidia++;
        g.measurable = QFileInfo::exists(dev + QStringLiteral("/gpu_busy_percent")) || g.nvidiaIndex >= 0;
        m_gpuCards.append(g);
    }

    // Versión de OpenGL (lo más parecido a "Versión de DirectX"), una vez y en segundo plano
    auto *gl = new QProcess(this);
    connect(gl, &QProcess::finished, this, [this, gl] {
        for (const QString &l : QString::fromUtf8(gl->readAllStandardOutput()).split(QLatin1Char('\n'))) {
            if (l.trimmed().startsWith(QLatin1String("OpenGL version string:")) || l.trimmed().startsWith(QLatin1String("OpenGL core profile version string:"))) {
                m_glVersion = l.section(QLatin1Char(':'), 1).trimmed().section(QLatin1Char(' '), 0, 0);
                if (l.contains(QLatin1String("core profile")))
                    break;
            }
        }
        gl->deleteLater();
        Q_EMIT glChanged();
    });
    gl->start(QStringLiteral("glxinfo"), {QStringLiteral("-B")});
}

void SysMon::startNvidia()
{
    bool any = false;
    for (const GpuCard &g : std::as_const(m_gpuCards))
        any = any || g.nvidiaIndex >= 0;
    if (!any || QStandardPaths::findExecutable(QStringLiteral("nvidia-smi")).isEmpty())
        return;
    m_nvidia = new QProcess(this);
    connect(m_nvidia, &QProcess::readyReadStandardOutput, this, [this] {
        while (m_nvidia->canReadLine()) {
            const QStringList f = QString::fromUtf8(m_nvidia->readLine()).trimmed().split(QStringLiteral(", "));
            if (f.size() >= 6)
                m_nvidiaData[f[0].toInt()] = f;
        }
    });
    m_nvidia->start(QStringLiteral("nvidia-smi"), {QStringLiteral("--query-gpu=index,utilization.gpu,utilization.encoder,utilization.decoder,memory.used,memory.total"),
                                                   QStringLiteral("--format=csv,noheader,nounits"), QStringLiteral("-l"), QStringLiteral("1")});
}

// Motor DRM -> categoría de Windows
static int engineCategory(const QString &e)
{
    const QString n = e.toLower();
    if (n.contains(QLatin1String("enc")) || n == QLatin1String("vecs"))
        return 2;   // Video Encode
    if (n.contains(QLatin1String("dec")) || n.contains(QLatin1String("vcn")) || n.contains(QLatin1String("video")) || n == QLatin1String("vcs"))
        return 3;   // Video Decode
    if (n.contains(QLatin1String("copy")) || n.contains(QLatin1String("dma")) || n == QLatin1String("bcs"))
        return 1;   // Copy
    return 0;       // 3D (gfx, render, compute...)
}
static const char *const engineNames[] = {"3D", "Copy", "Video Encode", "Video Decode"};

static double sizeValue(const QString &v)
{
    const QStringList p = v.trimmed().split(QLatin1Char(' '));
    double n = p.value(0).toDouble();
    const QString u = p.value(1);
    if (u == QLatin1String("KiB")) n *= 1024;
    else if (u == QLatin1String("MiB")) n *= 1024 * 1024;
    else if (u == QLatin1String("GiB")) n *= 1024.0 * 1024 * 1024;
    return n;
}

void SysMon::sampleGpus(double secs)
{
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    // Uso por tarjeta y categoría, y memoria, sumando los clientes DRM de cada proceso
    QHash<QString, std::array<double, 4>> util;
    QHash<QString, double> vramUsed, sharedUsed;
    QSet<QString> seenClients;
    QHash<QString, QHash<QString, quint64>> nextPrev;
    char path[96];
    for (auto it = m_procs.begin(); it != m_procs.end(); ++it) {
        ProcInfo &p = it.value();
        if (p.kernel || p.uid != getuid())
            continue;
        // Qué descriptores son de /dev/dri (se vuelve a mirar cada 5 s)
        if (!m_drmScan.contains(p.pid) || now - m_drmScan[p.pid] > 5000) {
            QList<int> fds;
            snprintf(path, sizeof path, "/proc/%d/fd", p.pid);
            QDir fdDir(QString::fromLatin1(path));
            for (const QString &fd : fdDir.entryList(QDir::System | QDir::NoDotAndDotDot)) {
                char target[256];
                snprintf(path, sizeof path, "/proc/%d/fd/%s", p.pid, fd.toLatin1().constData());
                const ssize_t n = ::readlink(path, target, sizeof target - 1);
                if (n > 9 && strncmp(target, "/dev/dri/", 9) == 0)
                    fds << fd.toInt();
            }
            m_drmFds[p.pid] = fds;
            m_drmScan[p.pid] = now;
        }
        double best = 0;
        int bestCat = -1, bestCard = -1;
        for (int fd : std::as_const(m_drmFds[p.pid])) {
            snprintf(path, sizeof path, "/proc/%d/fdinfo/%d", p.pid, fd);
            const QString info = QString::fromUtf8(readSmall(path));
            if (!info.contains(QLatin1String("drm-client-id")))
                continue;
            QHash<QString, QString> kv;
            for (const QString &l : info.split(QLatin1Char('\n'))) {
                const int c = l.indexOf(QLatin1Char(':'));
                if (c > 0)
                    kv.insert(l.left(c), l.mid(c + 1).trimmed());
            }
            const QString pdev = kv.value(QStringLiteral("drm-pdev"));
            const QString client = pdev + QLatin1Char('/') + kv.value(QStringLiteral("drm-client-id"));
            if (seenClients.contains(client))
                continue;
            seenClients.insert(client);
            const int cardIndex = [&] {
                for (int i = 0; i < m_gpuCards.size(); ++i)
                    if (m_gpuCards[i].pdev == pdev) return i;
                return m_gpuCards.size() == 1 ? 0 : -1;
            }();
            if (cardIndex < 0)
                continue;
            const QString card = m_gpuCards[cardIndex].card;
            const QHash<QString, quint64> &prev = m_clientPrev.value(client);
            QHash<QString, quint64> &cur = nextPrev[client];
            std::array<double, 4> clientUtil{0, 0, 0, 0};
            for (auto k = kv.cbegin(); k != kv.cend(); ++k) {
                const QString &key = k.key();
                if (key.startsWith(QLatin1String("drm-engine-")) && !key.startsWith(QLatin1String("drm-engine-capacity-"))) {
                    const QString eng = key.mid(11);
                    const quint64 ns = k.value().section(QLatin1Char(' '), 0, 0).toULongLong();
                    cur.insert(key, ns);
                    m_gpuCards[cardIndex].measurable = true;
                    if (prev.contains(key) && ns >= prev[key]) {
                        const double cap = qMax(1.0, kv.value(QStringLiteral("drm-engine-capacity-") + eng, QStringLiteral("1")).toDouble());
                        clientUtil[engineCategory(eng)] += 100.0 * (ns - prev[key]) / (secs * 1e9 * cap);
                    }
                } else if (key.startsWith(QLatin1String("drm-cycles-"))) {
                    const QString eng = key.mid(11);
                    const quint64 cyc = k.value().toULongLong(), total = kv.value(QStringLiteral("drm-total-cycles-") + eng).toULongLong();
                    cur.insert(key, cyc);
                    cur.insert(QStringLiteral("total-") + key, total);
                    m_gpuCards[cardIndex].measurable = true;
                    const quint64 pc = prev.value(key), pt = prev.value(QStringLiteral("total-") + key);
                    if (prev.contains(key) && total > pt && cyc >= pc)
                        clientUtil[engineCategory(eng)] += 100.0 * (cyc - pc) / double(total - pt);
                } else if (key.startsWith(QLatin1String("drm-resident-"))) {
                    const QString region = key.mid(13);
                    (region == QLatin1String("vram") || region == QLatin1String("local") ? vramUsed : sharedUsed)[card] += sizeValue(k.value());
                }
            }
            auto &u = util[card];
            for (int c = 0; c < 4; ++c) {
                clientUtil[c] = qBound(0.0, clientUtil[c], 100.0);
                u[c] += clientUtil[c];
                if (clientUtil[c] > best) {
                    best = clientUtil[c];
                    bestCat = c;
                    bestCard = cardIndex;
                }
            }
        }
        p.gpu = best;
        p.gpuEngine = bestCat >= 0 ? QStringLiteral("GPU %1 - %2").arg(bestCard).arg(QLatin1String(engineNames[bestCat])) : QString();
    }
    m_clientPrev = std::move(nextPrev);
    for (auto it = m_drmScan.begin(); it != m_drmScan.end();) {   // procesos que ya no existen
        if (!m_procs.contains(it.key())) {
            m_drmFds.remove(it.key());
            it = m_drmScan.erase(it);
        } else {
            ++it;
        }
    }

    QVariantList out;
    const double sharedTotal = m_memTotal / 2.0;   // como Windows: la mitad de la RAM
    for (int i = 0; i < m_gpuCards.size(); ++i) {
        const GpuCard &g = m_gpuCards[i];
        const QString dev = QStringLiteral("/sys/class/drm/") + g.card + QStringLiteral("/device/");
        std::array<double, 4> u = util.value(g.card, {0, 0, 0, 0});
        double vram = vramUsed.value(g.card), shared = sharedUsed.value(g.card), vramTotal = g.dedicatedTotal;
        const QString busy = readLine(dev + QStringLiteral("gpu_busy_percent"));
        if (!busy.isEmpty())
            u[0] = qMax(u[0], busy.toDouble());
        if (QFileInfo::exists(dev + QStringLiteral("mem_info_vram_used"))) {
            vram = readLine(dev + QStringLiteral("mem_info_vram_used")).toDouble();
            shared = qMax(shared, readLine(dev + QStringLiteral("mem_info_gtt_used")).toDouble());
        }
        if (g.nvidiaIndex >= 0 && m_nvidiaData.contains(g.nvidiaIndex)) {
            const QStringList f = m_nvidiaData[g.nvidiaIndex];
            u[0] = f[1].toDouble();
            u[2] = f[2].toDouble();
            u[3] = f[3].toDouble();
            vram = f[4].toDouble() * 1024 * 1024;
            vramTotal = f[5].toDouble() * 1024 * 1024;
        }
        double usage = 0;
        for (int c = 0; c < 4; ++c) {
            u[c] = qBound(0.0, u[c], 100.0);
            usage = qMax(usage, u[c]);
            push(m_gpuHist[g.card + QString::number(c)], u[c]);
        }
        push(m_gpuHist[g.card], usage);
        push(m_gpuHist[g.card + QStringLiteral("vram")], vram);
        push(m_gpuHist[g.card + QStringLiteral("shared")], shared);
        out.append(QVariantMap{
            {QStringLiteral("index"), i},
            {QStringLiteral("name"), g.name},
            {QStringLiteral("driver"), g.driver},
            {QStringLiteral("driverVersion"), g.driverVersion},
            {QStringLiteral("location"), g.location},
            {QStringLiteral("measurable"), g.measurable || !busy.isEmpty()},
            {QStringLiteral("integrated"), g.integrated},
            {QStringLiteral("usage"), usage},
            {QStringLiteral("engines"), QVariantList{u[0], u[1], u[2], u[3]}},
            {QStringLiteral("engineHistory"), QVariantList{m_gpuHist[g.card + QStringLiteral("0")], m_gpuHist[g.card + QStringLiteral("1")],
                                                            m_gpuHist[g.card + QStringLiteral("2")], m_gpuHist[g.card + QStringLiteral("3")]}},
            {QStringLiteral("history"), m_gpuHist[g.card]},
            {QStringLiteral("vramUsed"), vram},
            {QStringLiteral("vramTotal"), vramTotal},
            {QStringLiteral("vramHistory"), m_gpuHist[g.card + QStringLiteral("vram")]},
            {QStringLiteral("sharedUsed"), shared},
            {QStringLiteral("sharedTotal"), sharedTotal},
            {QStringLiteral("sharedHistory"), m_gpuHist[g.card + QStringLiteral("shared")]},
        });
    }
    m_gpus = out;
}

QVariantList SysMon::coreHistory() const
{
    QVariantList l;
    for (const QVariantList &h : m_coreHist)
        l.append(QVariant(h));
    return l;
}

// ---------------- Procesos ----------------

void SysMon::startNetHelper()
{
    const QString helper = QStringLiteral("/usr/lib/ksysguard/ksgrd_network_helper");
    if (!QFileInfo(helper).isExecutable())
        return;
    m_netHelper = new QProcess(this);
    auto pending = std::make_shared<QHash<int, double>>();
    auto stamp = std::make_shared<QByteArray>();
    connect(m_netHelper, &QProcess::readyReadStandardOutput, this, [this, pending, stamp] {
        while (m_netHelper->canReadLine()) {
            const QByteArray line = m_netHelper->readLine().trimmed();
            // hh:mm:ss|PID|1234|IN|bytes|OUT|bytes  (una tanda por segundo)
            const QList<QByteArray> f = line.split('|');
            if (f.first() != *stamp) {
                m_netByPid = *pending;
                pending->clear();
                *stamp = f.first();
            }
            if (f.size() >= 7 && f[1] == "PID") {
                const int pid = f[2].toInt();
                if (pid > 0)
                    (*pending)[pid] += f[4].toDouble() + f[6].toDouble();
            }
        }
    });
    m_netHelper->start(helper, {});
}

void SysMon::sampleProcesses(double secs)
{
    QHash<int, ProcInfo> next;
    next.reserve(m_procs.size() + 16);
    QHash<uint, QVariantMap> byUser;
    int threads = 0;

    QDir proc(QStringLiteral("/proc"));
    char path[64];
    for (const QString &entry : proc.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        bool ok = false;
        const int pid = entry.toInt(&ok);
        if (!ok)
            continue;
        snprintf(path, sizeof path, "/proc/%d/stat", pid);
        const QByteArray stat = readSmall(path);
        const int open = stat.indexOf('('), close = stat.lastIndexOf(')');
        if (open < 0 || close < 0)
            continue;
        const QList<QByteArray> f = stat.mid(close + 2).split(' ');
        if (f.size() < 20)
            continue;

        ProcInfo p;
        p.pid = pid;
        p.comm = QString::fromUtf8(stat.mid(open + 1, close - open - 1));
        p.state = QLatin1Char(f[0].at(0));
        p.ppid = f[1].toInt();
        p.kernel = (f[6].toULongLong() & 0x00200000) || pid == 2 || p.ppid == 2;
        p.cpuTicks = f[11].toULongLong() + f[12].toULongLong();
        p.nice = f[16].toInt();
        p.threads = f[17].toInt();
        p.startTicks = f[19].toULongLong();
        threads += p.threads;

        struct stat st;
        snprintf(path, sizeof path, "/proc/%d", pid);
        if (::stat(path, &st) == 0)
            p.uid = st.st_uid;

        // Datos que no cambian: se reutilizan de la muestra anterior
        const auto prev = m_procs.constFind(pid);
        const bool same = prev != m_procs.constEnd() && prev->startTicks == p.startTicks;
        if (same) {
            p.exe = prev->exe;
            p.cmdline = prev->cmdline;
        } else if (!p.kernel) {
            snprintf(path, sizeof path, "/proc/%d/exe", pid);
            char buf[4096];
            const ssize_t n = ::readlink(path, buf, sizeof buf - 1);
            if (n > 0)
                p.exe = QString::fromUtf8(buf, n).remove(QStringLiteral(" (deleted)"));
            snprintf(path, sizeof path, "/proc/%d/cmdline", pid);
            QByteArray cmd = readSmall(path);
            cmd.replace('\0', ' ');
            p.cmdline = QString::fromUtf8(cmd).trimmed();
        }

        if (!p.kernel) {
            snprintf(path, sizeof path, "/proc/%d/statm", pid);
            const QList<QByteArray> m = readSmall(path).split(' ');
            if (m.size() > 2)
                p.privateBytes = (m[1].toULongLong() - qMin(m[1].toULongLong(), m[2].toULongLong())) * quint64(m_pageSize);
            snprintf(path, sizeof path, "/proc/%d/io", pid);
            const QByteArray io = readSmall(path);
            if (!io.isEmpty()) {
                for (const QByteArray &l : io.split('\n')) {
                    if (l.startsWith("read_bytes:") || l.startsWith("write_bytes:"))
                        p.ioBytes += l.mid(l.indexOf(':') + 1).trimmed().toULongLong();
                }
            }
        }

        if (same) {
            if (m_cpuTotalDelta)
                p.cpu = qBound(0.0, 100.0 * double(p.cpuTicks - qMin(p.cpuTicks, prev->cpuTicks)) / double(m_cpuTotalDelta), 100.0);
            if (p.ioBytes >= prev->ioBytes)
                p.disk = (p.ioBytes - prev->ioBytes) / secs;
        }
        p.net = m_netByPid.value(pid);

        if (!p.kernel && p.uid >= 1000 && p.uid < 65534) {
            QVariantMap &u = byUser[p.uid];
            u[QStringLiteral("cpu")] = u.value(QStringLiteral("cpu")).toDouble() + p.cpu;
            u[QStringLiteral("mem")] = u.value(QStringLiteral("mem")).toDouble() + double(p.privateBytes);
            u[QStringLiteral("disk")] = u.value(QStringLiteral("disk")).toDouble() + p.disk;
            u[QStringLiteral("net")] = u.value(QStringLiteral("net")).toDouble() + p.net;
            u[QStringLiteral("count")] = u.value(QStringLiteral("count")).toInt() + 1;
        }
        next.insert(pid, p);
    }
    m_procs = std::move(next);

    m_users.clear();
    for (auto it = byUser.begin(); it != byUser.end(); ++it) {
        QVariantMap u = it.value();
        if (const passwd *pw = getpwuid(it.key())) {
            u[QStringLiteral("name")] = QString::fromLocal8Bit(pw->pw_name);
            u[QStringLiteral("fullName")] = QString::fromLocal8Bit(pw->pw_gecos).section(QLatin1Char(','), 0, 0);
        } else {
            u[QStringLiteral("name")] = QString::number(it.key());
        }
        u[QStringLiteral("uid")] = it.key();
        m_users.append(u);
    }

    int count = 0;
    for (const ProcInfo &p : std::as_const(m_procs))
        count += p.kernel ? 0 : 1;
    m_cpuStats[QStringLiteral("processes")] = count;
    m_cpuStats[QStringLiteral("threads")] = threads;
}

// ---------------- Formato ----------------

QString SysMon::formatBytes(double bytes) const
{
    const QLocale loc;
    if (bytes < 1024)
        return QStringLiteral("%1 B").arg(int(bytes));
    if (bytes < 1024.0 * 1024)
        return loc.toString(bytes / 1024, 'f', 1) + QStringLiteral(" KB");
    if (bytes < 1024.0 * 1024 * 1024)
        return loc.toString(bytes / 1024 / 1024, 'f', 1) + QStringLiteral(" MB");
    return loc.toString(bytes / 1024 / 1024 / 1024, 'f', 1) + QStringLiteral(" GB");
}

QString SysMon::formatRate(double bytesPerSec) const
{
    const QLocale loc;
    const double bits = bytesPerSec * 8;
    if (bits < 1e6)
        return loc.toString(bits / 1e3, 'f', 1) + QStringLiteral(" Kbps");
    if (bits < 1e9)
        return loc.toString(bits / 1e6, 'f', 1) + QStringLiteral(" Mbps");
    return loc.toString(bits / 1e9, 'f', 1) + QStringLiteral(" Gbps");
}
