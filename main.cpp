#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QDir>
#include "serialreader.h"
#include "voicecontroller.h"


int main(int argc, char *argv[])
{   
    QGuiApplication app(argc, argv);
    QQuickStyle::setStyle("Basic");
    QQmlApplicationEngine engine;

    QString exePath = QCoreApplication::applicationDirPath();
    QString dbPath = QDir::cleanPath(exePath + "/Database");

    QDir dir;
    if (!dir.exists(dbPath)) {
        dir.mkpath(dbPath);
    }
    engine.setOfflineStoragePath(dbPath);


    SerialReader serialService;
    VoiceController voiceController;



    engine.rootContext()->setContextProperty("sensorData", &serialService);
    engine.rootContext()->setContextProperty("VoiceController", &voiceController);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("proj1", "Main");

    return app.exec();
}
