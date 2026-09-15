.pragma library

function fromCategories(categories) {
    const options = [{ id: "", name: "Entrada", color: "" }];
    for (const category of categories)
        options.push(category);
    return options;
}
