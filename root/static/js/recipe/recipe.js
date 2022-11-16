const formEl = document.getElementById("dublicateForm");
const recipeNameTitleEl = document.getElementById("recipeNameTitle");
const recipeNameBodyEl = document.getElementById("recipeNameBody");

const setValues = (actionURL, name) => {
    formEl.setAttribute("action", actionURL);
    recipeNameTitleEl.textContent = name;
    recipeNameBodyEl.textContent = name;
}
