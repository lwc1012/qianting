#ifndef VOICECONTROLLER_H
#define VOICECONTROLLER_H

#include <QObject>
#include <QMediaCaptureSession>
#include <QAudioInput>
#include <QMediaRecorder>
#include <QUrl>
#include <QString>
#include <QProcess>
#include <QNetworkAccessManager>
#include <QNetworkReply>

class VoiceController : public QObject
{
    Q_OBJECT

public:
    explicit VoiceController(QObject *parent = nullptr);
    ~VoiceController();
    Q_INVOKABLE void startRecording();
    Q_INVOKABLE void stopRecordingAndProcess();

signals:
    void recordingStarted();
    void recordingFinished(const QString &filePath);
    void logMessage(const QString &msg);
    void parametersExtracted(const QString &jsonData);

private slots:
    void onWhisperFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void onLlamaReplyFinished(QNetworkReply *reply);

private:
    void runWhisper(const QString &audioPath);
    void askLlamaServer(const QString &transcribedText);

    QMediaCaptureSession m_session;
    QAudioInput *m_audioInput;
    QMediaRecorder *m_recorder;
    QString m_currentFilePath;

    QProcess *m_whisperProcess;
    QProcess *m_llamaProcess;
    QNetworkAccessManager *m_networkManager;
};

#endif
