(() => {
    const existingRecipeNames = getJsonData("existing_recipe_names");

    const articleElemList = document.querySelectorAll("#import select.article");
    articleElemList.forEach((articleElem) => {
        articleElem.onchange = () => {
            let selectedArticleElem =
                articleElem.options[articleElem.options.selectedIndex];

            let unitElem = articleElem
                .closest("tr")
                .querySelector("select.unit");
            let unitOptionElems = unitElem.options;

            if (!selectedArticleElem.value) {
                Array.from(unitOptionElems).forEach((unitOptionElem) => {
                    unitOptionElem.style.display = "block";
                });
                return;
            }

            let unitIds = selectedArticleElem
                .getAttribute("data-units")
                .split(",");
            // if select unit is not applicable to article, reset unit selector
            if (unitIds.indexOf(unitElem.value) == -1) {
                unitElem.value = "";
            }

            // show only applicable units
            Array.from(unitOptionElems).forEach((unitOptionElem) => {
                let unitId = unitOptionElem.value;
                if (unitId == "" || unitIds.indexOf(unitId) > -1) {
                    unitOptionElem.style.display = "block";
                } else {
                    unitOptionElem.style.display = "none";
                }
            });
        };
    });

    // check uniqueness of recipe name
    const nameInputElem = document.querySelector('#import input[name="name"]');
    nameInputElem.addEventListener("input", () => {
        let name = nameInputElem.value;

        if (existingRecipeNames.indexOf(name) === -1) {
            nameInputElem.setCustomValidity("");
            nameInputElem.classList.remove("is-invalid");
        } else {
            nameInputElem.setCustomValidity(
                "This recipe name already exists in this project"
            );
            nameInputElem.classList.add("is-invalid");
        }
        nameInputElem.reportValidity();
    });

    // skip checkboxes
    const checkboxElemList = document.querySelectorAll(
        "#import .should-import"
    );
    checkboxElemList.forEach((checkboxElem) => {
        checkboxElem.onchange = () => {
            let skip = !checkboxElem.checked;
            let trElem = checkboxElem.closest("tr");

            trElem.classList.toggle("skip");

            Array.from(trElem.querySelectorAll("input,select"))
                .filter((item) => item != checkboxElem)
                .forEach((item) =>
                    skip
                        ? item.setAttribute("disabled", skip)
                        : item.removeAttribute("disabled")
                );
        };
    });
})();
