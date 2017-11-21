use utf8;
package RfamDB::Result::Author;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME
RfamLive::Result::Author
=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<author>
=cut

__PACKAGE__->table("author");

=head1 ACCESSORS
=head2 author_id
  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
=head2 name
  data_type: 'varchar'
  is_nullable: 0
  size: 20
=head2 last_name
  data_type: 'varchar'
  is_nullable: 1
  size: 50
=head2 initials
  data_type: 'varchar'
  is_nullable: 1
  size: 4
=head2 orcid
  data_type: 'varchar'
  is_nullable: 1
  size: 19
=head2 synonyms
  data_type: 'varchar'
  is_nullable: 1
  size: 100
=cut

__PACKAGE__->add_columns(
  "author_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "last_name",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "initials",
  { data_type => "varchar", is_nullable => 1, size => 4 },
  "orcid",
  { data_type => "varchar", is_nullable => 1, size => 19 },
  "synonyms",
  { data_type => "varchar", is_nullable => 1, size => 100 },
);

=head1 PRIMARY KEY
=over 4
=item * L</author_id>
=back
=cut

__PACKAGE__->set_primary_key("author_id");


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2017-10-03 11:31:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wCq8FS1Lf/nM+XMx0LmWKw

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
