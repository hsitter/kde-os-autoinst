/*
    Copyright © 2017 Harald Sitter <sitter@kde.org>

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation; either version 2 of
    the License or (at your option) version 3 or any later version
    accepted by the membership of KDE e.V. (or its successor approved
    by the membership of KDE e.V.), which shall act as a proxy
    defined in Section 14 of version 3 of the license.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QMutex>
#include <QWaitCondition>

#include <KIO/CopyJob>

#include <QDebug>
#include <QDir>

class Application : public QObject
{
    Q_OBJECT
public slots:
    QUrl fileArgument()
    {
        return QUrl::fromUserInput(QCoreApplication::arguments().value(1, QString()),
                                   QDir::currentPath());
    }

    bool copy(const QUrl &origin, const QUrl &target)
    {
        qDebug() << origin << target;
        auto job = KIO::copy(origin, target, KIO::Overwrite);
        qDebug() << "start";
        return job->exec();
    }
};

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    qmlRegisterSingletonType<Application>("privateneedler", 1, 0, "Application",
                                          [](QQmlEngine *, QJSEngine *) -> QObject * { return new Application; });

    QQmlApplicationEngine engine;
    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));
    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    return app.exec();
}

#include "main.moc"
