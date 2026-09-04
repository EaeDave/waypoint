cmake_minimum_required(VERSION 3.28)

project(Waypoint VERSION 0.2.6 LANGUAGES CXX)
configure_file(
    src/core/WaypointVersion.hpp.in
    ${CMAKE_CURRENT_BINARY_DIR}/generated/WaypointVersion.hpp
    @ONLY
)
add_library(waypoint_version INTERFACE)
target_include_directories(waypoint_version INTERFACE ${CMAKE_CURRENT_BINARY_DIR}/generated)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(waypoint_qt_components Core Gui Network Qml Quick QuickControls2 Sql)
if(NOT ANDROID)
    list(APPEND waypoint_qt_components DBus Test)
endif()
find_package(Qt6 6.8 REQUIRED COMPONENTS ${waypoint_qt_components})
qt_standard_project_setup(REQUIRES 6.8)

add_library(waypoint_core STATIC
    src/core/HabitRecord.cpp
    src/core/HabitRecord.hpp
    src/core/Recurrence.cpp
    src/core/Recurrence.hpp
    src/core/TaskRecord.cpp
    src/core/TaskRecord.hpp
    src/core/SyncConfiguration.hpp
    src/core/TaskStore.cpp
    src/core/TaskStore.hpp
    src/core/TaskVisibility.cpp
    src/core/TaskVisibility.hpp
)
target_include_directories(waypoint_core PUBLIC src)
target_link_libraries(waypoint_core PUBLIC waypoint_version Qt6::Core Qt6::Network Qt6::Sql)
target_compile_options(waypoint_core PRIVATE -Wall -Wextra -Wpedantic)
add_library(waypoint_update STATIC
    src/update/UpdateChecker.cpp
    src/update/UpdateChecker.hpp
)
target_include_directories(waypoint_update PUBLIC src)
target_link_libraries(waypoint_update PUBLIC waypoint_version Qt6::Core Qt6::Network)
target_compile_options(waypoint_update PRIVATE -Wall -Wextra -Wpedantic)


add_library(waypoint_sync STATIC
    src/sync/SyncEngine.cpp
    src/sync/HolidaySyncEngine.cpp
    src/sync/HolidaySyncEngine.hpp
    src/sync/SyncEngine.hpp
    src/sync/SyncProtocol.cpp
    src/sync/SyncProtocol.hpp
)
target_include_directories(waypoint_sync PUBLIC src)
target_link_libraries(waypoint_sync PUBLIC waypoint_core Qt6::Core Qt6::Network)
target_compile_options(waypoint_sync PRIVATE -Wall -Wextra -Wpedantic)

add_library(waypoint_mobile_core STATIC
    src/mobile/AndroidBackgroundSyncBridge.cpp
    src/mobile/AndroidBackgroundSyncBridge.hpp
    src/mobile/AndroidWidgetBridge.cpp
    src/mobile/AndroidUpdateBridge.cpp
    src/mobile/AndroidUpdateBridge.hpp
    src/mobile/AndroidUpdateInstaller.cpp
    src/mobile/AndroidUpdateInstaller.hpp
    src/mobile/AndroidWidgetBridge.hpp
    src/mobile/AndroidNotificationBridge.cpp
    src/mobile/BackgroundSync.cpp
    src/mobile/BackgroundSync.hpp
    src/mobile/AndroidNotificationBridge.hpp
    src/mobile/MobileController.cpp
    src/mobile/MobileController.hpp
    src/mobile/NotificationSchedule.cpp
    src/mobile/NotificationSchedule.hpp
    src/mobile/WidgetSnapshot.cpp
    src/mobile/WidgetSnapshot.hpp
    src/mobile/WidgetTaskAction.cpp
    src/mobile/WidgetTaskAction.hpp
)
target_include_directories(waypoint_mobile_core PUBLIC src)
target_link_libraries(waypoint_mobile_core PUBLIC waypoint_core waypoint_sync waypoint_update waypoint_version Qt6::Core Qt6::Network)
target_compile_options(waypoint_mobile_core PRIVATE -Wall -Wextra -Wpedantic)

if(ANDROID)
    include(FetchContent)
    FetchContent_Declare(
        android_openssl
        DOWNLOAD_EXTRACT_TIMESTAMP TRUE
        URL https://github.com/KDAB/android_openssl/archive/b71f1470962019bd89534a2919f5925f93bc5779.zip
        URL_HASH SHA256=9277d62ecdb4809801e2c369e0a639c154e0d9137e8d60863b44bf07d16ed5b3
    )
    FetchContent_MakeAvailable(android_openssl)
    include("${android_openssl_SOURCE_DIR}/android_openssl.cmake")

    math(EXPR waypoint_android_version_code
        "${PROJECT_VERSION_MAJOR} * 1000000 + ${PROJECT_VERSION_MINOR} * 1000 + ${PROJECT_VERSION_PATCH}")
    qt_add_executable(waypoint_android MANUAL_FINALIZATION
        src/mobile/main.cpp
        src/mobile/AndroidWidgetAction.cpp
    )
    set_source_files_properties(qml/mobile/MobileTheme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
    qt_add_qml_module(waypoint_android
        URI Waypoint.Mobile
        VERSION 1.0
        QML_FILES
            qml/mobile/Main.qml
            qml/mobile/MobileTheme.qml
            qml/mobile/components/HabitEditor.qml
            qml/mobile/components/MobileButton.qml
            qml/mobile/components/MobileComboBox.qml
            qml/mobile/components/MobileCheck.qml
            qml/mobile/components/MobileField.qml
            qml/mobile/components/MobileIcon.qml
            qml/mobile/components/SectionCard.qml
            qml/mobile/components/TaskEditor.qml
            qml/mobile/components/TaskVisibilityChip.qml
            qml/mobile/views/CalendarPage.qml
            qml/mobile/views/HabitsPage.qml
            qml/mobile/views/SettingsPage.qml
            qml/mobile/views/TodayPage.qml
    )
    target_include_directories(waypoint_android PRIVATE src)
    target_link_libraries(waypoint_android PRIVATE
        waypoint_mobile_core
        waypoint_version
        Qt6::Core
        Qt6::CorePrivate
        Qt6::Gui
        Qt6::Qml
        Qt6::Quick
        Qt6::QuickControls2
    )
    target_compile_options(waypoint_android PRIVATE -Wall -Wextra -Wpedantic)
    set_target_properties(waypoint_android PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android"
        QT_ANDROID_PACKAGE_NAME "org.eaedave.waypoint"
        QT_ANDROID_APP_NAME "Waypoint"
        QT_ANDROID_MIN_SDK_VERSION 28
        QT_ANDROID_TARGET_SDK_VERSION 35
        QT_ANDROID_VERSION_CODE "${waypoint_android_version_code}"
        QT_ANDROID_VERSION_NAME "${PROJECT_VERSION}"
    )
    add_android_openssl_libraries(waypoint_android)
    qt_finalize_executable(waypoint_android)
else()
    add_library(waypoint_reminders STATIC
        src/reminders/ReminderScheduler.cpp
        src/reminders/ReminderScheduler.hpp
        src/reminders/SystemNotificationSink.cpp
        src/reminders/SystemNotificationSink.hpp
    )
    target_include_directories(waypoint_reminders PUBLIC src)
    target_link_libraries(waypoint_reminders PUBLIC waypoint_core Qt6::Core Qt6::DBus)
    target_compile_options(waypoint_reminders PRIVATE -Wall -Wextra -Wpedantic)

    add_library(waypoint_ipc STATIC
        src/ipc/WaypointIpcClient.cpp
        src/ipc/WaypointIpcClient.hpp
        src/ipc/WaypointIpcServer.cpp
        src/ipc/WaypointIpcServer.hpp
        src/ipc/WaypointProtocol.cpp
        src/ipc/WaypointProtocol.hpp
    )
    target_include_directories(waypoint_ipc PUBLIC src)
    target_link_libraries(waypoint_ipc PUBLIC waypoint_core waypoint_sync waypoint_update Qt6::Core Qt6::Network)
    target_compile_options(waypoint_ipc PRIVATE -Wall -Wextra -Wpedantic)

    add_executable(waypointd src/daemon/main.cpp)
    target_link_libraries(waypointd PRIVATE waypoint_reminders waypoint_sync waypoint_ipc waypoint_update waypoint_core waypoint_version Qt6::Core)
    add_executable(waypoint-updater src/update/LinuxUpdaterMain.cpp)
    target_link_libraries(waypoint-updater PRIVATE waypoint_update waypoint_version Qt6::Core)


    add_executable(waypointctl src/cli/main.cpp)
    target_link_libraries(waypointctl PRIVATE waypoint_ipc waypoint_version Qt6::Core Qt6::Network)

    add_library(waypoint_app_models STATIC
        src/app/CalendarModel.cpp
        src/app/CalendarModel.hpp
        src/app/TaskListModel.cpp
        src/app/TaskListModel.hpp
    )
    target_include_directories(waypoint_app_models PUBLIC src)
    target_link_libraries(waypoint_app_models PUBLIC waypoint_core Qt6::Core)
    target_compile_options(waypoint_app_models PRIVATE -Wall -Wextra -Wpedantic)

    qt_add_executable(waypoint
        src/app/main.cpp
        src/app/WaypointController.cpp
        src/app/WaypointController.hpp
    )
    set_source_files_properties(qml/WaypointTheme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
    set_source_files_properties(qml/data/EmojiCatalog.js PROPERTIES QT_QML_SKIP_QMLDIR_ENTRY TRUE)

    qt_add_qml_module(waypoint
        URI Waypoint
        VERSION 1.0
        NO_IMPORT_SCAN
        QML_FILES
            qml/Main.qml
            qml/WaypointTheme.qml
            qml/components/CalendarDay.qml
            qml/components/AppIcon.qml
            qml/components/AppButton.qml
            qml/components/AppCheckBox.qml
            qml/components/AppComboBox.qml
            qml/components/AppSpinBox.qml
            qml/components/AppMenuItem.qml
            qml/components/AppTextField.qml
            qml/components/AppTimePicker.qml
            qml/components/AppReminderPicker.qml
            qml/components/AppEmojiPicker.qml
            qml/components/AppHabitReminderPicker.qml
            qml/components/HabitSection.qml
            qml/components/CalendarGrid.qml
            qml/components/QuickTaskComposer.qml
            qml/components/TaskRow.qml
            qml/components/TaskVisibilityChip.qml
            qml/views/MonthView.qml
            qml/views/TodayView.qml
            qml/views/SettingsView.qml
            qml/data/EmojiCatalog.js
    )
    target_include_directories(waypoint PRIVATE src)
    target_link_libraries(waypoint PRIVATE waypoint_app_models waypoint_ipc waypoint_update waypoint_version Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2)
    target_compile_options(waypoint PRIVATE -Wall -Wextra -Wpedantic)

    include(CTest)
    if(BUILD_TESTING)
        add_subdirectory(tests)
    endif()

    install(TARGETS waypoint waypointd waypointctl waypoint-updater
        BUNDLE DESTINATION .
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    )
    install(FILES packaging/waypoint.desktop
        DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
    install(FILES packaging/waypoint.svg
        DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)
    install(FILES LICENSE
        DESTINATION ${CMAKE_INSTALL_DATADIR}/licenses/waypoint)
    install(FILES packaging/systemd/waypointd.service
        DESTINATION ${CMAKE_INSTALL_DATADIR}/systemd/user)
endif()
