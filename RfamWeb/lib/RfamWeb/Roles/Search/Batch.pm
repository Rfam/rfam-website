
# Batch.pm
# jt6 20120514 WTSI
#
# $Id$

=head1 NAME

RfamWeb::Roles::Search::Batch - role containing actions related to batch
sequence searching

=cut

package RfamWeb::Roles::Search::Batch;

=head1 DESCRIPTION

A role to add batch sequence search-related methods to the main search
controller.

$Id$

=cut

use MooseX::MethodAttributes::Role;
use namespace::autoclean;

use Email::Valid;
use DateTime;

with 'PfamBase::Roles::Search::Batch';

#-------------------------------------------------------------------------------

=head1 METHODS

=head2 batch : Chained('search') PathPart('batch') Args(0)

Executes a batch sequence search. 

=cut

sub batch : Chained( 'search' )
            PathPart( 'batch' )
            Args(0) {
  my ( $this, $c ) = @_;

  # Store $jobId and $email_address in the stash
  $c->stash->{jobId} = $c->req->param('jobId');
  $c->stash->{email_address} = $c->req->param('email_address');

  # Before handing off to the template, set a refresh URI that will be
  # picked up by head.tt and used in a meta refresh element
  $c->stash->{refreshUri}   = $c->uri_for( '/search' );
  $c->stash->{refreshDelay} = 300;
  
  $c->log->debug( 'Search::batch: protein batch search submitted' )
    if $c->debug; 
  $c->stash->{template} = 'pages/search/sequence/batchSubmitted.tt';
}

#-------------------------------------------------------------------------------

=head1 AUTHOR

John Tate, C<jt6@sanger.ac.uk>

=head1 COPYRIGHT

Copyright (c) 2012 Genome Research Ltd.

Authors: John Tate (jt6@sanger.ac.uk)

This is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
this program. If not, see <http://www.gnu.org/licenses/>.

=cut

1;

