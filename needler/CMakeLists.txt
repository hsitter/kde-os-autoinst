project(needler)

cmake_minimum_required(VERSION 3.0)

find_package(ECM 0.0.14 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH} ${ECM_KDE_MODULE_DIR})

include(FeatureSummary)
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings)

find_package(Qt5 CONFIG REQUIRED Gui Qml)
find_package(KF5CoreAddons 5.0.0 REQUIRED)
find_package(KF5KIO 5.0 REQUIRED)

add_subdirectory(src)

