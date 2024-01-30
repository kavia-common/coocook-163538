package Coocook::Schema::Result::ArticleTag;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::Result';

__PACKAGE__->table('articles_tags');

__PACKAGE__->add_columns(
    article_id => { data_type => 'integer' },
    tag_id     => { data_type => 'integer' },
);

__PACKAGE__->set_primary_key(qw<article_id tag_id>);

__PACKAGE__->belongs_to( article => 'Coocook::Schema::Result::Article', 'article_id' );
__PACKAGE__->belongs_to( tag     => 'Coocook::Schema::Result::Tag',     'tag_id' );

__PACKAGE__->meta->make_immutable;

1;
