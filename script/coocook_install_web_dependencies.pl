#!/usr/bin/env perl

# ABSTRACT: script for managing external dependencies downloaded from the internet

use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/../lib";
use Coocook::Base;

use File::Basename;
use File::Fetch;
use File::Path qw/rmtree make_path/;
use Term::ANSIColor;
use Term::Size::Any;
use YAML::XS;

my $YAML_FILENAME = 'web-dependencies.yaml';

if ( not -f $YAML_FILENAME ) {
    error('This script can only be executed in the top-level coocook repository');
}

my $yaml         = YAML::XS::LoadFile($YAML_FILENAME);
my @dependencies = map { WebDependency->new($_) } $yaml->{dependencies}->@*;

say colored( '=== downloading coocook web dependencies ===', 'cyan' );
download( \@dependencies );
say '';
say colored( '=== installing coocook web dependencies ===', 'cyan' );
install( \@dependencies );

sub download ($deps) {
    make_path '.cache';

    for my $pkg ( $deps->@* ) {
        $pkg->print_command('downloading');

        # test if the package archive was already downloaded
        if ( not( -e '.cache/' . $pkg->archive_name ) ) {
            $pkg->download( dest_dir => '.cache' );
            if ( not( -e '.cache/' . $pkg->archive_name ) ) {
                $pkg->print_status('FAILED');
            }
            else {
                $pkg->print_status('SUCCESS');
            }
        }
        else {
            $pkg->print_status('CACHED');
        }
    }
}

sub install ($deps) {
    for my $pkg ( $deps->@* ) {
        rmtree 'root/static/lib/' . $pkg->name;
        make_path 'root/static/lib/' . $pkg->name;

        $pkg->print_command('installing');
        $pkg->extract();
        $pkg->print_status('SUCCESS');
    }
}

package WebDependency {
    use Term::ANSIColor;
    use File::Copy::Recursive qw/rmove/;

    sub new ( $class, $pkg_hash ) {
        $pkg_hash->{extract_paths} ||= [];
        my $self = {
            name          => $pkg_hash->{name},
            url           => $pkg_hash->{url},
            version       => $pkg_hash->{version},
            extract_paths => [
                map {
                    $_->[0] =~ s/\$\{VERSION\}/$pkg_hash->{version}/g;
                    $_->[1] =~ s/\$\{VERSION\}/$pkg_hash->{version}/g;
                    $_
                } $pkg_hash->{extract_paths}->@*
            ],
        };

        # replace version placeholder with actual version number
        $self->{url} =~ s/\$\{VERSION\}/$self->{version}/g;
        $self->{ff} = File::Fetch->new( uri => $self->{url} );

        return bless $self, $class;
    }

    sub name          ($self) { $self->{name} }
    sub url           ($self) { $self->{url} }
    sub version       ($self) { $self->{version} }
    sub ff            ($self) { $self->{ff} }
    sub extract_paths ($self) { $self->{extract_paths} }
    sub archive_name  ($self) { $self->ff->output_file }

    sub print_command ( $self, $command ) {

        my $pkg_id         = $self->name . '@' . $self->version;
        my $status_width   = length "SUCCESS";
        my $terminal_width = Term::Size::Any::chars() || undef;
        my $command_width  = length "$command ";
        my $right_margin   = 1;
        my $status_margin  = 1;
        my $min_points     = 3;

        my $points =
          defined $terminal_width
          ? ( $terminal_width -
              $right_margin -
              $command_width -
              $status_width -
              $status_margin -
              length "$pkg_id " )
          : $min_points;

        print "$command $pkg_id ", '.' x ( $points < $min_points ? $min_points : $points );
    }

    sub print_status ( $self, $status ) {
        if ( $status eq 'SUCCESS' ) {
            say colored( " $status", 'green' );
        }
        elsif ( $status eq 'CACHED' ) {
            say colored( "  $status", 'green' );
        }
        elsif ( $status eq 'FAILED' ) {
            say colored( "  $status", 'red' );
        }
    }

    sub download ( $self, %args ) {
        $self->ff->fetch( to => $args{dest_dir} )
          or error( $self->ff->error(1) );
    }

    sub extract ($self) {
        my $archive_name = $self->archive_name;
        my $tmp_dir      = File::Temp->newdir();

        # compression formats supported by tar
        # see https://en.wikipedia.org/wiki/Tar_(computing)#Suffixes_for_compressed_files
        if ( $archive_name =~ / \. tar \. (bz2|gz|lz|lzma|lzo|xz|Z|zst) $/x ) {
            my @tar_args = ( 'tar', '--extract', '--file' => ".cache/$archive_name" );
            if ( $self->extract_paths->@* ) {
                push @tar_args, ( '--directory' => $tmp_dir->dirname );
                for my $mapping ( $self->extract_paths->@* ) {
                    push @tar_args, "$mapping->[0]";
                }
            }
            else {
                push @tar_args, '--directory' => 'root/static/lib/' . $self->name;
            }
            system(@tar_args);
        }
        elsif ( $archive_name =~ / \. zip $/x ) {
            my @unzip_args = ( 'unzip', '-q', ".cache/$archive_name" );
            if ( $self->extract_paths->@* ) {
                for my $mapping ( $self->extract_paths->@* ) {
                    if ( $mapping->[0] =~ m{ / $ }x ) {
                        push @unzip_args, $mapping->[0] . "*";
                    }
                    else {
                        push @unzip_args, $mapping->[0];
                    }
                }
                push @unzip_args, ( '-d' => $tmp_dir->dirname );
            }
            else {
                push @unzip_args, ( '-d' => 'root/static/lib/' . $self->name );
            }
            system(@unzip_args);
        }
        else {
            error("unsupported archive format: '$archive_name'");
        }
        if ( $self->extract_paths->@* ) {
            for my $mapping ( $self->extract_paths->@* ) {
                if ( $mapping->[1] ) {
                    rmove( $tmp_dir->dirname . "/$mapping->[0]", 'root/static/lib/' . $self->name . "/$mapping->[1]" );
                }
            }
        }
    }
}

sub error ($msg) {
    say '';
    die colored( $msg, 'red' ) . "\n";
}
