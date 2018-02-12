qt5_add_resources(needler_SRCS resources.qrc)
add_executable(needler main.cpp ${needler_SRCS})
target_link_libraries(needler Qt5::Qml Qt5::Widgets KF5::KIOCore)
