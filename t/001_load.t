# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More tests => 3;
use lib 't/lib';
use DBSchema;

BEGIN { use_ok('HTML::Widget::DBIC'); }

my $config = [
    {
        'foreign_class'  => 'Dvd',
        'widget_element' => [ 'Select', 'multiple' => 1 ],
        'name'           => 'dvds',
        'label'          => 'Dvds',
        'bridge_rel'     => 'dvdtags'
    },
    {
        'widget_element' => [
            'Textarea', 
            'rows' => 5,
            'cols' => 60
        ],
        'constraints' => [
            {
                'max'        => '255',
                'constraint' => 'Length',
                'message'    => 'Should be shorten than 255 characters'
            },
            {
                'constraint' => 'All',
                'message'    => 'The field is required'
            }
        ],
        'name'  => 'name',
        'label' => 'Name'
    },
    {
        'primary_key' => 1,
        'name'        => 'id',
        'label'       => 'Id'
    }
];

my $dsn    = 'dbi:SQLite:dbname=t/var/dvdzbr.db';
my $schema = DBSchema->connect( $dsn, '', '', {} );

my $rs = $schema->resultset( 'Tag' );
my $object = HTML::Widget::DBIC->create_from_config( $config, $rs );
isa_ok( $object, 'HTML::Widget::DBIC' );

my $result = $object->process;
isa_ok( $result, 'HTML::Widget::Result::DBIC');

