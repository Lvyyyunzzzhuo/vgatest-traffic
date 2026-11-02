#ifndef LOGWIDGET_H
#define LOGWIDGET_H

#include <QWidget>

#include <QSqlDatabase> //数据驱动
#include <QSqlQuery> //数据库执行语句
#include <QMessageBox>//消息盒子
#include <QDebug>

void sqlite_Init();

namespace Ui {
class LogWidget;
}

class LogWidget : public QWidget
{
    Q_OBJECT

public:
    explicit LogWidget(QWidget *parent = nullptr);
    ~LogWidget();

signals:
    void login(); //登录主界面信号
    void close_window(); //关闭登录界面信号

private slots:
    void on_btn_signup_clicked();

    void on_btn_log_clicked();

    void on_btn_clear_clicked();

private:
    Ui::LogWidget *ui;
};

#endif // LOGWIDGET_H
