#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QSurfaceFormat>

#include <LayerShellQt/Window>

#include "NiriEventStream.h"

int main(int argc, char *argv[])
{
    // Alpha buffer must be requested before the QGuiApplication exists,
    // otherwise the layer-shell surface renders opaque black instead of
    // letting the compositor composite the transparent parts.
    QSurfaceFormat format = QSurfaceFormat::defaultFormat();
    format.setAlphaBufferSize(8);
    QSurfaceFormat::setDefaultFormat(format);

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("dynamic-island"));

    NiriEventStream niriEventStream;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("Niri"), &niriEventStream);
    engine.loadFromModule("DynamicIsland", "Island");

    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
    if (!window) {
        return -1;
    }

    // Must create() the native surface before it's ever shown, so the
    // layer-shell role is negotiated before Wayland assigns a default
    // xdg_toplevel role on first commit. Doing this after show() (or
    // relying on QML's `visible: true`) is why the window showed up as a
    // normal tiled window instead of an anchored strip.
    window->create();

    if (auto *layerWindow = LayerShellQt::Window::get(window)) {
        layerWindow->setLayer(LayerShellQt::Window::LayerTop);
        layerWindow->setAnchors(LayerShellQt::Window::AnchorTop);
        layerWindow->setExclusiveZone(-1);
        layerWindow->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
        layerWindow->setScope(QStringLiteral("dynamic-island"));
    }

    window->show();
    niriEventStream.start();

    return app.exec();
}
