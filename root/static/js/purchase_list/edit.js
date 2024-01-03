const moveBtn = document.getElementById("move-btn");
const moveBtnDisabled = document.getElementById("move-btn-disabled");
const moveItemsForm = document.getElementById("move-items-form");

const assignBtn = document.getElementById("assign-btn");
const assignBtnDisabled = document.getElementById("assign-btn-disabled");

const messages = document.getElementById("messages");
const moveModal = document.getElementById("move-items");
const select = document.getElementById("move-items-target");
const currentPurchaseListId = parseInt(location.pathname.split("/").pop());

const purchaseLists = getJsonData("purchase-lists");
let shopSections = getJsonData("shop-sections");

let SKIP = false;

function showMessage(msg, type) {
    const msgElem = document.createElement("div");
    msgElem.className = `alert alert-${type}`;
    msgElem.innerHTML = msg;

    messages.append(msgElem);
    setTimeout(() => {
        msgElem.remove();
    }, 5_000);
}

function buildPurchaseListOptions() {
    for (const pl of purchaseLists) {
        if (pl.id === currentPurchaseListId) continue;
        const option = document.createElement("option");
        option.value = pl.id;
        option.innerText = `${pl.date} ${pl.name}`;
        select.append(option);
    }

    select.setCustomValidity("Please select a target purchase list");
    select.addEventListener("input", () => {
        if (select.value === "") {
            select.setCustomValidity("Please select a target purchase list");
        } else {
            select.setCustomValidity("");
        }
    });
}

function handleChangeItem(e) {
    if (SKIP) return;
    SKIP = true;
    const container = e.currentTarget.closest(".purchase-list-table");
    const containerIngredients = container.querySelectorAll(
        `input[id^="move-ingredient"]`
    );
    for (const ingredient of containerIngredients) {
        ingredient.checked = e.target.checked;
    }
    for (const row of container.querySelectorAll("tr")) {
        row.classList[e.target.checked ? "add" : "remove"]("selected");
    }

    SKIP = false;
    checkDisabled();
}

function handleChangeIngredient(e) {
    if (SKIP) return;
    SKIP = true;
    const container = e.currentTarget.closest(".purchase-list-table");
    const containerIngredients = container.querySelectorAll(
        `input[id^="move-ingredient"]`
    );
    const containerItem = container.querySelector(`input[id^="move-item"]`);

    if (!e.target.checked) {
        containerItem.checked = false;
        containerItem.parentElement.parentElement.classList.remove("selected");
        e.target.parentElement.parentElement.classList.remove("selected");
        container.querySelector(".rounding")?.classList.remove("selected");
    } else {
        let all = true;
        for (const ingredient of containerIngredients) {
            if (ingredient === e.target) {
                continue;
            }
            if (!ingredient.checked) {
                all = false;
                break;
            }
        }
        if (all) {
            containerItem.checked = true;
            container.querySelector(".rounding")?.classList.add("selected");
            containerItem.parentElement.parentElement.classList.add("selected");
        }
        e.target.parentElement.parentElement.classList.add("selected");
    }
    SKIP = false;
    checkDisabled();
}

function init() {
    const items = document.querySelectorAll(`input[id^="move-item"]`);
    const ingredients = document.querySelectorAll(
        `input[id^="move-ingredient"]`
    );

    const itemRows = document.querySelectorAll("tbody tr.parent:first-child");
    const ingredientRows = document.querySelectorAll(
        "tbody tr.parent:not(:first-child, .rounding)"
    );

    for (const item of items) {
        item.addEventListener("click", handleChangeItem);
        if (item.checked) {
            item.parentElement.parentElement.classList.add("selected");
        }
    }

    for (const ingredient of ingredients) {
        ingredient.addEventListener("click", handleChangeIngredient);
        if (ingredient.checked) {
            ingredient.parentElement.parentElement.classList.add("selected");
        }
    }

    for (const itemRow of itemRows) {
        itemRow.addEventListener("click", (e) => {
            e.currentTarget.querySelector(`input[id^="move-item"]`).click();
        });
    }

    if (purchaseLists.length > 1) {
        for (const ingredientRow of ingredientRows) {
            ingredientRow.addEventListener("click", (e) => {
                e.currentTarget
                    .querySelector(`input[id^="move-ingredient"]`)
                    .click();
            });
        }
    }

    for (const form of document.querySelectorAll("#list-container form")) {
        form.addEventListener("click", (e) => e.stopPropagation());
    }

    checkDisabled();
}

function checkDisabled() {
    const items = document.querySelectorAll(
        `input[id^="move-item"]:checked`
    ).length;
    const ingredients = document.querySelectorAll(
        `input[id^="move-ingredient"]:checked`
    ).length;

    if (items > 0) {
        assignBtn?.classList.remove("d-none");
        assignBtnDisabled?.classList.add("d-none");
    } else {
        assignBtn?.classList.add("d-none");
        assignBtnDisabled?.classList.remove("d-none");
    }

    if (items > 0 || ingredients > 0) {
        moveBtn?.classList.remove("d-none");
        moveBtnDisabled?.classList.add("d-none");
    } else {
        moveBtn?.classList.add("d-none");
        moveBtnDisabled?.classList.remove("d-none");
    }
}

init();
buildPurchaseListOptions();

moveModal.addEventListener("shown.bs.modal", () => select.focus());
moveModal.addEventListener("hidden.bs.modal", () => {
    select.value = "";
    select.setCustomValidity("Please select a target purchase list");
});

moveItemsForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    const select = document.getElementById("move-items-target");
    const items = document.querySelectorAll(`input[id^="move-item"]:checked`);
    const ingredients = document.querySelectorAll(
        `input[id^="move-ingredient"]:checked`
    );
    const data = `target_purchase_list=${select.value}${Array.from(items)
        .map((elem) => `&item=${elem.id.split("-").pop()}`)
        .join("")}${Array.from(ingredients)
        .map((elem) => `&ingredient=${elem.id.split("-").pop()}`)
        .join("")}`;
    const url =
        location.pathname +
        (location.pathname.endsWith("/") ? "" : "/") +
        "move_items_ingredients";
    const res = await fetch(url, {
        method: "post",
        headers: {
            Accept: "text/html",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        body: data,
    });

    if (!res.ok) {
        showMessage(
            "An error occured during moving the selected items/ingredients",
            "danger"
        );
    } else {
        document.getElementById("list-container").innerHTML = await res.text();
        showMessage(
            "Successfully moved the selected items/ingredients",
            "success"
        );
        init();
    }

    bootstrap.Modal.getInstance(document.getElementById("move-items")).hide();
});
