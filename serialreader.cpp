#include "SerialReader.h"
#include <QDebug>
#include <QRegularExpression>

SerialReader::SerialReader(QObject *parent) : QObject(parent)
{
    m_serial = new QSerialPort(this);
    connect(m_serial, &QSerialPort::readyRead, this, &SerialReader::handleReadyRead);
    startSerial();
}

void SerialReader::startSerial()
{
    QString targetPortName = "";
    const QList<QSerialPortInfo> availablePorts = QSerialPortInfo::availablePorts();

    qDebug() << "=== 开始扫描系统串口 ===";
    for (const QSerialPortInfo &info : availablePorts) {
        if (info.hasVendorIdentifier() && info.hasProductIdentifier()) {

            if (info.vendorIdentifier() == 0x1A86 && info.productIdentifier() == 0x7523) {
                targetPortName = info.portName();
                qDebug() << ">>> [硬件锁定] 成功精准识别到倾角仪设备，所在端口:" << targetPortName;
                break;
            }
        }
    }

    if (targetPortName.isEmpty()) {
        qDebug() << "错误：未检测到倾角仪硬件（VID:1A86, PID:7523）。请检查设备是否正常插入 USB 接口！";
        return;
    }

    m_serial->setPortName(targetPortName);
    m_serial->setBaudRate(QSerialPort::Baud9600);
    m_serial->setDataBits(QSerialPort::Data8);
    m_serial->setParity(QSerialPort::NoParity);
    m_serial->setStopBits(QSerialPort::OneStop);
    m_serial->setFlowControl(QSerialPort::NoFlowControl);

    if (m_serial->open(QIODevice::ReadOnly)) {
        qDebug() << "成功连接到倾角仪串口:" << targetPortName;
    } else {
        qDebug() << "打开串口失败:" << targetPortName << " 错误原因:" << m_serial->errorString();
    }
}

void SerialReader::handleReadyRead()
{
    QByteArray rawData = m_serial->readAll();
    qDebug() << "COM4原始数据:" << rawData;
    m_buffer.append(rawData);

    while (m_buffer.contains('\n')) {

        int lineEndIndex = m_buffer.indexOf('\n');
        QString line = QString::fromLatin1(m_buffer.left(lineEndIndex)).trimmed();
        m_buffer.remove(0, lineEndIndex + 1);
        static QRegularExpression regex("X:\\s*([+-]?\\d*\\.?\\d+)\\s*DEG,Y:\\s*([+-]?\\d*\\.?\\d+)\\s*DEG");
        QRegularExpressionMatch match = regex.match(line);

        if (match.hasMatch()) {
            double newRoll = match.captured(1).toDouble();
            double newPitch = match.captured(2).toDouble();

            if (!qFuzzyCompare(m_roll, newRoll)) {
                m_roll = newRoll;
                emit rollChanged();
            }
            if (!qFuzzyCompare(m_pitch, newPitch)) {
                m_pitch = newPitch;
                emit pitchChanged();
            }
            //qDebug() << "Parsed -> Roll:" << m_roll << " Pitch:" << m_pitch;
        }
    }
}
