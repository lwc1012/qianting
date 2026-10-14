#include "VoiceController.h"
#include <QDir>
#include <QStandardPaths>
#include <QCoreApplication>
#include <QMediaFormat>
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkRequest>
#include <QDebug>

VoiceController::VoiceController(QObject *parent)
    : QObject(parent),
    m_whisperProcess(new QProcess(this)),
    m_llamaProcess(new QProcess(this)),
    m_networkManager(new QNetworkAccessManager(this))
{
    QString baseDir = QCoreApplication::applicationDirPath();
    QString llamaDir;

    if (QDir(baseDir + "/llama-bin").exists()) {
        llamaDir = baseDir + "/llama-bin";
    } else if (QDir(baseDir + "/../llama-bin").exists()) {
        llamaDir = QDir::cleanPath(baseDir + "/../llama-bin");
    } else if (QDir(baseDir + "/../../llama-bin").exists()) {
        llamaDir = QDir::cleanPath(baseDir + "/../../llama-bin");
    } else {
        llamaDir = "D:/CodeField/Qt/proj1/llama-bin";
    }

    QString llamaExe = llamaDir + "/llama-server.exe";
    QString modelPath = llamaDir + "/models/Qwen3-4B-Q4_K_M.gguf";

    QStringList llamaArgs;
    llamaArgs << "-m" << modelPath
              << "--host" << "127.0.0.1"
              << "--port" << "8080"
              << "-c" << "4096";

    QProcess nvSmiProcess;
    nvSmiProcess.start("nvidia-smi");
    nvSmiProcess.waitForFinished(1000);

    if (nvSmiProcess.exitStatus() == QProcess::NormalExit && nvSmiProcess.exitCode() == 0) {
        qDebug() << "[环境检测] 发现支持 CUDA 的 NVIDIA GPU，启用显卡硬件加速。";
        llamaArgs << "-ngl" << "99"; // 将模型全部层卸载到 GPU 显存
    } else {
        qDebug() << "[环境检测] 未检测到 NVIDIA GPU 或驱动，已自动降级为 CPU 推理模式。";
        llamaArgs << "-ngl" << "0";  // 使用纯 CPU 模式计算
    }

    m_llamaProcess->start(llamaExe, llamaArgs);
    m_audioInput = new QAudioInput(this);
    m_recorder = new QMediaRecorder(this);

    m_session.setAudioInput(m_audioInput);
    m_session.setRecorder(m_recorder);

    QMediaFormat format;
    format.setFileFormat(QMediaFormat::Wave);
    format.setAudioCodec(QMediaFormat::AudioCodec::Wave);
    m_recorder->setMediaFormat(format);

    m_recorder->setAudioSampleRate(16000);
    m_recorder->setAudioChannelCount(1);

    connect(m_recorder, &QMediaRecorder::recorderStateChanged, this, [this](QMediaRecorder::RecorderState state) {
        if (state == QMediaRecorder::RecordingState) {
            qDebug() << "----麦克风录音已开始...----";
            emit recordingStarted();
        } else if (state == QMediaRecorder::StoppedState) {
            qDebug() << "麦克风录音已结束，文件保存在:" + m_currentFilePath;
            emit recordingFinished(m_currentFilePath);
            runWhisper(m_currentFilePath);
        }
    });

    connect(m_recorder, &QMediaRecorder::errorChanged, this, [this]() {
        qDebug() << "[错误] 录音失败: " + m_recorder->errorString();
    });

    connect(m_whisperProcess, &QProcess::finished, this, &VoiceController::onWhisperFinished);

    connect(m_whisperProcess, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        QString errorMsg = "Whisper 进程异常，错误码: " + QString::number(error) + " | " + m_whisperProcess->errorString();
        qDebug() << "[Whisper Error]" << errorMsg;
    });
}

VoiceController::~VoiceController()
{
    if (m_llamaProcess && m_llamaProcess->state() == QProcess::Running) {
        m_llamaProcess->kill();
        m_llamaProcess->waitForFinished(3000);
    }
}

void VoiceController::startRecording()
{
    QString baseDir = QCoreApplication::applicationDirPath();
    QString recordDirPath = QDir::cleanPath(baseDir + "/voiceRecord");

    qDebug() << "[Debug] 准备保存录音的目录:" << recordDirPath;


    QDir dir;
    if (!dir.exists(recordDirPath)) {
        dir.mkpath(recordDirPath);
    }

    QDir recordDir(recordDirPath);
    recordDir.setNameFilters(QStringList() << "*.wav");
    recordDir.setFilter(QDir::Files | QDir::NoSymLinks);
    recordDir.setSorting(QDir::Name);

    QFileInfoList fileList = recordDir.entryInfoList();
    const int MAX_RECORDINGS = 20;

    if (fileList.size() >= MAX_RECORDINGS) {
        int deleteCount = fileList.size() - MAX_RECORDINGS + 1;

        for (int i = 0; i < deleteCount; ++i) {
            QString fileToDelete = fileList.at(i).absoluteFilePath();
            QFile::remove(fileToDelete);

            qDebug() << "[系统] 自动清理过期录音: " + fileList.at(i).fileName();
        }
    }

    QString timeStamp = QDateTime::currentDateTime().toString("yyyy-MM-dd_HH-mm-ss");
    m_currentFilePath = recordDirPath + "/" + timeStamp + ".wav";

    m_recorder->setOutputLocation(QUrl::fromLocalFile(m_currentFilePath));
    m_recorder->record();
}

void VoiceController::stopRecordingAndProcess()
{
    m_recorder->stop();
}

void VoiceController::runWhisper(const QString &audioPath)
{
    qDebug() << "[系统] 正在启动 Whisper 语音识别...";

    QString baseDir = QCoreApplication::applicationDirPath();
    QString whisperDir;

    if (QDir(baseDir + "/whisper-blas-bin-x64").exists()) {
        whisperDir = baseDir + "/whisper-blas-bin-x64";
    }
    else if (QDir(baseDir + "/../whisper-blas-bin-x64").exists()) {
        whisperDir = QDir::cleanPath(baseDir + "/../whisper-blas-bin-x64");
    }
    else if (QDir(baseDir + "/../../whisper-blas-bin-x64").exists()) {
        whisperDir = QDir::cleanPath(baseDir + "/../../whisper-blas-bin-x64");
    }
    else {
        whisperDir = "D:/CodeField/Qt/proj1/whisper-blas-bin-x64";
        qDebug() << "[警告] 相对路径探测失败，启用本地绝对路径，打包部署前请注意检查。";
    }

    QString whisperExe = whisperDir + "/whisper-cli.exe";
    QString modelPath = whisperDir + "/models/ggml-large-v3-turbo-q5_0.bin";

    qDebug() << "=======================================";
    qDebug() << "[Debug] 最终采用的 Whisper EXE 路径:" << whisperExe;
    qDebug() << "[Debug] 最终采用的 Model 路径:" << modelPath;
    qDebug() << "=======================================";

    QStringList arguments;
    arguments << "-m" << modelPath
              << "-f" << audioPath
              << "-l" << "zh"
              << "-nt";

    m_whisperProcess->start(whisperExe, arguments);
}

void VoiceController::onWhisperFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    QByteArray errorOutput = m_whisperProcess->readAllStandardError();
    QString whisperStderr = QString::fromUtf8(errorOutput).trimmed();

    if (!whisperStderr.isEmpty()) {
        qDebug() << "\n>>> [Whisper 内部报错/日志] >>>";
        qDebug().noquote() << whisperStderr;
        qDebug() << "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n";
    }

    if (exitStatus == QProcess::CrashExit || exitCode != 0) {
        qDebug() << "[Whisper Error] 进程退出码:" << exitCode << "状态:" << exitStatus;
        return;
    }

    QString transcribedText = QString::fromUtf8(m_whisperProcess->readAllStandardOutput()).trimmed();

    qDebug() << "\n>>> [Whisper Transcribed Text] >>>";
    qDebug().noquote() << transcribedText;
    qDebug() << "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n";

    if (transcribedText.isEmpty()) {
        qDebug() << "[错误] 未能从音频中识别出有效文字.\n";
        return;
    }

    askLlamaServer(transcribedText);
}

void VoiceController::askLlamaServer(const QString &transcribedText)
{
    qDebug() << "正在调用本地 Qwen3 模型进行语义抽取...\n";

    QNetworkRequest request(QUrl("http://127.0.0.1:8080/v1/chat/completions"));
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    QString prompt = R"(You are a data extraction engine for a lifeboat system. Extract parameters from the user's Chinese voice-to-text transcript and output STRICTLY a pure JSON object. Do not include any Markdown formatting (e.g., ```json), code blocks, or additional explanations.

Extraction Rules:
1. "status" (integer): Map "水面" to 0; map "水中" to 1.
2. "ballast" (object): Extract capacities (numbers only, unit is liter) for water cabins. Handle voice typos like "守卫舱" for Command Cabin.
   - "t1": 救生舱1
   - "t2": 救生舱2
   - "t3": 救生舱3
   - "t4": 救生舱4
   - "t5": 救生舱5
   - "t6": 救生舱6
   - "t7": 救生舱7
   - "t8": 救生舱8
   - "tCmd1": 指挥舱1
   - "tCmd2": 指挥舱2
3. "leads" (object): Extract the number of lead blocks (numbers only). Handle voice typos like "压载铅" for lead blocks.
   - "l1": 位置1/船头
   - "l2": 位置2/船中
   - "l3": 位置3/船尾
4. "personnel" (array of objects): Extract details for each rescued person.
   - "weight" (number): Body weight(kg)
   - "pos" (number): Seat position number

Important: If a parameter is not mentioned in the text, omit it from the JSON.

Example Output Format:
{"status": 1, "ballast": {"t1": 50, "t2": 71, "t3": 69, "t4": 83, "t5": 50, "t6": 71, "t7": 69, "t8": 83, "tCmd1": 215, "tCmd2": 215}, "leads": {"l1": 3, "l2": 18, "l3": 1}, "personnel": [{"weight": 75, "pos": 3}, {"weight": 66, "pos": 2}]})";

    QJsonObject json;
    QJsonArray messages;
    QJsonObject systemMsg;
    systemMsg["role"] = "system";
    systemMsg["content"] = prompt;
    messages.append(systemMsg);

    QJsonObject userMsg;
    userMsg["role"] = "user";
    userMsg["content"] = "User text:" + transcribedText;
    messages.append(userMsg);

    json["messages"] = messages;
    json["stream"] = false;
    json["temperature"]= 0.6;

    QJsonObject responseFormat;
    responseFormat["type"]="json_object";
    json["response_format"]=responseFormat;

    QJsonDocument doc(json);
    QNetworkReply *reply = m_networkManager->post(request, doc.toJson());
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onLlamaReplyFinished(reply);
    });
}

void VoiceController::onLlamaReplyFinished(QNetworkReply *reply)
{
    if (reply->error() != QNetworkReply::NoError) {
        qDebug() << "[Llama Server Error]" << reply->errorString();
        reply->deleteLater();
        return;
    }

    QByteArray responseData = reply->readAll();
    QJsonDocument jsonDoc = QJsonDocument::fromJson(responseData);
    QJsonObject rootObj = jsonDoc.object();

    QString responseText;
    QJsonArray choices = rootObj.value("choices").toArray();
    if (!choices.isEmpty()) {
        QJsonObject message = choices.first().toObject().value("message").toObject();
        responseText = message.value("content").toString();
    }

    qDebug().noquote() << "\n========== [Llama.cpp 响应详情] ==========";
    qDebug().noquote() << "【最终答复】:\n" << responseText;
    qDebug().noquote() << "=======================================\n";

    qDebug().noquote() << "qwen返回的内容:\n" << responseText;
    emit parametersExtracted(responseText);

    reply->deleteLater();
}
