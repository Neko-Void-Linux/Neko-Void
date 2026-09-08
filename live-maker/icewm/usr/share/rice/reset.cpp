#include <QApplication>
#include <QMessageBox>
#include <QProcess>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);

    QMessageBox msgBox;
    msgBox.setWindowTitle("Restart Required");
    msgBox.setText("The computer will now restart to finish applying configurations.");
    msgBox.setIcon(QMessageBox::Information);
    msgBox.setStandardButtons(QMessageBox::Ok);
    msgBox.exec();

    // Ejecutar el reinicio
    QProcess::startDetached("loginctl", QStringList() << "reboot");

    return 0;
}
