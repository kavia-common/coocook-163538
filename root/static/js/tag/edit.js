document
    .getElementById("edit-tag")
    .addEventListener("shown.bs.modal", () =>
        document.getElementById("edit-name").focus()
    );

try {
    document
        .getElementById("delete-tag")
        .addEventListener("shown.bs.modal", () =>
            document.getElementById("delete-btn").focus()
        );
} catch {}
