const userList = Array.from(
    document.querySelectorAll(".username"),
    (elem) => elem.innerText
);

function renderUserOption(data) {
    return data
        .filter((elem) => !userList.includes(elem.name))
        .map((elem) => ({
            id: elem.name,
            name: elem.name,
            mark: true,
            display: `<i class="material-icons">groups</i> ${elem.display_name} (${elem.name})`,
        }));
}

setTimeout(() => {
    const search = document.getElementById("user");
    search.renderFunc = renderUserOption;
}, 1_000);
