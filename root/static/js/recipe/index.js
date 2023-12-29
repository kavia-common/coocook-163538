const formElement = document.getElementById("duplicate-form");
const recipeNameTitleElement = document.getElementById("recipe-name-title");
const recipeNameBodyElement = document.getElementById("recipe-name-body");

const setDuplicateFormValues = (actionURL, name) => {
    formElement.setAttribute("action", actionURL);
    recipeNameTitleElement.textContent = name;
    recipeNameBodyElement.textContent = name;
}

document.getElementById("duplicate-recipe-modal").addEventListener("shown.bs.modal", () => document.getElementById("new-name").focus());
document.getElementById("create-recipe-modal").addEventListener("shown.bs.modal", () => document.getElementById("create-name").focus());
