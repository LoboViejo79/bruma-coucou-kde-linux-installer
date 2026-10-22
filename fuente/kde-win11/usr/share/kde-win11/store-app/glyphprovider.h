#pragma once

#include <QJsonDocument>
#include <QJsonObject>
#include <QPainter>
#include <QPainterPath>
#include <QQuickImageProvider>
#include <QSvgRenderer>
#include <QUrl>

// image://glyph/<JSON>: dibuja un icono de línea (rutas SVG en una rejilla de 24×24) con QSvgRenderer.
// Con antialiasing y en cualquier tarjeta gráfica (los Shape de Qt Quick pierden trazos rectos en algunas).
// Claves: d (ruta de trazo), c (color), w (grosor), f (relleno de d, opcional), d2/c2 (detalles, opcional)
class GlyphProvider : public QQuickImageProvider
{
public:
    GlyphProvider()
        : QQuickImageProvider(QQuickImageProvider::Image)
    {
    }

    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override
    {
        const QJsonObject o = QJsonDocument::fromJson(QUrl::fromPercentEncoding(id.toUtf8()).toUtf8()).object();
        const int w = requestedSize.width() > 0 ? requestedSize.width() : 48;
        const int h = requestedSize.height() > 0 ? requestedSize.height() : w;
        const QString color = o.value(QStringLiteral("c")).toString(QStringLiteral("#ffffff"));
        const double stroke = o.value(QStringLiteral("w")).toDouble(1.5);
        const QString fill = o.value(QStringLiteral("f")).toString();
        QString svg = QStringLiteral("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'>");
        svg += QStringLiteral("<path d='%1' fill='%2' stroke='%3' stroke-width='%4' stroke-linecap='round' stroke-linejoin='round'/>")
                   .arg(o.value(QStringLiteral("d")).toString(), fill.isEmpty() ? QStringLiteral("none") : fill,
                        fill.isEmpty() ? color : QStringLiteral("none"), QString::number(stroke));
        const QString d2 = o.value(QStringLiteral("d2")).toString();
        if (!d2.isEmpty())
            svg += QStringLiteral("<path d='%1' fill='none' stroke='%2' stroke-width='%3' stroke-linecap='round' stroke-linejoin='round'/>")
                       .arg(d2, o.value(QStringLiteral("c2")).toString(color), QString::number(o.value(QStringLiteral("w2")).toDouble(stroke)));
        svg += QStringLiteral("</svg>");

        QImage img(w, h, QImage::Format_ARGB32_Premultiplied);
        img.fill(Qt::transparent);
        QSvgRenderer renderer(svg.toUtf8());
        QPainter p(&img);
        p.setRenderHint(QPainter::Antialiasing);
        renderer.render(&p);
        p.end();
        if (size)
            *size = img.size();
        return img;
    }
};

// image://avatar/<url de archivo>: la foto de perfil recortada en círculo (como en Windows)
class AvatarProvider : public QQuickImageProvider
{
public:
    AvatarProvider()
        : QQuickImageProvider(QQuickImageProvider::Image)
    {
    }

    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override
    {
        const int s = requestedSize.width() > 0 ? requestedSize.width() : 128;
        QImage src(QUrl(QUrl::fromPercentEncoding(id.toUtf8())).toLocalFile());
        QImage out(s, s, QImage::Format_ARGB32_Premultiplied);
        out.fill(Qt::transparent);
        if (!src.isNull()) {
            src = src.scaled(s, s, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation);
            QPainter p(&out);
            p.setRenderHint(QPainter::Antialiasing);
            QPainterPath circle;
            circle.addEllipse(0, 0, s, s);
            p.setClipPath(circle);
            p.drawImage((s - src.width()) / 2, (s - src.height()) / 2, src);
        }
        if (size)
            *size = out.size();
        return out;
    }
};
