#ifndef SERIALREADER_H
#define SERIALREADER_H

#include <QObject>
#include <QSerialPort>
#include <QSerialPortInfo>

class SerialReader : public QObject
{
    Q_OBJECT
    Q_PROPERTY(double roll READ roll NOTIFY rollChanged)
    Q_PROPERTY(double pitch READ pitch NOTIFY pitchChanged)

public:
    explicit SerialReader(QObject *parent = nullptr);

    double roll() const { return m_roll; }
    double pitch() const { return m_pitch; }

public slots:
    void startSerial();

signals:
    void rollChanged();
    void pitchChanged();

private slots:
    void handleReadyRead();

private:
    QSerialPort *m_serial;
    double m_roll = 0.0;
    double m_pitch = 0.0;
    QByteArray m_buffer;

    void parseData(const QByteArray &data);
};

#endif
