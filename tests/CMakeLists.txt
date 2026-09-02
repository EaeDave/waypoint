qt_add_executable(waypoint_core_tests
    TaskStoreTest.cpp
)
target_link_libraries(waypoint_core_tests PRIVATE waypoint_core Qt6::Core Qt6::Sql Qt6::Test)
add_test(NAME waypoint_core_tests COMMAND waypoint_core_tests -o -,txt)
set_tests_properties(waypoint_core_tests PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)

qt_add_executable(waypoint_habit_tests
    HabitStoreTest.cpp
)
target_link_libraries(waypoint_habit_tests PRIVATE waypoint_core Qt6::Core Qt6::Sql Qt6::Test)
add_test(NAME waypoint_habit_tests COMMAND waypoint_habit_tests -o -,txt)
set_tests_properties(waypoint_habit_tests PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)

qt_add_executable(waypoint_recurrence_tests
    RecurrenceTest.cpp
)
target_link_libraries(waypoint_recurrence_tests PRIVATE waypoint_core Qt6::Core Qt6::Test)
add_test(NAME waypoint_recurrence_tests COMMAND waypoint_recurrence_tests -o -,txt)
set_tests_properties(waypoint_recurrence_tests PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)

qt_add_executable(waypoint_sync_tests
    SyncEngineTest.cpp
)
target_link_libraries(waypoint_sync_tests PRIVATE waypoint_sync waypoint_core Qt6::Core Qt6::Network Qt6::Sql Qt6::Test)
add_test(NAME waypoint_sync_tests COMMAND waypoint_sync_tests -o -,txt)
set_tests_properties(waypoint_sync_tests PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)

qt_add_executable(waypoint_app_models_tests
    AppModelsTest.cpp
)
target_link_libraries(waypoint_app_models_tests PRIVATE waypoint_app_models Qt6::Core Qt6::Test)
add_test(NAME waypoint_app_models_tests COMMAND waypoint_app_models_tests -o -,txt)
set_tests_properties(waypoint_app_models_tests PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)

qt_add_executable(waypoint_reminder_tests
    ReminderSchedulerTest.cpp
)
target_link_libraries(waypoint_reminder_tests PRIVATE waypoint_reminders waypoint_core Qt6::Core Qt6::Sql Qt6::Test)
add_test(NAME waypoint_reminder_tests COMMAND waypoint_reminder_tests -o -,txt)
set_tests_properties(waypoint_reminder_tests PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)
