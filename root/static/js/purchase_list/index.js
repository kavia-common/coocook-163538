// Add
document
    .getElementById("addList")
    .addEventListener("shown.bs.modal", () =>
        document.getElementById("pl-name").focus()
    );

// Update
function setEditModal(e) {
    let url = e.currentTarget.dataset.url;
    let name = e.currentTarget.dataset.name;

    document.getElementById("update-list").action = url;
    document.getElementById("list-name").innerText = name;
    document.getElementById("pl-new-name").value = name;
    document
        .getElementById("updateList")
        .addEventListener("shown.bs.modal", () =>
            document.getElementById("pl-new-name").focus()
        );
}

document
    .querySelectorAll(".update-trigger")
    .forEach((elem) => elem.addEventListener("click", setEditModal));

// Delete
function setDeleteModal(e) {
    let url = e.currentTarget.dataset.url;
    let name = e.currentTarget.dataset.name;
    let count = e.currentTarget.dataset.count;

    document.getElementById("delete-list-form").action = url;
    document.getElementById("delete-list-name").innerText = name;
    document.getElementById("delete-list-count").innerText = `${
        count === "1" ? "is" : "are"
    } currently ${count} ${count === "1" ? "item" : "items"}`;
}

document
    .getElementById("delete-list")
    .addEventListener("shown.bs.modal", () =>
        document.getElementById("delete-btn").focus()
    );

document
    .querySelectorAll(".delete-trigger")
    .forEach((elem) => elem.addEventListener("click", setDeleteModal));
