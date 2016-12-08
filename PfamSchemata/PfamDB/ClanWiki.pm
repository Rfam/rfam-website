use utf8;
package PfamDB::ClanWiki;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PfamDB::ClanWiki

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<clan_wiki>

=cut

__PACKAGE__->table("clan_wiki");

=head1 ACCESSORS

=head2 clan_acc

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 6

=head2 auto_wiki

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "clan_acc",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 6 },
  "auto_wiki",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);

=head1 RELATIONS

=head2 auto_wiki

Type: belongs_to

Related object: L<PfamDB::Wikipedia>

=cut

__PACKAGE__->belongs_to("auto_wiki", "PfamDB::Wikipedia", { auto_wiki => "auto_wiki" });

=head2 clan_acc

Type: belongs_to

Related object: L<PfamDB::Clan>

=cut

__PACKAGE__->belongs_to("clan_acc", "PfamDB::Clan", { clan_acc => "clan_acc" });


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-04-22 10:42:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jwatfjFp9U9cbVg80fGvPw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
