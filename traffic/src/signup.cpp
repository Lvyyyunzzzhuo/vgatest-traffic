#include "signup.h"
#include "ui_signup.h"

#include "logwidget.h"

Signup::Signup(QWidget *parent)
    : QWidget(parent)
    , ui(new Ui::Signup)
{
    ui->setupUi(this);
    //设置图片
    QPixmap *pix = new QPixmap(":/girl.jpg");
    QSize sz = ui->label_image->size();
    ui->label_image->setPixmap(pix->scaled(sz));
}

Signup::~Signup()
{
    delete ui;
}

void Signup::on_btn_return_clicked()
{
    LogWidget * m_log;
    m_log = new LogWidget;
    // 调用登录窗口的show()函数显示登录界面
    m_log->show();
    this->close();

}


void Signup::on_Sure_clicked()
{
    sqlite_Init();
    QString username = ui->lineEdit_username->text();
    QString password = ui->lineEdit_passwd->text();
    QString surepass = ui->lineEdit_surepasswd->text();
    //判断密码是否一致
    if(password == surepass)
    {
        QString sql=QString("insert into user(username,password) values('%1','%2');")
        .arg(username).arg(password);
        //创建执行语句对象
        QSqlQuery query;
        //判断执行结果
        if(!query.exec(sql))
        {
            qDebug()<<"insert into error";
            QMessageBox::information(this,"注册认证","插入失败！");
        }
        else
        {
            qDebug()<<"insert into success";
            QMessageBox::information(this,"注册认证","插入成功！");
            LogWidget * m_log;
            m_log = new LogWidget;
            m_log->show();
            this->close();
        }

    }else{
        QMessageBox::information(this,"注册认证","两次密码输入不一致");
    }


}

