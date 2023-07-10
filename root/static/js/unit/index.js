document
    .getElementById("create-unit-modal")
    .addEventListener("shown.bs.modal", () =>
        document.getElementById("create-short-name").focus()
    );
