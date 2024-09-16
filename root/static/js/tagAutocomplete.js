const tags = getJsonData("available_tags");
const tagsInputs = document.querySelectorAll("cc-multi-autocomplete.tags");

function getTagOptions() {
    return tags.map((elem) => ({
        id: elem.name,
        name: elem.name,
        mark: true,
    }));
}

function initAutocomplete() {
    for (const tagInput of tagsInputs) {
        setTimeout(() => {
            tagInput.options = getTagOptions();
            tagInput.clear();
        }, 1_000);
    }
}

initAutocomplete();
