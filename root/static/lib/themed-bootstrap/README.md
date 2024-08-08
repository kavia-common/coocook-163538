To adjust the theme you need a sass compiler and css minifier.

With Node.js you can use the packages `sass` and `clean-css-cli`.
```shell
npm i -g sass clean-css-cli
```

Comands to build the CSS (inside of `root/static/lib/themed-bootstrap`):
```shell
sass themed.scss:themed.css
cleancss -o themed.min.css themed.css
```

Both commands can also be used in watch mode with the `--watch` flag.


**All changes should be done in `themed.scss`.**
