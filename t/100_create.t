# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More tests => 4;
use lib 't/lib';
use DBSchema;

use HTML::Widget::DBIC; 
use CGI;

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
$schema->deploy({ add_drop_table => 1, });
$schema->populate('User', [
    [ qw/id username name password / ],
    [ 1, 'jgda', 'Jonas Alves', '' ],
    [ 2, 'isa' , 'Isa', '' ],
    [ 3, 'zby' , 'Zbyszek Lukasiak', ''],
    ]
);
$schema->populate('Tag', [
    [ qw/id name/ ],
    [ 1, 'comedy' ],
    ]
);


$schema->populate('Dvd', [
    [ qw/id name imdb_id owner current_owner creation_date alter_date hour/ ],
    [ 1, 'Picnick under the Hanging Rock', 123, 1, 1, '', '', ''],
    [ 2, 'The Deerhunter', 1234, 1, 1, '', '', ''],
    [ 3, 'Rejs', 1235, 1, 1, '', '', ''],
    [ 4, 'Seksmisja', 1236, 1, 1, '', '', ''],
    ]
); 

$schema->populate( 'Dvdtag', [
    [ qw/ dvd tag / ],
    [ 3, 1 ],
    [ 4, 1 ],
    ]
);

my $resultset = $schema->resultset( 'Tag' );
my $widget = HTML::Widget::DBIC->create_from_config( $config, $resultset );
my $result = $widget->process;
ok ( $result->as_xml =~ qr{<label for="widget_dvds" id="widget_dvds_label">Dvds<select class="select" id="widget_dvds" multiple="multiple" name="dvds"><option value="0"></option><option value="1">Picnick under the Hanging Rock</option><option value="2">The Deerhunter</option><option value="3">Rejs</option><option value="4">Seksmisja</option></select></label>}, 'SELECT values from db' ) or warn $result->as_xml; 

my $item = $resultset->find( 1 ); 
$widget = HTML::Widget::DBIC->create_from_config( $config, $resultset, $item );
$result = $widget->process;
ok ( $result->as_xml =~ qr{<option value="0"></option><option value="1">Picnick under the Hanging Rock</option><option value="2">The Deerhunter</option><option selected="selected" value="3">Rejs</option><option selected="selected" value="4">Seksmisja</option>}, 'SELECT selected from item' ) or warn $result->as_xml; 

$widget = HTML::Widget::DBIC->create_from_config( $config, $resultset );
my $query = new CGI( {'name'=>'New Tag', 'dvds'=>[1, 2]});
$result = $widget->process ( $query );
$result->save_to_db();
$item = $resultset->search( { name => 'New Tag' } )->next(); 
my @dvds = $item->dvds();
ok ( scalar @dvds == 2 && $dvds[0]->id == 1, 'Creation and many to many link' );

$widget = HTML::Widget::DBIC->create_from_config( $config, $resultset, $item);
$query = new CGI( {'name'=>'New Tag', 'dvds'=>[3]});
$result = $widget->process ( $query );
$result->save_to_db();
$item = $resultset->search( { name => 'New Tag' } )->next(); 
@dvds = $item->dvds();
ok ( scalar @dvds == 1 && $dvds[0]->id == 3, 'Updating many to many' );


