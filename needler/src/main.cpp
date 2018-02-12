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

#include <QApplication>
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
    // Need QApplicaton instead of QGuiApplication as KIO internally will
    // open QDialogs. Happens a lot when draggin and dropping from browser.
    // See below.
    // TODO: file bug against KIO, KIOCore shouldn't QDialog most likely or
    //   have Qt5::Widgets in the link list.
    QApplication app(argc, argv);

    qmlRegisterSingletonType<Application>("privateneedler", 1, 0, "Application",
                                          [](QQmlEngine *, QJSEngine *) -> QObject * { return new Application; });

    QQmlApplicationEngine engine;
    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));
    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    return app.exec();
}

/**
es/install_calamares/calamares-installer-welcome.png")
needler(5112)/(kf5.kio.core.copyjob) unknown: Stating finished. To copy: 0 , available: 74166726656
needler(5112)/(kf5.kio.core.copyjob) unknown:
needler(5112)/(kf5.kio.core.copyjob) unknown: preparing to copy QUrl("") 18446744073709551615 74166726656
needler(5112)/(kf5.kio.core.copyjob) unknown: copying "/home/me/src/git/kde-os-autoinst/neon/needles/install_calamares/calamares-installer-welcome.png"
needler(5112)/(kf5.kio.core) unknown: Refilling KProtocolInfoFactory cache in the hope to find ""
needler(5112)/(kf5.kio.core) unknown: Refilling KProtocolInfoFactory cache in the hope to find ""
needler(5112)/(kf5.kio.core.copyjob) unknown: Copying QUrl("") to QUrl("file:///home/me/src/git/kde-os-autoinst/neon/needles/install_calamares/calamares-installer-welcome.png")
needler(5112)/(kf5.kio.core) unknown: Refilling KProtocolInfoFactory cache in the hope to find ""
needler(5112)/(kf5.kio.core) unknown: Refilling KProtocolInfoFactory cache in the hope to find ""
needler(5112)/(kf5.kio.core) unknown: Invalid URL: QUrl("")
needler(5112)/(kf5.kio.core.copyjob) unknown: d->state= 6
needler(5112)/(default) unknown: QWidget: Cannot create a QWidget without QApplication


#0  0x00007ffff5c21428 in __GI_raise (sig=sig@entry=6) at ../sysdeps/unix/sysv/linux/raise.c:54
#1  0x00007ffff5c2302a in __GI_abort () at abort.c:89
#2  0x00007ffff63ccc71 in QMessageLogger::fatal(char const*, ...) const ()
   from /usr/lib/x86_64-linux-gnu/libQt5Core.so.5
#3  0x00007fffe13d3971 in QWidgetPrivate::init(QWidget*, QFlags<Qt::WindowType>) ()
   from /usr/lib/x86_64-linux-gnu/libQt5Widgets.so.5
#4  0x00007fffe157f8b3 in QDialog::QDialog(QWidget*, QFlags<Qt::WindowType>) ()
   from /usr/lib/x86_64-linux-gnu/libQt5Widgets.so.5
#5  0x00007fffe3449a3e in KIO::SkipDialog::SkipDialog(QWidget*, QFlags<KIO::SkipDialog_Option>, QString const&) ()
   from /usr/lib/x86_64-linux-gnu/libKF5KIOWidgets.so.5
#6  0x00007fffe344b3cf in KIO::JobUiDelegate::askSkip(KJob*, QFlags<KIO::SkipDialog_Option>, QString const&) ()
   from /usr/lib/x86_64-linux-gnu/libKF5KIOWidgets.so.5
#7  0x00007ffff6d82d43 in KIO::CopyJobPrivate::slotResultErrorCopyingFiles (this=this@entry=0x189cb70,
    job=job@entry=0xc531d0) at /workspace/build/src/core/copyjob.cpp:1436
#8  0x00007ffff6d83404 in KIO::CopyJobPrivate::slotResultCopyingFiles (this=this@entry=0x189cb70,
    job=job@entry=0xc531d0) at /workspace/build/src/core/copyjob.cpp:1312
#9  0x00007ffff6d85317 in KIO::CopyJob::slotResult (this=0x189ad00, job=0xc531d0)
    at /workspace/build/src/core/copyjob.cpp:2112
#10 0x00007ffff65e55a6 in QMetaObject::activate(QObject*, int, int, void**) ()
   from /usr/lib/x86_64-linux-gnu/libQt5Core.so.5
#11 0x00007ffff6ab2b5c in KJob::result(KJob*, KJob::QPrivateSignal) ()
   from /usr/lib/x86_64-linux-gnu/libKF5CoreAddons.so.5
#12 0x00007ffff6ab3671 in KJob::finishJob(bool) () from /usr/lib/x86_64-linux-gnu/libKF5CoreAddons.so.5
#13 0x00007ffff6dcb3a9 in KIO::FileCopyJob::slotResult (this=0xc531d0, job=0x174db40)
    at /workspace/build/src/core/filecopyjob.cpp:565
#14 0x00007ffff65e55a6 in QMetaObject::activate(QObject*, int, int, void**) ()
   from /usr/lib/x86_64-linux-gnu/libQt5Core.so.5
#15 0x00007ffff6ab2b5c in KJob::result(KJob*, KJob::QPrivateSignal) ()
   from /usr/lib/x86_64-linux-gnu/libKF5CoreAddons.so.5
#16 0x00007ffff6ab3671 in KJob::finishJob(bool) () from /usr/lib/x86_64-linux-gnu/libKF5CoreAddons.so.5
#17 0x00007ffff6dd5e42 in KIO::SimpleJob::slotFinished (this=this@entry=0x174db40)
    at /workspace/build/src/core/simplejob.cpp:233
#18 0x00007ffff6de09b6 in KIO::TransferJob::slotFinished (this=0x174db40)
    at /workspace/build/src/core/transferjob.cpp:172
#19 0x00007ffff65e62b9 in QObject::event(QEvent*) () from /usr/lib/x86_64-linux-gnu/libQt5Core.so.5
#20 0x00007ffff65b8c9a in QCoreApplication::notify(QObject*, QEvent*) () from /usr/lib/x86_64-linux-gnu/libQt5Core.so.5
#21 0x00007ffff65b8df8 in QCoreApplication::notifyInternal2(QObject*, QEvent*) ()
   from /usr/lib/x86_64-linux-gnu/libQt5Core.so.5
#22 0x00007ffff65bb5db in QCoreApplicationPrivate::sendPostedEvents(QObject*, int, QThreadData*) ()
   from /usr/lib/x86_64-linux-gnu/libQt5Core.so.5
#23 0x00007ffff660f0a3 in ?? () from /usr/lib/x86_64-linux-gnu/libQt5Core.so.5
#24 0x00007ffff25ee197 in g_main_dispatch (context=0x7fffe40016f0)
    at /build/glib2.0-prJhLS/glib2.0-2.48.2/./glib/gmain.c:3154
#25 g_main_context_dispatch (context=context@entry=0x7fffe40016f0)
    at /build/glib2.0-prJhLS/glib2.0-2.48.2/./glib/gmain.c:3769
#26 0x00007ffff25ee3f0 in g_main_context_iterate (context=context@entry=0x7fffe40016f0, block=block@entry=1,
    dispatch=dispatch@entry=1, self=<optimized out>) at /build/glib2.0-prJhLS/glib2.0-2.48.2/./glib/gmain.c:3840
#27 0x00007ffff25ee49c in g_main_context_iteration (context=0x7fffe40016f0, may_block=1)
    at /build/glib2.0-prJhLS/glib2.0-2.48.2/./glib/gmain.c:3901
#28 0x00007ffff660e6af in QEventDispatcherGlib::processEvents(QFlags<QEventLoop::ProcessEventsFlag>) ()
   from /usr/lib/x86_64-linux-gnu/libQt5Core.so.5
#29 0x00007ffff65b6e2a in QEventLoop::exec(QFlags<QEventLoop::ProcessEventsFlag>) ()
   from /usr/lib/x86_64-linux-gnu/libQt5Core.so.5
#30 0x00007ffff6ab614e in KJob::exec() () from /usr/lib/x86_64-linux-gnu/libKF5CoreAddons.so.5
#31 0x0000000000404e25 in Application::copy(QUrl const&, QUrl const&) ()
#32 0x000000000040440c in Application::qt_static_metacall(QObject*, QMetaObject::Call, int, void**) ()
#33 0x0000000000404546 in Application::qt_metacall(QMetaObject::Call, int, void**) ()
#34 0x00007ffff7a64539 in ?? () from /usr/lib/x86_64-linux-gnu/libQt5Qml.so.5

   **/

#include "main.moc"

