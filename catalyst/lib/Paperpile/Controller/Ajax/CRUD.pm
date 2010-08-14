# Copyright 2009, 2010 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.  You should have received a
# copy of the GNU General Public License along with Paperpile.  If
# not, see http://www.gnu.org/licenses.

package Paperpile::Controller::Ajax::CRUD;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Paperpile::Plugins::Import::Duplicates; # <-- delete me afterwards
use Paperpile::Job;
use Paperpile::Queue;
use Paperpile::FileSync;
use Data::Dumper;
use HTML::TreeBuilder;
use HTML::FormatText;
use File::Path;
use File::Spec;
use File::Copy;
use File::stat;
use URI::file;
use FreezeThaw;

use 5.010;

sub insert_entry : Local {
  my ( $self, $c ) = @_;

  my $grid_id   = $c->request->params->{grid_id};
  my $plugin    = $self->_get_plugin($c);
  my $selection = $self->_get_selection($c);
  my %output    = ();

  # Go through and complete publication details if necessary.
  my @pub_array = ();
  foreach my $pub (@$selection) {
    if ( $plugin->needs_completing($pub) ) {
      $pub = $plugin->complete_details($pub);
    }
    if ( $plugin->needs_match_before_import($pub) ) {
      my $j = Paperpile::Job->new(
        type => 'METADATA_UPDATE',
        pub  => $pub,
      );

      # We're 'stealing' the _match method from the metadata update job type
      # in order to match the article against the user's choice of web resources
      # before importing it here.
      my $success = $j->_match;
      if ($success) {
        $pub = $j->pub;
      }
    }

    push @pub_array, $pub;
  }

  # In case a pdf is present but not imported (e.g. in bibtex file
  # plugin with attachments) we set _pdf_tmp to make sure the PDF is
  # imported
  foreach my $pub (@pub_array) {
    if ( $pub->pdf_name and !$pub->_imported ) {
      $pub->_pdf_tmp( $pub->pdf_name );
    }
  }

  $c->model('Library')->insert_pubs( \@pub_array, 1 );

  my $pubs = {};
  foreach my $pub (@pub_array) {
    $pub->_imported(1);
    my $pub_hash = $pub->as_hash;
    $pubs->{ $pub_hash->{guid} } = $pub_hash;
  }

  # If the number of imported pubs is reasonable, we return the updated pub data
  # directly and don't reload the entire grid that triggered the import.
  if ( scalar( keys %$pubs ) < 50 ) {
    $c->stash->{data} = { pubs => $pubs };
    $c->stash->{data}->{pub_delta_ignore} = $grid_id;
  }

  # Trigger a complete reload
  $c->stash->{data}->{pub_delta} = 1;

  # Probably not the most efficient way but works for now
  $c->stash->{data}->{file_sync_delta} = $self->_get_sync_collections( $c, \@pub_array );

  $self->_update_counts($c);

}

sub complete_entry : Local {

  my ( $self, $c ) = @_;
  my $plugin    = $self->_get_plugin($c);
  my $selection = $self->_get_selection($c);

  my $cancel_handle = $c->request->params->{cancel_handle};

  Paperpile::Utils->register_cancel_handle($cancel_handle);

  my @new_pubs = ();
  my $results  = {};
  foreach my $pub (@$selection) {
    my $pub_hash;
    if ( $plugin->needs_completing($pub) ) {
      my $new_pub = $plugin->complete_details($pub);
      $pub_hash = $new_pub->as_hash;
    }
    $results->{ $pub_hash->{guid} } = $pub_hash;
  }

  $c->stash->{data} = { pubs => $results };

  Paperpile::Utils->clear_cancel($$);

}

sub new_entry : Local {

  my ( $self, $c ) = @_;

  my $match_job = $c->request->params->{match_job};

  my %fields = ();

  foreach my $key ( %{ $c->request->params } ) {
    next if $key =~ /^_/;
    $fields{$key} = $c->request->params->{$key};
  }

  my $pub = Paperpile::Library::Publication->new( {%fields} );

  $c->model('Library')->exists_pub( [$pub] );

  if ( $pub->_imported ) {
    DuplicateError->throw("Updates duplicate an existing reference in the database");
  }

  my $job;

  # Inserting a PDF that failed to match automatically and that has a
  # jobid in the queue.
  if ($match_job) {
    $job = Paperpile::Job->new( { id => $match_job } );
    $pub->_pdf_tmp( $job->pub->pdf );
  }

  $c->model('Library')->insert_pubs( [$pub], 1 );

  $self->_update_counts($c);

  # That's handled as form on the front-end so we have to explicitly
  # indicate success
  $c->stash->{success} = \1;

  $c->stash->{data}->{pub_delta} = 1;

  # Update the job entry here.
  if ($job) {
    $job->update_status('DONE');
    $job->error('');
    $job->update_info( 'msg', "Data inserted manually." );
    $job->pub($pub);
    $job->save;
    $c->stash->{data}->{jobs}->{$match_job} = $job->as_hash;
  }

  $c->stash->{data}->{file_sync_delta} = $self->_get_sync_collections( $c, [$pub]);

}

sub empty_trash : Local {
  my ( $self, $c ) = @_;

  my $library = $c->model('Library');
  my $data    = $library->get_trashed_pubs;
  $library->delete_pubs($data);

  $c->stash->{data} = { pub_delta => 1 };
  $c->stash->{num_deleted} = scalar @$data;
}

sub delete_entry : Local {
  my ( $self, $c ) = @_;
  my $plugin = $self->_get_plugin($c);
  my $mode   = $c->request->params->{mode};

  my $data = $self->_get_selection($c);

  # ignore all entries that are not imported
  my @imported = ();
  foreach my $pub (@$data) {
    next if not $pub->_imported;
    push @imported, $pub;
  }

  $data = [@imported];

  $c->model('Library')->delete_pubs($data) if $mode eq 'DELETE';
  $c->model('Library')->trash_pubs( $data, 'RESTORE' ) if $mode eq 'RESTORE';

  if ( $mode eq 'TRASH' ) {
    $c->model('Library')->trash_pubs( $data, 'TRASH' );
    $c->session->{"undo_trash"} = $data;
  }

  $self->_collect_update_data( $c, $data, [ '_imported', 'trashed' ] );

  $c->stash->{data}->{pub_delta} = 1;
  $c->stash->{num_deleted} = scalar @$data;

  $plugin->total_entries( $plugin->total_entries - scalar(@$data) );

  $self->_update_counts($c);

  $c->stash->{data}->{file_sync_delta} = $self->_get_sync_collections( $c, $data );
  $c->stash->{data}->{undo_url} = '/ajax/crud/undo_trash';

}

sub undo_trash : Local {

  my ( $self, $c ) = @_;

  my $data = $c->session->{"undo_trash"};

  $c->model('Library')->trash_pubs( $data, 'RESTORE' );

  delete( $c->session->{undo_trash} );

  $self->_update_counts($c);

  $c->stash->{data}->{pub_delta} = 1;

  $c->stash->{data}->{file_sync_delta} = $self->_get_sync_collections( $c, $data )

}

sub update_entry : Local {
  my ( $self, $c ) = @_;

  my $guid = $c->request->params->{guid};

  my $new_data = {};
  foreach my $field ( keys %{ $c->request->params } ) {
    next if $field =~ /grid_id/;
    $new_data->{$field} = $c->request->params->{$field};
  }

  my $new_pub = $c->model('Library')->update_pub( $guid, $new_data );

  foreach my $var ( keys %{ $c->session } ) {
    next if !( $var =~ /^grid_/ );
    my $plugin = $c->session->{$var};
    if ( $plugin->plugin_name eq 'DB' or $plugin->plugin_name eq 'Trash' ) {
      if ( $plugin->_hash->{$guid} ) {
        delete( $plugin->_hash->{$guid} );
        $plugin->_hash->{ $new_pub->guid } = $new_pub;
      }
    }
  }

  # That's handled as form on the front-end so we have to explicitly
  # indicate success
  $c->stash->{success} = \1;

  my $hash = $new_pub->as_hash;

  $c->stash->{data} = { pubs => { $guid => $hash } };

  $c->stash->{data}->{file_sync_delta} = $self->_get_sync_collections( $c, [$new_pub] )

}

sub lookup_entry : Local {
  my ( $self, $c ) = @_;

  my $old_data = {};
  foreach my $field ( keys %{ $c->request->params } ) {
    next if $field =~ /grid_id/;
    $old_data->{$field} = $c->request->params->{$field};
  }

  my $pub = Paperpile::Library::Publication->new($old_data);

  # Get default plugin order
  my @plugin_list = split( /,/, $c->model('Library')->get_setting('search_seq') );

  # Re-order list if identifiers are given
  if ( $pub->arxivid ) {
    @plugin_list = ( 'ArXiv', grep { $_ ne 'ArXiv' } @plugin_list );
  }
  if ( $pub->pmid ) {
    @plugin_list = ( 'PubMed', grep { $_ ne 'PubMed' } @plugin_list );
  }

  # Try plugins until a match is found
  my $success_plugin = undef;

  my $caught_error = undef;

  foreach my $plugin_name (@plugin_list) {
    eval {
      my $plugin_module = "Paperpile::Plugins::Import::" . $plugin_name;
      my $plugin        = eval( "use $plugin_module; $plugin_module->" . 'new()' );
      $pub = $plugin->match($pub);
    };

    my $e;
    if ( $e = Exception::Class->caught ) {

      # Did not find a match, continue with next plugin
      if ( Exception::Class->caught('NetMatchError') ) {
        next;
      }

      # Other exception has occured; still try other plugins but save
      # error message to show if all plugins fail
      else {
        if ( ref $e ) {
          $caught_error = $e->error;
          next;
        }

        # Abort on unexpected exception
        else {
          die($@);
        }
      }
    }

    # Found match -> stop now
    else {
      $success_plugin = $plugin_name;
      $caught_error   = undef;
      last;
    }
  }

  $c->stash->{error}          = $caught_error;
  $c->stash->{success_plugin} = $success_plugin;

  if ($success_plugin) {

    my $new_data = $pub->as_hash;

    $new_data->{guid} = '';

    $c->stash->{data} = $new_data;
  }

  # We always set success unless an unexpected exception occured and
  # handle everything in the success callback in the front-end.
  $c->stash->{success} = \1;

}

sub _match_single {

  my ( $self, $match_plugin ) = @_;

  my $plugin_module = "Paperpile::Plugins::Import::" . $match_plugin;
  my $plugin        = eval( "use $plugin_module; $plugin_module->" . 'new()' );

  my $pub = $self->pub;

  $pub = $plugin->match($pub);

  $self->pub($pub);

}

sub update_notes : Local {
  my ( $self, $c ) = @_;

  my $rowid = $c->request->params->{rowid};
  my $guid  = $c->request->params->{guid};
  my $html  = $c->request->params->{html};

  my $dbh = $c->model('Library')->dbh;

  my $value = $dbh->quote($html);
  $dbh->do("UPDATE Publications SET annote=$value WHERE rowid=$rowid");

  my $tree      = HTML::TreeBuilder->new->parse($html);
  my $formatter = HTML::FormatText->new( leftmargin => 0, rightmargin => 72 );
  my $text      = $formatter->format($tree);

  $value = $dbh->quote($text);

  $dbh->do("UPDATE Fulltext SET notes=$value WHERE rowid=$rowid");

  $c->stash->{data} = { pubs => { $guid => { annote => $html } } };

}

sub new_collection : Local {
  my ( $self, $c ) = @_;

  my $guid   = $c->request->params->{node_id};
  my $parent = $c->request->params->{parent_id};
  my $name   = $c->request->params->{text};
  my $type   = $c->request->params->{type};
  my $style  = $c->request->params->{style} || '0';

  $c->model('Library')->new_collection( $guid, $name, $type, $parent, $style );
}

sub move_in_collection : Local {
  my ( $self, $c ) = @_;

  my $grid_id = $c->request->params->{grid_id};
  my $guid    = $c->request->params->{guid};
  my $type    = $c->request->params->{type};
  my $data    = $self->_get_selection($c);

  my $what = $type eq 'FOLDER' ? 'folders' : 'tags';

  # First import entries that are not already in the database
  my @to_be_imported = ();
  foreach my $pub (@$data) {
    push @to_be_imported, $pub if !$pub->_imported;
  }

  $c->model('Library')->insert_pubs( \@to_be_imported, 1 );

  my $dbh = $c->model('Library')->dbh;

  if ( $guid ne 'FOLDER_ROOT' ) {
    my $new_guid = $guid;

    $c->model('Library')->add_to_collection( $data, $new_guid );
  }

  if (@to_be_imported) {
    $self->_update_counts($c);
    $self->_collect_update_data( $c, $data, [ $what, '_imported', 'citekey', 'created', 'pdf' ] );
    $c->stash->{data}->{pub_delta}        = 1;
    $c->stash->{data}->{pub_delta_ignore} = $grid_id;
  } else {
    $self->_collect_update_data( $c, $data, [$what] );
  }
  $c->stash->{data}->{collection_delta} = 1;

  $c->stash->{data}->{file_sync_delta} = $self->_get_sync_collections( $c, undef, $guid );
}

sub remove_from_collection : Local {
  my ( $self, $c ) = @_;

  my $collection_guid = $c->request->params->{collection_guid};
  my $type            = $c->request->params->{type};

  my $data = $self->_get_selection($c);

  my $what = $type eq 'FOLDER' ? 'folders' : 'tags';

  $c->model('Library')->remove_from_collection( $data, $collection_guid);

  $self->_collect_update_data( $c, $data, [$what] );
  $c->stash->{data}->{collection_delta} = 1;

  $c->stash->{data}->{file_sync_delta} = $self->_get_sync_collections( $c, undef, $collection_guid );

}

sub delete_collection : Local {
  my ( $self, $c ) = @_;

  my $guid = $c->request->params->{guid};
  my $type = $c->request->params->{type};

  $c->model('Library')->delete_collection( $guid, $type );

  # Not sure if we need to update the tree structure in the
  # backend in some way here.

  my $what = $type eq 'FOLDER' ? 'folders' : 'tags';

  my $pubs = $self->_get_cached_data($c);
  foreach my $pub (@$pubs) {
    my $new_list = $pub->$what;
    $new_list =~ s/^$guid,//g;
    $new_list =~ s/^$guid$//g;
    $new_list =~ s/,$guid$//g;
    $new_list =~ s/,$guid,/,/g;
    $pub->$what($new_list);
  }

  $self->_collect_update_data( $c, $pubs, [$what] );
  $c->stash->{data}->{collection_delta} = 1;
}

sub rename_collection : Local {
  my ( $self, $c ) = @_;

  my $guid     = $c->request->params->{guid};
  my $new_name = $c->request->params->{new_name};

  $c->model('Library')->rename_collection( $guid, $new_name );

  my $type = 'TAGS';
  my $what = $type eq 'FOLDER' ? 'folders' : 'tags';
  my $pubs = $self->_get_cached_data($c);
  $self->_collect_update_data( $c, $pubs, [$what] );
  $c->stash->{data}->{collection_delta} = 1;
}

sub move_collection : Local {
  my ( $self, $c ) = @_;

  # The node that was moved
  my $drop_guid = $c->request->params->{drop_node};

  # The node to which it was moved
  my $target_guid = $c->request->params->{target_node};

  my $type = $c->request->params->{type};

  # Either 'append' for dropping into the node, or 'below' or 'above'
  # for moving nodes on the same level
  my $position = $c->request->params->{point};

  $c->model('Library')->move_collection( $target_guid, $drop_guid, $position, $type );

  $c->stash->{data}->{collection_delta} = 1;
}

# Sorts a set of sibling collection nodes by the given order of IDs.
sub sort_collection : Local {
  my ( $self, $c ) = @_;

  my $m = $c->model('Library');

  # The desired order of nodes, given as a list of GUIDs.
  my $node_id_order = $c->request->params->{node_id_order};
  my @id_order;
  if ( ref $node_id_order eq 'ARRAY' ) {
    @id_order = @{$node_id_order};
  } else {
    @id_order = ($node_id_order);
  }

  # The parent node under which all these nodes live, given as a GUID.
  my $parent_id = $c->request->params->{parent_id};
  my $type      = $m->get_collection_type($parent_id);

  print STDERR "TYPE: $type\n";

  # Go in order, putting each sub-node at the end of the parent node's child list.
  foreach my $id (@id_order) {
    $m->move_collection( $parent_id, $id, 'append', $type );
  }
}

sub style_collection : Local {
  my ( $self, $c ) = @_;

  my $guid  = $c->request->params->{guid};
  my $style = $c->request->params->{style};

  $c->model('Library')->set_collection_style( $guid, $style );
  $c->stash->{data}->{collection_delta} = 1;
}

sub list_labels : Local {

  my ( $self, $c ) = @_;

  my $sth = $c->model('Library')->dbh->prepare("SELECT * FROM Collections WHERE type='LABEL'");

  my @data = ();

  $sth->execute;
  while ( my $row = $sth->fetchrow_hashref() ) {
    push @data, {
      name  => $row->{name},
      style => $row->{style},
      guid  => $row->{guid},
      };
  }

  my %metaData = (
    root   => 'data',
    fields => [ 'name', 'style', 'guid' ],
  );

  $c->stash->{data} = [@data];

  $c->stash->{metaData} = {%metaData};

}

# Returns the list of labels sorted by tag counts.
sub list_labels_sorted : Local {
  my ( $self, $c ) = @_;

  my $hist = $c->model('Library')->histogram('tags');
  my @data = ();

  foreach
    my $key ( sort { $hist->{$b}->{count} <=> $hist->{$a}->{count} || $a <=> $b } keys %$hist ) {
    my $tag = $hist->{$key};
    push @data, $tag;
  }

  $c->stash->{data} = \@data;
}

sub batch_update : Local {
  my ( $self, $c ) = @_;
  my $plugin = $self->_get_plugin($c);
  my $data   = $self->_get_selection($c);

  my $q    = Paperpile::Queue->new();
  my @jobs = ();
  foreach my $pub (@$data) {
    my $j = Paperpile::Job->new(
      type => 'METADATA_UPDATE',
      pub  => $pub,
    );

    $j->hidden(1) if (scalar(@$data) == 1);

    $j->pub->_metadata_job( { id => $j->id, status => $j->status, msg => $j->info->{msg}, hidden => $j->hidden } );

    push @jobs, $j;
  }

  $q->submit( \@jobs );
  $q->save;
  $q->run;
  $self->_collect_update_data( $c, $data, ['_metadata_job'] );

  $c->stash->{data}->{job_delta} = 1;
  $c->detach('Paperpile::View::JSON');
}

sub batch_download : Local {
  my ( $self, $c ) = @_;
  my $plugin = $self->_get_plugin($c);

  my $data = $self->_get_selection($c);

  my $q = Paperpile::Queue->new();

  my @jobs = ();

  foreach my $pub (@$data) {
    my $j = Paperpile::Job->new(
      type => 'PDF_SEARCH',
      pub  => $pub
    );

    $j->hidden(1) if (scalar(@$data) == 1);

    $j->pub->_search_job( { id => $j->id, status => $j->status, msg => $j->info->{msg}, hidden => $j->hidden } );

    push @jobs, $j;
  }

  $q->submit( \@jobs );
  $q->save;
  $q->run;
  $self->_collect_update_data( $c, $data, ['_search_job'] );

  $c->stash->{data}->{job_delta} = 1;

  $c->detach('Paperpile::View::JSON');

}

sub attach_file : Local {
  my ( $self, $c ) = @_;

  my $guid   = $c->request->params->{guid};
  my $file   = $c->request->params->{file};
  my $is_pdf = $c->request->params->{is_pdf};

  my $grid_id = $c->request->params->{grid_id};
  my $plugin  = $c->session->{"grid_$grid_id"};

  my $pub = $plugin->find_guid($guid);

  $c->model('Library')->attach_file( $file, $is_pdf, $pub );

  $self->_collect_update_data( $c, [$pub],
    [ 'pdf', 'pdf_name', 'attachments', '_attachments_list' ] );

}

sub delete_file : Local {
  my ( $self, $c ) = @_;

  my $file_guid = $c->request->params->{file_guid};
  my $pub_guid  = $c->request->params->{pub_guid};
  my $is_pdf    = $c->request->params->{is_pdf};

  my $grid_id = $c->request->params->{grid_id};
  my $plugin  = $c->session->{"grid_$grid_id"};

  my $pub = $plugin->find_guid($pub_guid);

  my $undo_path = $c->model('Library')->delete_attachment( $file_guid, $is_pdf, $pub, 1 );

  $c->session->{"undo_delete_attachment"} = {
    file      => $undo_path,
    is_pdf    => $is_pdf,
    grid_id   => $grid_id,
    pub_guid  => $pub_guid,
    file_guid => $file_guid
  };

  # Kind of a hack: delete the _search_job info before sending back our JSON update.
  if ($is_pdf) {
    delete $pub->{_search_job};
  }

  $self->_collect_update_data( $c, [$pub],
    [ 'attachments', '_attachments_list', 'pdf', '_search_job' ] );

}

sub undo_delete : Local {
  my ( $self, $c ) = @_;

  my $undo_data = $c->session->{"undo_delete_attachment"};

  delete( $c->session->{undo_delete_attachment} );

  my $file   = $undo_data->{file};
  my $is_pdf = $undo_data->{is_pdf};

  my $grid_id   = $undo_data->{grid_id};
  my $pub_guid  = $undo_data->{pub_guid};
  my $file_guid = $undo_data->{file_guid};

  my $plugin = $c->session->{"grid_$grid_id"};

  my $pub = $plugin->find_guid($pub_guid);

  my $attached_file = $c->model('Library')->attach_file( $file, $is_pdf, $pub, $file_guid );

  $self->_collect_update_data( $c, [$pub], [ 'pdf', 'attachments', '_attachments_list' ] );

}

sub merge_duplicates : Local {
  my ( $self, $c ) = @_;

  my $grid_id     = $c->request->params->{grid_id};
  my $ref_guid    = $c->request->param('ref_guid');
  my @other_guids = $c->request->param('other_guids');

  my $plugin  = $c->session->{"grid_$grid_id"};
  my $library = $c->model('Library');

  my $undo_data;

  my $ref_pub = $plugin->find_guid($ref_guid);

  #    Error->throw("No ref pub!") unless (defined $ref_pub);

  my $merged_pub = Paperpile::Library::Publication->new( $ref_pub->as_hash );
  $merged_pub->refresh_fields;
  $merged_pub->_imported(0);
  $merged_pub->guid(undef);
  $merged_pub->title('');
  $library->insert_pubs( [$merged_pub], 1 );

  my @other_pubs;
  my @orig_pub_hashes;
  foreach my $other_guid ( $ref_guid, @other_guids ) {
    print STDERR "$ref_guid  -> $other_guid\n";
    my $pub = $plugin->find_guid($other_guid);
    push @orig_pub_hashes, $pub->as_hash;
    if ($pub) {
      $merged_pub->merge_into_me( $pub, $library );
      $pub->title( '[Discarded Duplicate] ' . $pub->title );
      $library->update_pub( $pub->guid, $pub->as_hash );
      push @other_pubs, $pub;
    }
  }

  push @orig_pub_hashes, $ref_pub->as_hash;
  push @other_pubs,      $ref_pub;

  $undo_data->{orig_pubs}  = \@orig_pub_hashes;
  $undo_data->{merged_pub} = $merged_pub->as_hash;

  # Trash all the pre-merge pubs.
  $library->trash_pubs( \@other_pubs, 'TRASH' );
  $library->update_pub( $merged_pub->guid, $merged_pub->as_hash );

  # Delete the duplicates cache.
  $plugin->connect;

  $self->_collect_update_data( $c, [$merged_pub] );
  $c->stash->{data}->{pub_delta} = 1;

  $c->session->{"undo_merge_duplicates"} = $undo_data;
}

sub undo_merge_duplicates : Local {
    my ($self, $c) = @_;

    my $data = $c->session->{"undo_merge_duplicates"};
    my $library = $c->model('Library');

    # So, we've got the 'other' pubs, which are trashed and have a prefix added
    # to their title. Take care of those first.

    # Restore the other pubs.
    my $orig_pub_hashes = $data->{orig_pubs};
    my @orig_pub_objs;
    foreach my $pub_hash (@{$orig_pub_hashes}) {
	my $pub = Paperpile::Library::Publication->new($pub_hash);
	push @orig_pub_objs, $pub;
    }
    $library->trash_pubs(\@orig_pub_objs,'RESTORE');

    # Delete the merged pub.
    my $merged_hash = $data->{merged_pub};
    my $merged_pub = Paperpile::Library::Publication->new($merged_hash);
    $library->delete_pubs([$merged_pub]);

    # Remove the prefix from their titles.
    foreach my $pub_hash (@{$orig_pub_hashes}) {
	my $title = $pub_hash->{title};
	$title =~ s/\[Discarded Duplicate\] //gi;
	print STDERR "Title: $title\n";
	$pub_hash->{$title} = $title;
	$library->update_pub($pub_hash->{guid},$pub_hash);
    }

    $self->_collect_update_data($c, \@orig_pub_objs);
    $c->stash->{data}->{pub_delta} = 1;
}

sub sync_files : Local {

  my ( $self, $c ) = @_;

  # Get non-redundant list of collections
  my %tmp;
  foreach my $collection ( split( /,/, $c->request->params->{collections} ) ) {
    $tmp{$collection} = 1;
  }
  my @collections = keys %tmp;

  my $map = $c->model('User')->get_setting('file_sync');

  my $sync = Paperpile::FileSync->new( map => $map );

  my %warnings;

  foreach my $collection (@collections) {
    eval { $sync->sync_collection($collection); };
    my $warning = 'A problem occured during BibTeX export. ';

    if ($@) {
      my $e = Exception::Class->caught();
      if ( ref $e ) {
        $warning = $e->error;
      } else {
        $warning .= $@;
      }
      $warnings{$collection} = $warning;
      $c->log->error($warning);
    }
  }

  $c->stash->{data}->{warnings} = {%warnings};

}

# Returns list of all collection guids that need to be re-synced when
# references in $data change. If $guid is given and $data is undefined
# the function checks if $guid or its parents need to be synced,

sub _get_sync_collections {
  my ( $self, $c, $data, $guid ) = @_;

  my $sync_files = $c->model('User')->get_setting('file_sync');

  return [] if !( ref $sync_files );

  my $model = $c->model('Library');
  my $dbh   = $model->dbh;

  my %collections;

  # Either take $guid or search folders or tags field of publications
  # in $data
  if ( defined $guid ) {
    $collections{$guid}=1;
  } else {
    foreach my $pub (@$data) {
      my @tmp;
      if ( $pub->folders ) {
        push @tmp, split( /,/, $pub->folders );
      }
      if ( $pub->tags ) {
        push @tmp, split( /,/, $pub->tags );
      }
      foreach my $collection (@tmp) {
        $collections{$collection} = 1;
      }
    }
  }


  # Add parents for subfolder and only consider collections whith an
  # active fileync setting
  my %final_collections;

  foreach my $collection (keys %collections) {
    my @parents = $model->find_collection_parents( $collection, $dbh );

    foreach my $parent (@parents){
      if ($sync_files->{$parent}->{active}){
        $final_collections{$parent} = 1;
      }
    }

    if ($sync_files->{$collection}->{active}){
      $final_collections{$collection} = 1;
    }
  }

  # Always add FOLDER_ROOT if active
  if ( $sync_files->{'FOLDER_ROOT'}->{active} ) {
    $final_collections{'FOLDER_ROOT'} = 1;
  }

  return [keys %final_collections];

}


# Returns the plugin object in the backend corresponding to an AJAX
# request from the frontend
sub _get_plugin {
  my ( $self, $c ) = @_;
  my $grid_id = $c->request->params->{grid_id};
  return $c->session->{"grid_$grid_id"};
}

# Gets data for a selection in the frontend from the plugin object cache
sub _get_selection {

  my ( $self, $c, $light_objects ) = @_;

  my $grid_id   = $c->request->params->{grid_id};
  my $selection = $c->request->params->{selection};
  my $plugin    = $self->_get_plugin($c);

  $plugin->light_objects( $light_objects ? 1 : 0 );

  my @data = ();

  if ( $selection eq 'ALL' ) {
    @data = @{ $plugin->all };
    $c->model('Library')->exists_pub( \@data );
    foreach my $pub (@data) {
      $pub->refresh_attachments;
    }
  } else {
    my @tmp;
    if ( ref($selection) eq 'ARRAY' ) {
      @tmp = @$selection;
    } else {
      push @tmp, $selection;
    }
    for my $guid (@tmp) {
      my $pub = $plugin->find_guid($guid);
      if ( defined $pub ) {
        push @data, $pub;
      }
    }
  }

  return [@data];
}

# Returns a list of all publications objects from all current plugin
# objects (i.e. all open grid tabs in the frontend)
sub _get_cached_data {

  my ( $self, $c ) = @_;

  my @list = ();

  foreach my $var ( keys %{ $c->session } ) {
    next if !( $var =~ /^grid_/ );
    my $plugin = $c->session->{$var};
    foreach my $pub ( values %{ $plugin->_hash } ) {
      push @list, $pub;
    }
  }

  return [@list];
}

# If we add or delete items we need to update the overall count in the
# database plugins to make sure the number is up-to-date when it is
# reloaded the next time by the frontend.

sub _update_counts {

  my ( $self, $c ) = @_;

  foreach my $var ( keys %{ $c->session } ) {
    next if !( $var =~ /^grid_/ );
    my $plugin = $c->session->{$var};
    if ( $plugin->plugin_name eq 'DB' or $plugin->plugin_name eq 'Trash' ) {
      $plugin->update_count();
    }
  }
}

sub _collect_update_data {
  my ( $self, $c, $pubs, $fields ) = @_;

  $c->stash->{data} = {} unless ( defined $c->stash->{data} );

  my $max_output_size = 30;
  if ( scalar(@$pubs) > $max_output_size ) {
    $c->stash->{data}->{pub_delta} = 1;
    @$pubs = @$pubs[ 1 .. $max_output_size ];
  }

  my %output = ();
  foreach my $pub (@$pubs) {
    my $hash = $pub->as_hash;

    my $pub_fields = {};
    if ($fields) {
      map { $pub_fields->{$_} = $hash->{$_} } @$fields;
    } else {
      $pub_fields = $hash;
    }
    $output{ $hash->{guid} } = $pub_fields;
  }

  $c->stash->{data}->{pubs} = \%output;
}

1;
