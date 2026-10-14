#include "aiassistant.h"
#include <QNetworkRequest>
#include <QJsonObject>
#include <QJsonDocument>
#include <QJsonArray>

AiAssistant::AiAssistant(QObject *parent) : QObject(parent)
{
    manager = new QNetworkAccessManager(this);
}

void AiAssistant::askAi(const QString &userPrompt)
{
    // 每次新提问时，先清空之前的回复
    m_response = "";
    m_thought = "";

    // 设置 API 地址 (Ollama 默认地址)
    QUrl url("http://localhost:11434/api/generate");
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    // 准备 JSON 数据
    QJsonObject json;
    json["model"] = "lifeboat-v5-8b5k-q4_k_m"; // 所选模型的名称，ollama list查看
    json["prompt"] = userPrompt;
    json["stream"] = true;
    json["keep_alive"] = "30m"; // 让模型在显存里待30分钟，避免频繁重新加载

    // 发送 POST 请求
    QNetworkReply *reply = manager->post(request, QJsonDocument(json).toJson());
    // 每当有一点数据传回来，这个 lambda 就会被触发
    connect(reply, &QNetworkReply::readyRead, this, [=]() {
        // 读取所有可用的数据
        while(reply->canReadLine()) {
            QByteArray line = reply->readLine();

            // 解析每一行 JSON (Ollama 流式返回的是一个个独立的 JSON 对象)
            QJsonDocument doc = QJsonDocument::fromJson(line);
            if (doc.isNull()) continue;
            QJsonObject obj = doc.object();

            // 1. 提取思维链 (CoT)
            // 注意：Ollama v0.5+ 针对支持思考的模型会返回这个字段
            if (obj.contains("reasoning_content")) {
                m_thought += obj.value("reasoning_content").toString();
                emit responseChanged();
            }

            // 2. 提取正式回答
            if (obj.contains("response")) {
                m_response += obj.value("response").toString();
                emit responseChanged();
            }

            // 检查是否结束
            if (obj.value("done").toBool()) {
                qDebug() << "AI 生成完毕";
            }
        }
    });

    // 处理结束和清理
    connect(reply, &QNetworkReply::finished, this, [=]() {
        if (reply->error() != QNetworkReply::NoError) {
            m_response = "Error: " + reply->errorString();
            emit responseChanged();
        }
        reply->deleteLater();
    });
}
