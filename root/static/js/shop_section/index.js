function setModal(e) {
    let url = e.currentTarget.dataset.url;
    let name = e.currentTarget.dataset.name;

    document.getElementById("update-section-form").action = url;
    document.getElementById("section-name").innerText = name;
    document.getElementById("ss-new-name").value = name;
    document
        .getElementById("update-section")
        .addEventListener("shown.bs.modal", () =>
            document.getElementById("ss-new-name").focus()
        );
}

document
    .querySelectorAll(".update")
    .forEach((elem) => elem.addEventListener("click", setModal));

document
    .getElementById("add-section")
    .addEventListener("shown.bs.modal", () =>
        document.getElementById("ss-name").focus()
    );
