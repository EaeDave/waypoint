cmake_minimum_required(VERSION 3.28)

project(Waypoint VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Network Qml Quick QuickControls2 Sql Test)
qt_standard_project_setup(REQUIRES 6.8)

add_library(waypoint_core STATIC
    src/core/Recurrence.cpp
    src/core/Recurrence.hpp
    src/core/TaskRecord.cpp
    src/core/TaskRecord.hpp
    src/core/SyncConfiguration.hpp
    src/core/TaskStore.cpp
    src/core/TaskStore.hpp
)
target_include_directories(waypoint_core PUBLIC src)
target_link_libraries(waypoint_core PUBLIC Qt6::Core Qt6::Network Qt6::Sql)
target_compile_options(waypoint_core PRIVATE -Wall -Wextra -Wpedantic)

add_library(waypoint_ipc STATIC
    src/ipc/WaypointIpcClient.cpp
    src/ipc/WaypointIpcClient.hpp
    src/ipc/WaypointIpcServer.cpp
    src/ipc/WaypointIpcServer.hpp
    src/ipc/WaypointProtocol.cpp
    src/ipc/WaypointProtocol.hpp
)
target_include_directories(waypoint_ipc PUBLIC src)
target_link_libraries(waypoint_ipc PUBLIC waypoint_core Qt6::Core Qt6::Network)
target_compile_options(waypoint_ipc PRIVATE -Wall -Wextra -Wpedantic)

add_library(waypoint_sync STATIC
    src/sync/SyncEngine.cpp
    src/sync/HolidaySyncEngine.cpp
    src/sync/HolidaySyncEngine.hpp
    src/sync/SyncEngine.hpp
)
target_include_directories(waypoint_sync PUBLIC src)
target_link_libraries(waypoint_sync PUBLIC waypoint_core Qt6::Core Qt6::Network)
target_compile_options(waypoint_sync PRIVATE -Wall -Wextra -Wpedantic)
target_link_libraries(waypoint_ipc PUBLIC waypoint_sync)

add_executable(waypointd src/daemon/main.cpp)
target_link_libraries(waypointd PRIVATE waypoint_sync waypoint_ipc waypoint_core Qt6::Core)

add_executable(waypointctl src/cli/main.cpp)
target_link_libraries(waypointctl PRIVATE waypoint_ipc Qt6::Core Qt6::Network)

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
        qml/components/AppEmojiPicker.qml
        qml/components/CalendarGrid.qml
        qml/components/QuickTaskComposer.qml
        qml/components/TaskRow.qml
        qml/views/MonthView.qml
        qml/views/TodayView.qml
        qml/views/SettingsView.qml
        qml/data/EmojiCatalog.js
)
target_include_directories(waypoint PRIVATE src)
target_link_libraries(waypoint PRIVATE waypoint_app_models waypoint_ipc Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2)
target_compile_options(waypoint PRIVATE -Wall -Wextra -Wpedantic)

include(CTest)
if(BUILD_TESTING)
    add_subdirectory(tests)
endif()

install(TARGETS waypoint waypointd waypointctl
    BUNDLE DESTINATION .
    RUNTIME DESTINATION bin
)
install(FILES packaging/waypoint.desktop DESTINATION share/applications)
