// properties comes from root/templates/project/import.tt

const properties = getJsonData("properties_data");

for (let property of properties) {
    if (property.depends_on.length || property.dependency_of.length) {
        let depends_on = property.depends_on.map((key) =>
            document.getElementById("property_" + key)
        );
        let dependency_of = property.dependency_of.map((key) =>
            document.getElementById("property_" + key)
        );

        let prop = document.getElementById("property_" + property.key);

        prop?.addEventListener("change", function () {
            if (this.checked) {
                depends_on.forEach((dep) => {
                    dep.checked = true;
                    dep.dispatchEvent(new Event("change"));
                });
            } else {
                dependency_of.forEach((dep) => {
                    dep.checked = false;
                    dep.dispatchEvent(new Event("change"));
                });
            }
        });
    }
}

// JavaScript worked until here -> remove warning
document.getElementById("jsWarning")?.remove();
