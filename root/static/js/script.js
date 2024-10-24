"use strict";

(() => {
    // show Markdown preview right of <textarea> inputs with class .with-markdown-preview
    const syncScrolling = (e, linkedElem) => {
        let height = e.currentTarget.clientHeight;
        let elemHeight = e.currentTarget.scrollHeight - height;
        let linkHeight = linkedElem.scrollHeight - height;
        let linkTop = Math.round(
            (e.currentTarget.scrollTop * linkHeight) / elemHeight
        );

        linkedElem.scroll({ top: linkTop, behaviour: "smooth" });
    };

    document
        .querySelectorAll(
            "textarea.with-markdown-preview, input[type=text].with-markdown-preview"
        )
        .forEach((elem) => {
            let row = elem.parentNode.parentNode;
            let col = document.createElement("div");
            col.className = "col-md-6";
            let preview = document.createElement("div");
            preview.className = "markdown-preview";

            col.append(preview);
            row.append(col);

            elem.addEventListener("input", (e) => {
                preview.innerHTML = marked.parse(e.target.value);
                decorateExternalLinks();
            });

            elem.dispatchEvent(new Event("input"));

            if (elem.tagName === "TEXTAREA") {
                let obs = new ResizeObserver(() => {
                    let height = elem.clientHeight;
                    // Adding 2px to height to prevent infinity loop of resizing
                    preview.style.height = `${height + 2}px`;
                });

                obs.observe(elem);

                elem.addEventListener("scroll", (e) =>
                    syncScrolling(e, preview)
                );
                preview.addEventListener("scroll", (e) =>
                    syncScrolling(e, elem)
                );
            }
        });
})();

// Init bootstrap tooltips
let tooltipList = [];

function initTootips() {
    let tooltipTriggerList = [].slice.call(
        document.querySelectorAll('[data-bs-toggle="tooltip"]')
    );
    tooltipList = tooltipTriggerList.map((elem) => new bootstrap.Tooltip(elem));
}

initTootips();

function alertMessage(
    message,
    typ = "success",
    dismissible = false,
    targetId = "messages"
) {
    const alert = document.createElement("div");
    alert.className = `alert alert-${typ}${
        dismissible ? " alert-dismissible fade show" : ""
    }`;
    alert.ariaRoleDescription = "alert";
    alert.innerHTML = message;
    if (dismissible)
        alert.innerHTML += `<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>`;

    document.getElementById(targetId).append(alert);
}

const forms = document.getElementsByClassName("confirmIfUnsavedChanges");
let hasUnsavedChanges = false;

for (const form of forms) {
    const inputs = Array.prototype.slice.apply(
        form.getElementsByTagName("input")
    );
    const textareas = Array.prototype.slice.apply(
        form.getElementsByTagName("textarea")
    );
    const selects = Array.prototype.slice.apply(
        form.getElementsByTagName("select")
    );
    const elements = inputs.concat(textareas).concat(selects);

    for (const elem of elements) {
        elem.addEventListener("input", () => {
            if (!hasUnsavedChanges) hasUnsavedChanges = true;
        });
    }

    const autocompletes = Array.from(
        form.getElementsByTagName("cc-multi-autocomplete")
    );

    for (const elem of autocompletes) {
        elem.addEventListener("changed", (e) => {
            if (!hasUnsavedChanges) hasUnsavedChanges = true;
        });
    }

    form.addEventListener("submit", () => {
        if (hasUnsavedChanges) hasUnsavedChanges = false;
    });
}

// See documentation about 'beforeunload' event on https://developer.mozilla.org/en-US/docs/Web/API/Window/beforeunload_event
window.addEventListener("beforeunload", (e) => {
    if (hasUnsavedChanges) {
        // Cancel the event as stated by the standard.
        e.preventDefault();
        // Chrome requires returnValue to be set.
        e.returnValue = "";
    }
});

(() => {
    const stickyElems = document.getElementsByClassName("sticky-top");
    const resizeObserver = new ResizeObserver(() => {
        let topValue = 0;
        for (const elem of stickyElems) {
            elem.style.top = `${topValue}px`;
            if (!elem.className.includes("sticky-stacked"))
                topValue += elem.offsetHeight;
        }
    });
    resizeObserver.observe(document.body);
})();

function decorateExternalLinks() {
    const externalLinks = document.querySelectorAll(
        `a[href*="://"]:not([href*="${window.location.origin}"])`
    );
    const externalIcon =
        '<i class="material-icons" style="font-size:90%;">open_in_new</i>';
    for (const link of externalLinks) {
        if (!link.innerHTML.includes(externalIcon))
            link.innerHTML += `&nbsp;${externalIcon}`;
    }
}
decorateExternalLinks();

function decodeHtml(html) {
    var txt = document.createElement("textarea");
    txt.innerHTML = html;
    return txt.value;
}

function getJsonData(id) {
    const html = document.getElementById(id)?.innerText || "";
    const text = decodeHtml(html);
    try {
        return JSON.parse(text);
    } catch {
        return undefined;
    }
}
