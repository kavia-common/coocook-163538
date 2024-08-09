// !!! this file is also loaded on /settings/account and /user/USERNAME/reset_password for password change !!!
(() => {
    document.querySelector('input[name="url"]')?.setAttribute("tabindex", -1);

    const MAX_STARS = 5;

    const passwordElem = document.querySelector('input[name="password"]');
    const password2Elem = document.querySelector('input[name="password2"]');
    const meterElem = document.getElementById("meter");
    const comparatorElem = document.getElementById("comparator");

    let html = `Strength: ${"&#x2606;".repeat(MAX_STARS)}`;
    meterElem.innerHTML = html;
    comparatorElem.innerHTML = "&nbsp;";

    passwordElem.addEventListener("input", () => {
        let password = passwordElem.value;

        let stars = password == "" ? 0 : zxcvbn(password).score + 1;

        html = `Strength: ${"&#x2605;".repeat(stars)}${"&#x2606;".repeat(
            MAX_STARS - stars
        )}`;

        meterElem.innerHTML = html;
        meterElem.setAttribute("title", `${stars} of ${MAX_STARS}`);
    });

    [passwordElem, password2Elem].forEach((item) => {
        item.addEventListener("input", () => {
            let password = passwordElem.value;
            let password2 = password2Elem.value;

            if ((password.length && password2.length) || password2.length) {
                comparatorElem.innerHTML =
                    password == password2 ? "Matches" : "Doesn't match";
            } else {
                comparatorElem.innerHTML = "&nbsp;";
            }
        });
    });
})();
