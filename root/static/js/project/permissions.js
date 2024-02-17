function renderUserOrgOption(data) {
    return data
        .filter((elem) => !userList.includes(elem.name))
        .filter((elem) => !orgList.includes(elem.name))
        .sort((a, b) => a.display_name > b.display_name)
        .map((elem) => ({
            id: elem.name,
            name: elem.name,
            mark: true,
            display: `<i class="material-icons">${
                elem.type === "user" ? "person" : "groups"
            }</i> ${elem.display_name} (${elem.name})`,
        }));
}

const userList = Array.from(
    document.querySelectorAll(".username"),
    (elem) => elem.innerText
);
const orgList = Array.from(
    document.querySelectorAll(".organization"),
    (elem) => elem.innerText
);

setTimeout(() => {
    const search = document.getElementById("user");
    search.renderFunc = renderUserOrgOption;
}, 1_000);
