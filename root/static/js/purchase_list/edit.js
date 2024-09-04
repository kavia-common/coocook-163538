// Purchase list moving constants
const moveBtn = document.getElementById("move-btn");
const moveBtnDisabled = document.getElementById("move-btn-disabled");
const moveItemsForm = document.getElementById("move-items-form");
const moveModal = document.getElementById("move-items");
const selectPl = document.getElementById("move-items-target");
const currentPurchaseListId = parseInt(location.pathname.split("/").pop());

// Shop section moving constants
const assignBtn = document.getElementById("assign-btn");
const assignBtnDisabled = document.getElementById("assign-btn-disabled");
const assignArticlesForm = document.getElementById("assign-articles-form");
const assignModal = document.getElementById("assign-articles");
const selectShopSection = document.getElementById("assign-articles-target");
const newShopSection = document.getElementById("new-shop-section-name");
const articleSelectWarning = document.getElementById("article-select-warning");
const articleSelectNum = document.getElementById("article-select-num");
const articleSelectList = document.getElementById("article-select-list");

// General constants
const messages = document.getElementById("messages");

const purchaseLists = getJsonData("purchase-lists");
let shopSections = getJsonData("shop-sections");
let articles = {};

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

function mapArticleAmount(items) {
    result = {};
    items.forEach((elem) => {
        const id = elem.dataset.articleId;
        const name = elem.dataset.articleName;
        if (id && name) {
            if (id in result) {
                result[id].num += 1;
            } else {
                result[id] = { num: 1, name };
            }
        }
    });

    return result;
}

function init() {
    if (shopSections === undefined || purchaseLists === undefined) {
        moveBtnDisabled.classList.add("d-none");
        assignBtnDisabled.classList.add("d-none");
        return;
    }

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

    articles = mapArticleAmount(items);

    checkDisabled();
}

function checkDisabled() {
    const items = document.querySelectorAll(
        `input[id^="move-item"]:checked`
    ).length;
    const ingredients = document.querySelectorAll(
        `input[id^="move-ingredient"]:checked`
    );
    let singleIngredientSelected = false;
    for (const ingredient of ingredients) {
        if (
            !ingredient
                .closest("tbody")
                .firstElementChild.className.includes("selected")
        ) {
            singleIngredientSelected = true;
            break;
        }
    }

    if (items > 0 && !singleIngredientSelected) {
        assignBtn?.classList.remove("d-none");
        assignBtnDisabled?.classList.add("d-none");
    } else {
        assignBtn?.classList.add("d-none");
        assignBtnDisabled?.classList.remove("d-none");
    }

    if (items > 0 || ingredients.length > 0) {
        moveBtn?.classList.remove("d-none");
        moveBtnDisabled?.classList.add("d-none");
    } else {
        moveBtn?.classList.add("d-none");
        moveBtnDisabled?.classList.remove("d-none");
    }
}

init();

// Purchase lists
function buildPurchaseListOptions() {
    let defaultSelected = false;
    for (const pl of purchaseLists) {
        if (pl.id === currentPurchaseListId) continue;
        const option = document.createElement("option");
        option.value = pl.id;
        option.innerHTML = `${pl.date} ${pl.name}${
            pl.is_default ? " (default)" : ""
        }`;
        selectPl.append(option);
        if (pl.is_default) {
            selectPl.value = pl.id;
            defaultSelected = true;
        }
    }

    if (purchaseLists.length === 2) {
        let plId = 0;
        for (const pl of purchaseLists) {
            if (pl.id !== currentPurchaseListId) {
                plId = pl.id;
                break;
            }
        }
        selectPl.value = plId;
    } else if (!defaultSelected) {
        selectPl.setCustomValidity("Please select a target purchase list");
    }
    selectPl.addEventListener("input", () => {
        if (selectPl.value === "") {
            selectPl.setCustomValidity("Please select a target purchase list");
        } else {
            selectPl.setCustomValidity("");
        }
    });
}

buildPurchaseListOptions();

moveModal.addEventListener("shown.bs.modal", () => selectPl.focus());
moveModal.addEventListener("hidden.bs.modal", () => {
    selectPl.value = "";
    selectPl.setCustomValidity("Please select a target purchase list");
});

moveItemsForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    const items = document.querySelectorAll(`input[id^="move-item"]:checked`);
    const ingredients = document.querySelectorAll(
        `input[id^="move-ingredient"]:checked`
    );
    const data = `target_purchase_list=${selectPl.value}${Array.from(items)
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

    bootstrap.Modal.getInstance(moveModal).hide();
});

// Shop sections
function getShopSectionOptions() {
    return [
        {
            id: "null",
            name: "(no shop section)",
            display: "<i>(no shop section)</i>",
            mark: false,
        },
        ...shopSections.map((elem) => ({
            id: elem.id,
            name: elem.name,
            mark: true,
        })),
    ];
}

function initAutocomplete() {
    setTimeout(() => {
        selectShopSection.options = getShopSectionOptions();
        selectShopSection.clear();
    }, 1_000);
}

initAutocomplete();

assignModal.addEventListener("shown.bs.modal", () => selectShopSection.focus());
assignModal.addEventListener("show.bs.modal", () => {
    const items = document.querySelectorAll(`input[id^="move-item"]:checked`);
    const selectedArticles = mapArticleAmount(items);
    const error = [];

    for (const [id, data] of Object.entries(selectedArticles)) {
        if (articles[id].num !== data.num) {
            error.push({
                name: data.name,
                selected: data.num,
                total: articles[id].num,
            });
        }
    }

    if (error.length === 0) {
        articleSelectWarning.classList.add("d-none");
        articleSelectWarning.classList.remove("d-flex");
    } else {
        articleSelectNum.innerText = `article${error.length === 1 ? "" : "s"}`;
        articleSelectList.innerHTML = error
            .map(
                (elem) =>
                    `<li class="list-group-item list-group-item-warning">${elem.name} - ${elem.selected} of ${elem.total} items selected</li>`
            )
            .join("");
        articleSelectWarning.classList.remove("d-none");
        articleSelectWarning.classList.add("d-flex");
    }
});
assignModal.addEventListener("hidden.bs.modal", () => {
    selectShopSection.clear();
});

assignArticlesForm.addEventListener("submit", async (e) => {
    e.preventDefault();

    const section = String(
        new FormData(e.target).get("target-shop-section")
    ).trim();
    const numSection = parseInt(section);

    const shopSection = `${
        !(section === "null" || Number.isInteger(numSection)) ? "new_" : ""
    }shop_section=${section}`;

    const items = document.querySelectorAll(`input[id^="move-item"]:checked`);

    const data = `${shopSection}${Array.from(items)
        .map((elem) => `&article=${elem.dataset.articleId}`)
        .join("")}`;
    const url =
        location.pathname +
        (location.pathname.endsWith("/") ? "" : "/") +
        "assign_articles_to_shop_section";
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
            "An error occured during moving the selected articles",
            "danger"
        );
    } else {
        document.getElementById("list-container").innerHTML = await res.text();
        showMessage("Successfully moved the selected articles", "success");
        init();
        selectShopSection.options = getShopSectionOptions();
        selectShopSection.clear();
    }

    bootstrap.Modal.getInstance(assignModal).hide();
});
