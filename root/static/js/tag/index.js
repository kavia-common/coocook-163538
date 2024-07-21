const existingNames = getJsonData("existing_names");

// Check for existing names
function setupCheckExistingName(inputField, tag = true) {
    inputField.addEventListener("input", () => {
        if (
            existingNames[tag ? "tags" : "tagGroups"].includes(inputField.value)
        ) {
            inputField.setCustomValidity("This name is already used");
        } else {
            inputField.setCustomValidity("");
        }
    });
}

// Add tag modal
const addTagName = document.getElementById("tag-new-name");
const addTagForm = document.getElementById("add-tag-form");
const addTagModal = document.getElementById("add-tag");

addTagModal.addEventListener("shown.bs.modal", () => addTagName.focus());
addTagModal.addEventListener("hidden.bs.modal", () => addTagForm.reset());
setupCheckExistingName(addTagName);

// Add tag group modal
const addTagGroupName = document.getElementById("tg-new-name");
const addTagGroupForm = document.getElementById("add-tag-group-form");
const addTagGroupModal = document.getElementById("add-tg");

addTagGroupModal.addEventListener("shown.bs.modal", () =>
    addTagGroupName.focus()
);
addTagGroupModal.addEventListener("hidden.bs.modal", () =>
    addTagGroupForm.reset()
);
setupCheckExistingName(addTagGroupName, false);

// Edit tag group modal
const editTagGroupName = document.getElementById("tg-edit-name");
const editTagGroupForm = document.getElementById("tg-edit-form");
const editTagGroupModal = document.getElementById("tg-edit");

editTagGroupModal.addEventListener("shown.bs.modal", () =>
    editTagGroupName.focus()
);
editTagGroupModal.addEventListener("hidden.bs.modal", () =>
    editTagGroupForm.reset()
);

function setEditTgModal(e) {
    const url = e.currentTarget.dataset.url;
    const name = e.currentTarget.dataset.name;
    const comment = e.currentTarget.dataset.comment;

    editTagGroupForm.action = url;
    document.getElementById("tg-edit-title").innerText = name;
    editTagGroupName.value = name;
    document.getElementById("tg-edit-comment").value = comment;

    editTagGroupName.addEventListener("input", () => {
        if (
            existingNames.tagGroups.includes(editTagGroupName.value) &&
            name !== editTagGroupName.value
        ) {
            editTagGroupName.setCustomValidity("This name is already used");
        } else {
            editTagGroupName.setCustomValidity("");
        }
    });
}

document
    .querySelectorAll(".edit-tg")
    .forEach((elem) => elem.addEventListener("click", setEditTgModal));

// Add to group modal
const addToTagGroupName = document.getElementById("atg-name");
const addToTagGroupForm = document.getElementById("add-to-group-form");
const addToTagGroupModal = document.getElementById("add-to-group");

addToTagGroupModal.addEventListener("shown.bs.modal", () =>
    addToTagGroupName.focus()
);
addToTagGroupModal.addEventListener("hidden.bs.modal", () =>
    addToTagGroupForm.reset()
);
setupCheckExistingName(addToTagGroupName);

function setAtgModal(e) {
    const name = e.currentTarget.dataset.name;
    const id = e.currentTarget.dataset.id;

    document.getElementById("atg-title").innerText = name;
    document.getElementById("atg-group").value = id;
}

document
    .querySelectorAll(".atg")
    .forEach((elem) => elem.addEventListener("click", setAtgModal));
