package DBSchema::Dvdtag;

# Created by DBIx::Class::Schema::Loader v0.03000 @ 2006-10-02 08:24:09

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("PK::Auto", "Core");
__PACKAGE__->table("dvdtag");
__PACKAGE__->add_columns("dvd", "tag");
__PACKAGE__->set_primary_key("dvd", "tag");
__PACKAGE__->belongs_to("dvd", "Dvd", { id => "dvd" });
__PACKAGE__->belongs_to("tag", "Tag", { id => "tag" });

1;

