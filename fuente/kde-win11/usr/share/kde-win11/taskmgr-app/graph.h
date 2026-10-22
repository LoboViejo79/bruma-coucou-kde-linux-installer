#pragma once

#include <QPainter>
#include <QPainterPath>
#include <QQuickPaintedItem>

// Gráfica de Rendimiento de Windows 11: rejilla, línea de color y relleno translúcido.
// values: historial (el último a la derecha); max: tope del eje (0 = automático).
// values2: segunda serie opcional en línea discontinua (p. ej. "Enviar" en red).
class Graph : public QQuickPaintedItem
{
    Q_OBJECT
    Q_PROPERTY(QVariantList values MEMBER m_values WRITE setValues NOTIFY changed)
    Q_PROPERTY(QVariantList values2 MEMBER m_values2 WRITE setValues2 NOTIFY changed)
    Q_PROPERTY(double max MEMBER m_max NOTIFY changed)
    Q_PROPERTY(QColor color MEMBER m_color NOTIFY changed)
    Q_PROPERTY(QColor gridColor MEMBER m_grid NOTIFY changed)
    Q_PROPERTY(bool grid MEMBER m_showGrid NOTIFY changed)
    Q_PROPERTY(bool border MEMBER m_border NOTIFY changed)
    Q_PROPERTY(double autoMax READ autoMax NOTIFY changed)
    Q_PROPERTY(double minScale MEMBER m_minScale NOTIFY changed)   // tope mínimo del eje automático

public:
    explicit Graph(QQuickItem *parent = nullptr)
        : QQuickPaintedItem(parent)
    {
        setAntialiasing(true);
        connect(this, &Graph::changed, this, [this] { update(); });
    }

    void setValues(const QVariantList &v) { m_values = v; Q_EMIT changed(); }
    void setValues2(const QVariantList &v) { m_values2 = v; Q_EMIT changed(); }

    // Tope "redondo" para series sin máximo fijo (red, velocidad de disco)
    double autoMax() const
    {
        if (m_max > 0)
            return m_max;
        double peak = m_minScale;
        for (const QVariant &v : m_values) peak = qMax(peak, v.toDouble());
        for (const QVariant &v : m_values2) peak = qMax(peak, v.toDouble());
        double step = 1;
        while (step * 10 <= peak) step *= 10;
        for (double m : {1.0, 2.0, 5.0, 10.0})
            if (peak <= step * m) return step * m;
        return step * 10;
    }

    void paint(QPainter *p) override
    {
        const QRectF r = boundingRect().adjusted(0.5, 0.5, -0.5, -0.5);
        p->setRenderHint(QPainter::Antialiasing, true);
        QColor fill = m_color;
        fill.setAlphaF(0.14);
        if (m_showGrid) {
            QPen gp(m_grid, 1);
            p->setPen(gp);
            for (int i = 1; i < 10; ++i) {
                const double y = r.top() + r.height() * i / 10.0;
                p->drawLine(QPointF(r.left(), y), QPointF(r.right(), y));
            }
            for (int i = 1; i < 20; ++i) {
                const double x = r.left() + r.width() * i / 20.0;
                p->drawLine(QPointF(x, r.top()), QPointF(x, r.bottom()));
            }
        }
        const double top = autoMax();
        auto path = [&](const QVariantList &vals) {
            QPainterPath line;
            const int n = vals.size();
            for (int i = 0; i < n; ++i) {
                const double x = r.left() + (n > 1 ? r.width() * i / (n - 1) : 0);
                const double v = qBound(0.0, vals[i].toDouble() / top, 1.0);
                const QPointF pt(x, r.bottom() - v * r.height());
                i ? line.lineTo(pt) : line.moveTo(pt);
            }
            return line;
        };
        if (m_values.size() > 1) {
            QPainterPath line = path(m_values);
            QPainterPath area = line;
            area.lineTo(r.right(), r.bottom());
            area.lineTo(r.left(), r.bottom());
            area.closeSubpath();
            p->fillPath(area, fill);
            p->setPen(QPen(m_color, 1.3));
            p->drawPath(line);
        }
        if (m_values2.size() > 1) {
            QPen dash(m_color, 1.2, Qt::DashLine);
            p->setPen(dash);
            p->drawPath(path(m_values2));
        }
        if (m_border) {
            p->setPen(QPen(m_color, 1));
            p->setBrush(Qt::NoBrush);
            p->drawRect(r);
        }
    }

Q_SIGNALS:
    void changed();

private:
    QVariantList m_values, m_values2;
    double m_max = 100;
    double m_minScale = 0;
    QColor m_color = QColor(0x00, 0x78, 0xD4);
    QColor m_grid = QColor(0, 0, 0, 30);
    bool m_showGrid = true;
    bool m_border = true;
};
