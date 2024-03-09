use Coocook::Base;
use Test2::V0 -no_warnings => 1;

use Coocook::Model::PurchaseList;
use DateTime;
use Test::Memory::Cycle;
use Test::MockObject;

use lib 't/lib';
use TestDB;

my $db = TestDB->new;

ok my $list =
  Coocook::Model::PurchaseList->new( list => $db->resultset('PurchaseList')->find(1) );

ok my $sections = $list->shop_sections;

is $sections => array {
    item hash {
        field id         => 1;
        field project_id => 1;
        field name       => "bakery products";
        field items      => array {
            item hash {
                field id                => 1;
                field purchase_list_id  => 1;
                field value             => 14.5;
                field offset            => +0;
                field total             => 14.5;
                field next_lower_total  => 14;
                field next_higher_total => 15;
                field unit_id           => 2;
                field unit              => hash { field short_name => "kg";    etc() };
                field article           => hash { field name       => "flour"; etc() };
                field article_id        => 1;
                field convertible_into  => array {
                    item hash {
                        field value      => 14500;
                        field short_name => 'g';
                        field suggested  => T();
                        etc();
                    };
                    item hash {
                        field value      => 0.0145;
                        field short_name => 't';
                        field suggested  => F();
                        etc();
                    };
                };
                field purchased   => F();
                field ingredients => array {
                    item hash {
                        field id   => 1;
                        field dish => hash {
                            field name    => "pancakes";
                            field comment => "sweet";
                            field meal    => hash {
                                field id   => 1;
                                field date => object {
                                    prop isa => 'DateTime';
                                    call ymd => '2000-01-01';
                                };
                                field name    => "breakfast";
                                field comment => "Best meal of the day!";
                                etc();
                            };
                            etc();
                        };
                        etc();
                    };
                    item hash { field id => 4;  etc() };
                    item hash { field id => 7;  etc() };
                    item hash { field id => 11; etc() };
                };
                field comment => "";
                end();
            };
            item hash {
                field id                => 2;
                field value             => 42.5;
                field offset            => +0.5;
                field total             => 43.0;
                field next_lower_total  => 42;
                field next_higher_total => 44;
                field unit              => hash { field short_name => "g";    etc() };
                field article           => hash { field name       => "salt"; field comment => "NaCl"; etc() };
                field convertible_into  => array {
                    item hash {
                        field value      => 0.0425;
                        field offset     => +0.0005;
                        field short_name => 'kg';
                        field suggested  => F();
                        etc();
                    };
                    item hash {
                        field value      => 0.0000425;
                        field offset     => 0.0000005;
                        field short_name => 't';
                        field suggested  => F();
                        etc();
                    };
                };
                field ingredients => array {
                    item hash { field id => 2; etc() };
                    item hash { field id => 6; etc() };
                    item hash { field id => 8; etc() };
                };
                field comment => "rounded to integer";
                etc();
            };
        };
    };
    etc();
},
  "->shop_sections()";

memory_cycle_ok $sections, "result of by_section() is free of memory cycles";

subtest _sort_convertible_into => sub {
    my $t = sub (@expected) {
        is Coocook::Model::PurchaseList::_sort_convertible_into( [ reverse @expected ] ) => \@expected;
    };

    $t->( { suggested => 1 }, { suggested => 0 } );

    $t->( { total => 2 }, { total => 1 } );

    $t->(
        { total => 1 },
        { total => 10 },
        { total => 100 },
        { total => 0.1 },
        { total => 1000 },
        { total => 0.01 },
        { total => 0.001 },
        { total => 1 / 3 },
    );
};

done_testing;
