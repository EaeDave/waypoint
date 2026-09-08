.pragma library

function fromCategories(categories) {
    const options = [{ id: "", name: "Sem categoria", color: "" }];
    for (const category of categories)
        options.push(category);
    return options;
}
