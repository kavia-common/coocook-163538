const purchaseLists = getJsonData("purchase-lists");
let SKIP = false;

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
    SKIP = false;
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
        }
    }
    SKIP = false;
}

function init() {
    const items = document.querySelectorAll(`input[id^="move-item"]`);
    const ingredients = document.querySelectorAll(
        `input[id^="move-ingredient"]`
    );

    for (const item of items) {
        item.addEventListener("click", handleChangeItem);
    }

    for (const ingredient of ingredients) {
        ingredient.addEventListener("click", handleChangeIngredient);
    }
}

init();
