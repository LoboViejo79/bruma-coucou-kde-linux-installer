#pragma once

#include <KService>
#include <QColor>
#include <QHash>
#include <QList>
#include <QObject>
#include <QUrl>
#include <QVariantList>

// "¿Cómo quieres abrir este archivo?" de Windows 11: apps para el tipo del archivo, la actual,
// el resto de apps instaladas, "Siempre" (la deja como predeterminada) y "Solo una vez".
class OpenWith : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString title READ title CONSTANT)
    Q_PROPERTY(QString fileName READ fileName CONSTANT)
    Q_PROPERTY(QString fileIcon READ fileIcon CONSTANT)
    Q_PROPERTY(QString typeName READ typeName CONSTANT)
    Q_PROPERTY(QVariantMap current READ current CONSTANT)
    Q_PROPERTY(QVariantList suggested READ suggested CONSTANT)
    Q_PROPERTY(QVariantList others READ others CONSTANT)
    Q_PROPERTY(bool dark READ dark CONSTANT)
    Q_PROPERTY(QColor accent READ accent CONSTANT)

public:
    explicit OpenWith(const QList<QUrl> &urls, QObject *parent = nullptr);

    QString title() const;
    QString fileName() const;
    QString fileIcon() const { return m_fileIcon; }
    QString typeName() const { return m_typeName; }
    QVariantMap current() const { return m_current; }
    QVariantList suggested() const { return m_suggested; }
    QVariantList others() const { return m_others; }
    bool dark() const { return m_dark; }
    QColor accent() const { return m_accent; }

    // Abre los archivos con la app; con always=true además la deja como predeterminada del tipo
    Q_INVOKABLE void open(const QString &id, bool always);
    // "Buscar otra aplicación en este equipo": elige un ejecutable y devuelve su entrada (o vacía)
    Q_INVOKABLE QVariantMap browse();

Q_SIGNALS:
    void failed(const QString &message);

private:
    QVariantMap entry(const KService::Ptr &service) const;
    KService::Ptr service(const QString &id) const;

    QList<QUrl> m_urls;
    QString m_mime;
    QString m_fileIcon;
    QString m_typeName;
    QVariantMap m_current;
    QVariantList m_suggested;
    QVariantList m_others;
    QHash<QString, KService::Ptr> m_extra; // apps elegidas con "Buscar otra aplicación"
    bool m_dark = false;
    QColor m_accent;
};
