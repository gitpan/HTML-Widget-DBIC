package DBSchema::Dvd;

# Created by DBIx::Class::Schema::Loader v0.03000 @ 2006-10-02 08:24:09

use strict;
use warnings;

use base 'DBIx::Class';
use overload '""' => sub {$_[0]->name}, fallback => 1;

__PACKAGE__->load_components("PK::Auto", "Core");
__PACKAGE__->table("dvd");
__PACKAGE__->add_columns(
  "id" => {
    data_type => 'integer',
    is_auto_increment => 1
  },
  'name' => {
    data_type => 'varchar',
    size      => 100,
    is_nullable => 1,
  },
  "imdb_id" => {
    data_type => 'varchar',
    size      => 100,
    is_nullable => 1,
  },
  "owner" => { data_type => 'integer' },
  "current_owner" => { data_type => 'integer' },

  "creation_date" => { data_type => 'datetime' },
  "alter_date" => { data_type => 'datetime' },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to("owner", "User", { id => "owner" });
__PACKAGE__->belongs_to("current_owner", "User", { id => "current_owner" });
__PACKAGE__->has_many("dvdtags", "Dvdtag", { "foreign.dvd" => "self.id" });
__PACKAGE__->many_to_many('tags', 'dvdtags' => 'tag');

1;

