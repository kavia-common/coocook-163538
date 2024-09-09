# Coocook

Web application for collecting recipes and making food plans

## Main features

* collect recipes
* create food plans
    * simply import dishes from your recipes
* gather purchase lists
    * convert units to summarize list items
* print views for whole project and each day
    * including ingredients, cooking instructions
* special features
    * define maximum shelf life or limit for need to preorder of articles
    * select some ingredients and part of cooking instructions to be done at an earlier meals

## Quick start

Get source code:

```console
$ git clone https://gitlab.com/coocook/coocook.git
$ cd coocook/
```

### Configuration

The only configuration required to start a development server is a database connection.
It’s recommended to configure (possibly multiple) connections in `dbic.yaml` in the project root directory.

You can copy the example file [`share/examples/dbic.yaml`](share/examples/dbic.yaml) to the project root directory:

```console
$ cp share/examples/dbic.yaml ./
```

By default Coocook will connect to the connection in `dbic.yaml` with key `development`.
The example file defines a local SQLite file `coocook.sqlite`.

The selected connection key and other settings can be configured in a config file format supported by [`Catalyst::Plugin::ConfigLoader`](https://metacpan.org/dist/Catalyst-Plugin-ConfigLoader/view/lib/Catalyst/Plugin/ConfigLoader/Manual.pod) like `coocook.yaml`.
You can copy the example file [`share/examples/coocook.yaml`](share/examples/coocook.yaml)
with the most common settings to the project root directory:

```console
$ cp share/examples/coocook.yaml ./
```

For other possible settings see the default values defined in [`lib/Coocook.pm`](lib/Coocook.pm).

### Run with native Perl (works best on Unix-like Operating Systems)

Prerequisites:

* [Perl5](https://www.perl.org/get.html)
  with [`cpanm`](https://metacpan.org/pod/App::cpanminus#INSTALLATION)

* database

  * by default [SQLite](https://www.sqlite.org/)
    with [`DBD::SQLite`](https://metacpan.org/pod/DBD::SQLite)

  * or [PostgreSQL](https://www.postgresql.org/)
    with [`DBD::Pg`](https://metacpan.org/pod/DBD::Pg)

With Ubuntu or Debian Linux:

```console
$ sudo apt-get install cpanminus sqlite3
```

To install Perl distributions that include C code you’ll probably need a C toolchain and some libraries:

```console
$ sudo apt-get install build-essential
$ sudo apt-get install libssl-dev zlib1g-dev             # for Net::SSLeay
$ sudo apt-get install libexpat1-dev                     # for XML::Parser
$ sudo apt-get install libncurses-dev libreadline-dev    # for Term::ReadLine::Gnu for development mode
$ sudo apt-get install libpq-dev                         # for DBD::Pg
```

Install Perl5 dependencies required for running the application:

```console
$ cpanm --installdeps .
```

There are a few additional dependencies for *development* as well *recommended* and *suggested* dependencies. To install these as well run:

```console
$ cpanm --installdeps --with-develop --with-recommends --with-suggests .
```

Install the database schema into a connection from your `dbic.yaml` (see above) and start development server in debug mode:

```console
$ script/coocook_deploy.pl --connection_name 'development' install
$ script/coocook_server.pl --debug
...
HTTP::Server::PSGI: Accepting connections at http://0:3000/
```

Hint: With the `--restart` option the development server restarts automatically when files in `lib/` are changed.
This requires [`Catalyst::Restarter`](https://metacpan.org/pod/Catalyst::Restarter).

### Run with Docker

Follow the instructions at [hub.docker.com/r/coocook/coocook-dev](https://hub.docker.com/r/coocook/coocook-dev) to use the Docker image for development.

## Mailing list

* <coocook@lists.coocook.org>
* subscribe at [lists.coocook.org](https://lists.coocook.org/)
* or send an email with subject `subscribe` to
[coocook-request@lists.coocook.org](mailto:coocook-request@lists.coocook.org?subject=subscribe)

## Terminology

| Name | Description | Example |
| --- | --- | --- |
| Project | self-contained collection of Coocook data | Paris vacation |
| Meal | an occasion for food on a particular date | lunch at August 15th |
| Dish | an actual food planned for a certain meal | apple pie for lunch on August 15th |
| Recipe | a scalable template for a dish | apple pie |
| Ingredient | an amount of some article for a dish/recipe | 1kg of apples |
| Article | a single sort of food that can be purchased | apples |
| Unit | a type of measurement | kilograms

## Author

Daniel Böhmer <post@daniel-boehmer.de>

## Contributors

* [@ChristinaSi](https://github.com/ChristinaSi) Christina Sixtus
* [@moseschmiedel](https://gitlab.com/moseschmiedel) Mose Schmiedel
* [@rico-hengst](https://github.com/rico-hengst) Rico Hengst
* [@kuro610](https://gitlab.com/kuro610) Kurt Roscher
* [@tjfoerster](https://gitlab.com/tjfoerster) Timon Förster

## Copyright and License

This software is copyright (c) 2015-2024 by Daniel Böhmer.
This web application is free software, licensed under the
[GNU Affero General Public License, Version 3, 19 November 2007](LICENSE).
