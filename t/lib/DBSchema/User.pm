package DBSchema::User;

# Created by DBIx::Class::Schema::Loader v0.03000 @ 2006-10-02 08:24:09

use strict;
use warnings;

use base 'DBIx::Class';
use overload '""' => sub {$_[0]->name}, fallback => 1;

__PACKAGE__->load_components("PK::Auto", "Core");
__PACKAGE__->table("user");
__PACKAGE__->add_columns(
    "id" => {
        data_type => 'integer',
        is_auto_increment => 1,
    },
    "username" => {
        data_type => 'varchar',
        size      => '100',
    },
    "password" => {
        data_type => 'varchar',
        size      => '100',
    },
    "name" => {
        data_type => 'varchar',
        size      => '100',
      },
  );
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many("user_roles", "UserRole", { "foreign.user" => "self.id" });
__PACKAGE__->has_many("dvd_owners", "Dvd", { "foreign.owner" => "self.id" });
__PACKAGE__->has_many(
  "dvd_current_owners",
  "Dvd",
  { "foreign.current_owner" => "self.id" },
);
__PACKAGE__->many_to_many('roles', 'user_roles' => 'role');

1;

