package Coocook::Controller::Admin;

use Coocook::Base qw(Moose);

BEGIN { extends 'Coocook::Controller' }

sub base : Chained('/base') PathPart('admin') CaptureArgs(0) {
    my ( $self, $c ) = @_;

    my $admin_urls = $c->stash->{admin_urls};

    my @items = (
        { url => $c->stash->{admin_url},       text => "Admin" },
        { url => $admin_urls->{faq},           text => "FAQ" },
        { url => $admin_urls->{organizations}, text => "Organizations" },
        { url => $admin_urls->{projects},      text => "Projects" },
        { url => $admin_urls->{recipes},       text => "Recipes" },
        { url => $admin_urls->{terms},         text => "Terms" },
        { url => $admin_urls->{users},         text => "Users" },
    );

    $_->{url} or $_->{forbidden} = 1 for @items;

    $c->stash( submenu_items => \@items );
}

sub index : GET HEAD Chained('base') PathPart('') Args(0) RequiresCapability('admin_view') {
    my ( $self, $c ) = @_;

    my $max_organizations = 5;
    my $max_projects      = 10;
    my $max_recipes       = 10;
    my $max_users         = 10;

    my @organizations = $c->model('DB::Organization')
      ->search( undef, { order_by => { -desc => 'created' }, rows => $max_organizations } )->hri->all;

    $_->{url} = $c->uri_for_action( '/organization/show', [ $_->{name} ] ) for @organizations;

    my @projects = $c->model('DB::Project')
      ->search( undef, { order_by => { -desc => 'created' }, rows => $max_projects } )->hri->all;

    $_->{url} = $c->uri_for_action( '/project/show', [ $_->{id}, $_->{url_name} ] ) for @projects;

    my $recipes = $c->model('DB::Recipe');

    $c->forward(
        '/browse/recipe/index',
        [
            $recipes->search(
                undef,
                {
                    join     => 'project',
                    order_by => { -desc => $recipes->me('created') },
                    rows     => $max_recipes,
                }
            )
        ]
    );

    my @users = $c->model('DB::User')
      ->search( undef, { order_by => { -desc => 'created' }, rows => $max_users } )->hri->all;

    $_->{url} = $c->uri_for_action( '/admin/user/show', [ $_->{name} ] ) for @users;

    $c->stash(
        organizations => \@organizations,
        projects      => \@projects,
        users         => \@users,
    );

}

sub organizations : GET HEAD Chained('base') Args(0) RequiresCapability('admin_view') {
    my ( $self, $c ) = @_;

    my @organizations = $c->model('DB::Organization')->sorted->hri->all;

    for my $organization (@organizations) {
        $organization->{url} = $c->uri_for_action( '/organization/show', [ $organization->{name} ] );
    }

    $c->stash( organizations => \@organizations );
}

sub projects : GET HEAD Chained('base') Args(0) RequiresCapability('admin_view') {
    my ( $self, $c ) = @_;

    # we expect every users to have >=1 projects
    # so better not preload 1:n relationship 'users'
    my @projects = $c->model('DB::Project')->sorted->hri->all;

    my %users = map { $_->{id} => $_ } $c->model('DB::User')->with_projects_count->hri->all;

    for my $project (@projects) {
        $project->{owner} = $users{ $project->{owner_id} } || die;
        $project->{url}   = $c->uri_for_action( '/project/show', [ $project->{id}, $project->{url_name} ] );
    }

    for my $user ( values %users ) {
        $user->{url} = $c->uri_for_action( '/user/show', [ $user->{name} ] );
    }

    $c->stash( projects => \@projects );
}

sub recipes : GET HEAD Chained('base') Args(0) RequiresCapability('admin_view') {
    my ( $self, $c ) = @_;

    my $recipes = $c->model('DB::Recipe');

    $c->forward( '/browse/recipe/index',
        [ $recipes->search( undef, { order_by => $recipes->me('name') } ) ] );

}

__PACKAGE__->meta->make_immutable;

1;
