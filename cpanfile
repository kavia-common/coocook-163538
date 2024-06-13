on 'configure' => sub {
    requires "ExtUtils::MakeMaker::CPANfile";
};

requires "perl" => "v5.34";
recommends "perl" => "v5.40";

requires "App::DH";
requires "Carp";
requires "Catalyst";
requires "Catalyst::Action::RenderView";
requires "Catalyst::Authentication::Store::DBIx::Class";
requires "Catalyst::Authentication::Store::DBIx::Class::User";
requires "Catalyst::Controller";
requires "Catalyst::Model";
requires "Catalyst::Model::DBIC::Schema";
requires "Catalyst::Plugin::Authentication";
requires "Catalyst::Plugin::ConfigLoader";
requires "Catalyst::Plugin::Session::State::Cookie";
requires "Catalyst::Plugin::Session::Store::DBIC";
requires "Catalyst::Plugin::Session::Store::FastMmap";
requires "Catalyst::Plugin::Static::Simple";
requires "Catalyst::Runtime" => "5.80";
requires "Catalyst::Test";
requires "Catalyst::View";
requires "Catalyst::View::JSON";
requires "Catalyst::View::TT";
requires "Clone";
requires "Crypt::Argon2";
requires "Crypt::Digest::SHA256";
requires "DBIx::Class::Core";
requires "DBIx::Class::DeploymentHandler";
requires "DBIx::Class::FilterColumn";
requires "DBIx::Class::Helpers" => "2.036000";    # supports RS->results_exist() with condition
requires "DBIx::Class::Helpers::Util";
requires "DBIx::Class::InflateColumn::DateTime";
requires "DBIx::Class::ResultSet";
requires "DBIx::Class::Schema::Config";
requires "DBIx::Class::TimeStamp";
requires "Data::Validate::Email";
requires "DateTime";
requires "Email::Stuffer";
requires "File::Basename";
requires "File::Copy::Recursive";
requires "File::Fetch";
requires "File::Path";
requires "File::Spec";
requires "FindBin";
requires "Getopt::Long";
requires "HTML::Meta::Robots";
requires "JSON::MaybeXS";
requires "MIME::Base64::URLSafe";
requires "Moose" => "2.1400";
requires "Moose::Role";
requires "Moose::Util::TypeConstraints";
requires "MooseX::Getopt";
requires "MooseX::NonMoose";
requires "namespace::autoclean";
requires "Net::SSLeay";
requires "PerlX::Maybe";
requires "SQL::Translator::Producer::SQLite";
requires "SVG";
requires "Scalar::Util";
requires "Storable";
requires "Sub::Util";
requires "Template" => "2.29";
requires "Template::Plugin::Filter";
requires "Template::Plugin::Markdown";
requires "Term::ANSIColor";
requires "Term::ReadKey";
requires "Term::Size::Any";
requires "Try::Tiny";
requires "URI";
requires "YAML::XS";

suggests "DBD::Pg";    # when running on PostgreSQL
suggests "DateTime::Format::Pg";
suggests "Sys::Hostname::FQDN";

on 'test' => sub {
    requires "DBI";
    requires "DBICx::TestDatabase";
    requires "DBIx::Class::Schema";
    requires "DBIx::Class::Schema::Loader";
    requires "DBIx::Diff::Schema";
    requires "Data::Dumper";
    requires "DateTime::Format::SQLite";
    requires "Email::Sender::Simple";
    requires "ExtUtils::MakeMaker";
    requires "HTML::TreeBuilder::XPath";
    requires "Regexp::Common";
    requires "Scope::Guard";
    requires "Sub::Exporter";
    requires "Test2::API";
    requires "Test2::Require::AuthorTesting";
    requires "Test2::Require::Module";
    requires "Test2::V0";
    requires "Test::Builder";
    requires "Test::Compile" => "v2.2.2";
    requires "Test::Memory::Cycle";
    requires "Test::MockObject";
    requires "Test::More";
    requires "Test::Output";
    requires "Test::WWW::Mechanize::Catalyst";
    requires "Time::HiRes";
    requires "WWW::Mechanize::TreeBuilder";

    suggests "Test::PostgreSQL";
};

on 'develop' => sub {
    requires "Module::CPANfile";
    requires "Perl::Tidy" => "== 20240511";
    requires "Sub::Override";
    requires "Test::Perl::Critic";
    requires "Test::PerlTidy";

    recommends "CatalystX::LeakChecker";    # loaded if available
    recommends "DBD::Pg";
    recommends "DateTime::Format::Pg";

    suggests "Catalyst::Plugin::StackTrace";
    suggests "Catalyst::Restarter";
    suggests "Term::Size::Any";
};
