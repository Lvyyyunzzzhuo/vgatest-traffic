#include "logwidget.h"
#include "ui_logwidget.h"
#include "signup.h"

#include <QGraphicsDropShadowEffect>
LogWidget::LogWidget(QWidget *parent)
    : QWidget(parent)
    , ui(new Ui::LogWidget)
{
    ui->setupUi(this);
    //设置图片

    QPixmap *pix = new QPixmap(":/loginbackground.png");
    QSize sz = ui->label_image->size();
    ui->label_image->setPixmap(pix->scaled(sz));

    //设置图片阴影效果
    QGraphicsDropShadowEffect *shadow = new QGraphicsDropShadowEffect(this);
    shadow->setOffset(-3, 0);
    shadow->setColor(QColor("#888888"));
    shadow->setBlurRadius(30);
    ui->label_image->setGraphicsEffect(shadow);

    // connect 3个信号槽
    // 触发重置按钮的信号槽连接
    connect(ui->btn_clear,SIGNAL(clicked()),this,SLOT(btn_clear_clicked()));
    // 触发登录按钮的信号槽连接
    connect(ui->btn_log,SIGNAL(clicked()),this,SLOT(btn_log_clicked()));
    // 发出信号后关闭登录窗口的信号槽连接
    connect(this,SIGNAL(close_window()),this,SLOT(close()));

}

//先编写一个数据库初始化函数，每次需要对数据库进行操作的时候都需要先调用它进行初始化。
void sqlite_Init()
{

    QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE");
    db.setDatabaseName("user.db");
    if(!db.open())
    {
        qDebug()<<"open error";
    }
    //create excle
    QString createsql=QString("create table if not exists user(id integer primary key autoincrement,"
                                "username ntext unique not NULL,"
                                "password ntext not NULL)");
    QSqlQuery query;
    if(!query.exec(createsql)){
        qDebug()<<"table create error";
    }
    else{
        qDebug()<<"table create success";
    }
}

void LogWidget::on_btn_clear_clicked()
{
    ui->edit_pw->clear();
    ui->edit_name->clear();
}

// 登录按钮触发事件
void LogWidget::on_btn_log_clicked()
{
    sqlite_Init();

    QString username = ui->edit_name->text();
    QString password = ui->edit_pw->text();
    QString sql=QString("select * from user where username='%1' and password='%2'")
                      .arg(username).arg(password);
    //创建执行语句对象
    QSqlQuery query(sql);
    //判断执行结果
    if(!query.next())
    {
        qDebug()<<"Login error";
        QMessageBox::information(this,"登录认证","登录失败,账户或者密码错误");
        return;
    }
    else
    {
        qDebug()<<"Login success";
        QMessageBox::information(this,"登录认证","登录成功");
        //登录成功后可以跳转到其他页面
        QWidget *w = new QWidget;
        w->show();
        this->close();

    }
    // 发出登录信号
    emit(login());
    // 发出关闭窗口信号
    emit(close_window());
}

LogWidget::~LogWidget()
{
    delete ui;
}

void LogWidget::on_btn_signup_clicked()
{
    this->close();
    Signup *s = new Signup;
    s->show();
}



