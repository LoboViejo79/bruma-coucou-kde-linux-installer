#pragma once

#include <QHash>
#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

// Un proceso leído de /proc en la última muestra
struct ProcInfo {
    int pid = 0;
    int ppid = 0;
    uint uid = 0;
    QString comm;       // nombre corto del núcleo
    QString exe;        // ruta del ejecutable (vacía si no se puede leer)
    QString cmdline;
    QChar state;
    int nice = 0;
    int threads = 0;
    quint64 cpuTicks = 0;   // utime + stime acumulados
    quint64 startTicks = 0;
    quint64 privateBytes = 0;
    quint64 ioBytes = 0;    // lectura + escritura acumuladas
    bool kernel = false;
    // Calculado entre dos muestras
    double cpu = 0;         // % del total del equipo
    double disk = 0;        // bytes/s
    double net = 0;         // bytes/s
    double gpu = 0;         // % del motor de GPU más usado por el proceso
    QString gpuEngine;      // "GPU 0 - 3D"
};

// Datos fijos de una tarjeta gráfica
struct GpuCard {
    QString card, pdev, name, driver, driverVersion, location;
    double dedicatedTotal = 0;
    bool integrated = false;
    bool measurable = false;   // el controlador informa del uso (fdinfo, gpu_busy_percent o nvidia-smi)
    int nvidiaIndex = -1;
};

// Lee el sistema (CPU, memoria, discos, red, procesos) cada cierto tiempo.
// Todo sale de /proc y /sys: no lanza procesos en cada muestra.
class SysMon : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int interval READ interval WRITE setInterval NOTIFY intervalChanged)
    Q_PROPERTY(bool paused READ paused WRITE setPaused NOTIFY intervalChanged)
    Q_PROPERTY(double cpu READ cpu NOTIFY updated)
    Q_PROPERTY(QVariantList cpuHistory READ cpuHistory NOTIFY updated)
    Q_PROPERTY(QVariantList coreUsage READ coreUsage NOTIFY updated)
    Q_PROPERTY(QVariantList coreHistory READ coreHistory NOTIFY updated)
    Q_PROPERTY(QString openGLVersion READ openGLVersion NOTIFY glChanged)
    Q_PROPERTY(QVariantMap cpuInfo READ cpuInfo CONSTANT)
    Q_PROPERTY(QVariantMap cpuStats READ cpuStats NOTIFY updated)
    Q_PROPERTY(QVariantMap memory READ memory NOTIFY updated)
    Q_PROPERTY(QVariantList memHistory READ memHistory NOTIFY updated)
    Q_PROPERTY(QVariantList disks READ disks NOTIFY updated)
    Q_PROPERTY(QVariantList nets READ nets NOTIFY updated)
    Q_PROPERTY(QVariantList gpus READ gpus NOTIFY updated)
    Q_PROPERTY(double diskTotal READ diskTotal NOTIFY updated)
    Q_PROPERTY(double netTotal READ netTotal NOTIFY updated)
    Q_PROPERTY(QVariantList users READ users NOTIFY updated)
    Q_PROPERTY(QString userName READ userName CONSTANT)

public:
    explicit SysMon(QObject *parent = nullptr);
    ~SysMon() override;

    int interval() const { return m_timer.interval(); }
    void setInterval(int ms);
    bool paused() const { return !m_timer.isActive(); }
    void setPaused(bool p);

    double cpu() const { return m_cpu; }
    QVariantList cpuHistory() const { return m_cpuHistory; }
    QVariantList coreUsage() const { return m_coreUsage; }
    QVariantList coreHistory() const;
    QString openGLVersion() const { return m_glVersion; }
    QVariantMap cpuInfo() const { return m_cpuInfo; }
    QVariantMap cpuStats() const { return m_cpuStats; }
    QVariantMap memory() const { return m_memory; }
    QVariantList memHistory() const { return m_memHistory; }
    QVariantList disks() const { return m_disks; }
    QVariantList nets() const { return m_nets; }
    QVariantList gpus() const { return m_gpus; }
    double diskTotal() const { return m_diskTotal; }
    double netTotal() const { return m_netTotal; }
    QVariantList users() const { return m_users; }
    QString userName() const;

    const QHash<int, ProcInfo> &processes() const { return m_procs; }
    quint64 memTotalBytes() const { return m_memTotal; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE QString formatBytes(double bytes) const;
    Q_INVOKABLE QString formatRate(double bytesPerSec) const;   // en bits, como Windows (Kbps / Mbps)

Q_SIGNALS:
    void updated();
    void intervalChanged();
    void glChanged();

private:
    void sampleCpu(double secs);
    void sampleMemory();
    void sampleDisks(double secs);
    void sampleNets(double secs);
    void sampleGpus(double secs);
    void loadGpuInfo();
    void startNvidia();
    void sampleProcesses(double secs);
    void loadCpuInfo();
    void startNetHelper();
    static void push(QVariantList &history, double v);

    QTimer m_timer;
    qint64 m_lastSample = 0;

    // CPU
    QVector<quint64> m_prevTotal, m_prevIdle;   // [0] = total, [1..] = núcleos
    double m_cpu = 0;
    quint64 m_cpuTotalDelta = 0;
    QVariantList m_cpuHistory, m_coreUsage;
    QVariantMap m_cpuInfo, m_cpuStats;

    // Memoria
    quint64 m_memTotal = 0;
    QVariantMap m_memory;
    QVariantList m_memHistory;

    // Discos y red
    struct IoPrev { quint64 a = 0, b = 0, c = 0, ios = 0, ms = 0; };
    QHash<QString, IoPrev> m_diskPrev, m_netPrev;
    QHash<QString, QVariantList> m_diskHist, m_diskReadHist, m_diskWriteHist, m_netHist, m_netSendHist;
    QVariantList m_disks, m_nets, m_gpus;
    QHash<QString, QVariantList> m_gpuHist;
    QList<GpuCard> m_gpuCards;
    // Clientes DRM (fdinfo): pid -> descriptores de /dev/dri, y contadores anteriores por cliente
    QHash<int, QList<int>> m_drmFds;
    QHash<int, qint64> m_drmScan;
    QHash<QString, QHash<QString, quint64>> m_clientPrev;
    QString m_glVersion;
    QProcess *m_nvidia = nullptr;
    QHash<int, QStringList> m_nvidiaData;
    QVector<QVariantList> m_coreHist;
    double m_physicalRam = 0;
    double m_diskTotal = 0, m_netTotal = 0;

    // Procesos
    QHash<int, ProcInfo> m_procs;
    QVariantList m_users;
    long m_pageSize = 4096;
    long m_hz = 100;

    // Red por proceso (ayudante de KDE con permiso de captura)
    QProcess *m_netHelper = nullptr;
    QHash<int, double> m_netByPid;
};
