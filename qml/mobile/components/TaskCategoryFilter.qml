pragma ComponentBehavior: Bound

import QtQuick

Flow {
    id: root

    required property var categories
    property string selectedCategoryId: "__all"
    signal categorySelected(string categoryId)

    readonly property var options: {
        const values = [
            { id: "__all", name: "Todas as categorias" },
            { id: "__uncategorized", name: "Sem categoria" }
        ];
        for (const category of categories || []) {
            values.push({
                id: String(category.id || ""),
                name: String(category.name || "")
            });
        }
        return values;
    }

    spacing: 6
    height: childrenRect.height

    Repeater {
        model: root.options

        delegate: MobileButton {
            required property var modelData

            text: modelData.id === "__all"
                  ? "TODAS AS CATEGORIAS"
                  : modelData.name.toUpperCase()
            accent: root.selectedCategoryId === modelData.id
            quiet: root.selectedCategoryId !== modelData.id
            Accessible.id: "category-filter-" + modelData.id
            Accessible.name: "Filtrar por " + modelData.name
            onClicked: root.categorySelected(modelData.id)
        }
    }
}
