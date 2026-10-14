#ifndef AIASSISTANT_H
#define AIASSISTANT_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QRegularExpression>

class AiAssistant : public QObject
{
    Q_OBJECT
    // 新增：专门用于 QML 显示的格式化属性（包含颜色信息）
    Q_PROPERTY(QString displayContent READ displayContent NOTIFY responseChanged)

public:
    explicit AiAssistant(QObject *parent = nullptr);

    Q_INVOKABLE void askAi(const QString &prompt);

    // 核心：根据当前是否有思考内容，返回组合后的 HTML 字符串
    QString displayContent() const {
        // 组合所有原始文本
        QString rawText = m_thought + m_response;
        if (rawText.isEmpty()) return "";

        // 将 \n 转换为 <br> 兼容 RichText，并处理思维链样式
        QString richText = rawText;

        // 处理已闭合的 <think>...</think> (变灰、斜体)
        richText.replace(QRegularExpression("<think>(.*?)</think>", QRegularExpression::DotMatchesEverythingOption),
                         "<i style='color: #888888;'>[思维链] \\1</i><br>");

        // 处理流式输出中尚未闭合的 <think> (确保正在思考的部分也是灰色的)
        if (richText.contains("<think>")) {
            richText.replace("<think>", "<i style='color: #888888;'>[正在思考...] ");
            // 如果没有匹配到闭合标签，就在末尾补全样式
            if (!richText.contains("</think>")) richText += "</i>";
        }

        // 将普通换行符转为 HTML 换行
        richText.replace("\n", "<br>");
        return richText;
    }

signals:
    void responseChanged();

private:
    QNetworkAccessManager *manager;
    QString m_response; // 存储正式回答
    QString m_thought;  // 存储思考内容 (CoT)
};

#endif // AIASSISTANT_H
