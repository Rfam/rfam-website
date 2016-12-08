use utf8;
package PfamDB::PfamaWiki;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PfamDB::PfamaWiki

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<pfamA_wiki>

=cut

__PACKAGE__->table("pfamA_wiki");

=head1 ACCESSORS

=head2 pfama_acc

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 7

=head2 auto_wiki

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "pfama_acc",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 7 },
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

=head2 pfama_acc

Type: belongs_to

Related object: L<PfamDB::Pfama>

=cut

__PACKAGE__->belongs_to("pfama_acc", "PfamDB::Pfama", { pfama_acc => "pfama_acc" });


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-04-22 10:42:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:I/4387pRTbHwyITANx9o7A


# You can replace this text with custom content, and it will be preserved on regeneration
1;
