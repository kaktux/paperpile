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

package Paperpile::Controller::Ajax::Tree;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Paperpile::Plugins::Import::Feed;
use Data::Dumper;
use 5.010;

# Note: I'm not sure what's best practice to have subs with access to
# $c. Forwarding is clumsy and explicitely passing $c also does not
# feel good.

sub get_node : Local {
  my ( $self, $c ) = @_;

  my $node = $c->request->params->{node};

  my $tree;

  if ( not defined $c->session->{"tree"} ) {
    $tree = $c->model('Library')->restore_tree();
    if ( not defined $tree ) {
      $tree = $c->forward('private/get_default_tree');
    }
    $c->session->{"tree"} = $tree;
  } else {
    $tree = $c->session->{"tree"};
  }

  if ( $node eq 'ROOT' ) {
    $c->stash->{tree} = $self->get_complete_tree( $c, $tree );
    $c->detach('Paperpile::View::JSON::Tree');
  }

  my $subtree = $c->forward( 'private/get_subtree', [ $tree, $node ] );

  # Tags always generated dynamically
  if ( $subtree->getUID =~ /TAGS_ROOT/ ) {
    $c->forward( 'private/get_tags', [$subtree] );
  }

  my @data = ();
  foreach my $child ( $subtree->getAllChildren ) {
    push @data, $self->_get_js_object( $child, $c->request->params->{checked} );
  }
  $c->stash->{tree} = [@data];

  $c->forward('Paperpile::View::JSON::Tree');

}

sub get_complete_tree {

  my ( $self, $c, $tree ) = @_;

  # Tags always generated dynamically
  my $subtree = $c->forward( 'private/get_subtree', [ $tree, 'TAGS_ROOT' ] );
  $c->forward( 'private/get_tags', [$subtree] );

  my $dump = '';

  # Simple way of getting the complete tree. We just create perl
  # expression and eval it. Not elegant but easy to implement starting
  # from the example in the Tree::Simple docs.
  $tree->traverse(
    sub {
      my ($_tree) = @_;
      my $_dump = Dumper( $self->_get_js_object( $_tree, 0 ) );

      # Remove first and last line with "$VAR1={" and "};", resp.
      my @t = split( /\n/, $_dump );
      my @tmp = @t[ 1 .. $#t - 1 ];
      $dump .= '{' . join( "\n", @tmp );
      if ( $_tree->isLeaf ) {
        $dump .= '},';
      } else {
        $dump .= ', children=>[';
      }
    },
    sub {
      my ($_tree) = @_;
      if ( !$_tree->isLeaf ) {
        $dump .= ']},';
      }
    }
  );

  return eval( '[' . $dump . ']' );

}

sub set_visibility : Local {

  my ( $self, $c ) = @_;

  my $node   = $c->request->params->{node_id};
  my $hidden = $c->request->params->{hidden};

  my $tree = $c->session->{"tree"};
  my $subtree = $c->forward( 'private/get_subtree', [ $tree, $node ] );

  $subtree->getNodeValue->{hidden} = $hidden;

  $c->model('Library')->save_tree($tree);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub new_folder : Local {
  my ( $self, $c ) = @_;

  my $node_id   = $c->request->params->{node_id};
  my $parent_id = $c->request->params->{parent_id};

  my $path = $c->request->params->{path};

  my $tree = $c->session->{"tree"};

  my $sub_tree = $c->forward( 'private/get_subtree', [ $tree, $parent_id ] );

  my %params = ( draggable => \1 );

  foreach my $key ( keys %{ $c->request->params } ) {
    next if $key =~ /^_/;
    $params{$key} = $c->request->params->{$key};
  }

  $params{id} = $node_id;
  delete( $params{node_id} );

  my $new = Tree::Simple->new( {%params} );
  $new->setUID($node_id);
  $sub_tree->addChild($new);

  $c->model('Library')->insert_folder($node_id);
  $c->model('Library')->save_tree($tree);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub delete_folder : Local {
  my ( $self, $c ) = @_;

  my $node_id   = $c->request->params->{node_id};
  my $parent_id = $c->request->params->{parent_id};
  my $path      = $c->request->params->{path};
  my $name      = $c->request->params->{name};

  my $tree = $c->session->{"tree"};
  my $subtree = $c->forward( 'private/get_subtree', [ $tree, $node_id ] );

  my @to_delete = ($node_id);

  $subtree->traverse(
    sub {
      my ($_tree) = @_;
      push @to_delete, $_tree->getUID;
    }
  );

  $subtree->getParent->removeChild($subtree);
  $c->model('Library')->save_tree($tree);
  $c->model('Library')->delete_folder( [@to_delete] );

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub delete_from_folder : Local {
  my ( $self, $c ) = @_;

  my $grid_id   = $c->request->params->{grid_id};
  my $rowid     = $c->request->params->{rowid};
  my $folder_id = $c->request->params->{folder_id};

  my $plugin = $c->session->{"grid_$grid_id"};

  $c->model('Library')->delete_from_folder( $rowid, $folder_id );

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub new_active : Local {
  my ( $self, $c ) = @_;

  my $node_id   = $c->request->params->{node_id};
  my $parent_id = $c->request->params->{parent_id};

  my $tree = $c->session->{"tree"};

  my $sub_tree = $c->forward( 'private/get_subtree', [ $tree, $parent_id ] );

  my %params = ();

  foreach my $key ( keys %{ $c->request->params } ) {
    next if $key =~ /^_/;
    $params{$key} = $c->request->params->{$key};
  }

  $params{id} = $node_id;
  delete( $params{node_id} );

  my $new = Tree::Simple->new( {%params} );
  $new->setUID($node_id);
  $sub_tree->addChild($new);

  $c->model('Library')->save_tree($tree);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub new_rss : Local {

  my ( $self, $c ) = @_;

  my $node_id   = $c->request->params->{node_id};
  my $parent_id = $c->request->params->{parent_id};

  my $tree = $c->session->{"tree"};

  my $sub_tree = $c->forward( 'private/get_subtree', [ $tree, $parent_id ] );

  my %params        = ();
  my %plugin_params = ();

  foreach my $key ( keys %{ $c->request->params } ) {
    next if $key =~ /^_/;
    $params{$key} = $c->request->params->{$key};

    if ( $key =~ /^plugin_/ ) {
      my $newKey = $key;
      $newKey =~ s/^plugin_//;
      $plugin_params{$newKey} = $c->request->params->{$key};
    }
  }

  $params{id} = $node_id;
  delete( $params{node_id} );

  my $plugin = Paperpile::Plugins::Import::Feed->new( {%plugin_params} );
  $plugin->connect();

  my $title = $plugin->title;

  if ( length($title) > 20 ) {
    ($title) = $title =~ /(.{1,20}\W)/gms;
    $title .= "...";
  }

  $params{text}         = $title;
  $params{plugin_title} = $title;
  $params{qtip}         = $params{plugin_url};

  my $new = Tree::Simple->new( {%params} );
  $new->setUID($node_id);
  $sub_tree->addChild($new);

  $c->model('Library')->save_tree($tree);

  $c->stash->{title}   = $title;
  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub delete_active : Local {
  my ( $self, $c ) = @_;

  my $node_id = $c->request->params->{node_id};

  my $tree = $c->session->{"tree"};

  my $subtree = $c->forward( 'private/get_subtree', [ $tree, $node_id ] );

  if ( $subtree->getNodeValue->{plugin_name} eq 'Feed' ) {

    my $plugin = Paperpile::Plugins::Import::Feed->new( id => $subtree->getNodeValue->{plugin_id} );
    print STDERR "Inehre outer\n";
    $plugin->cleanup();

  }

  $subtree->getParent->removeChild($subtree);

  $c->model('Library')->save_tree($tree);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub save_node_params : Local {
    my ($self, $c) = @_;

    my $request_params = $c->request->params;
    my $node_id = delete $request_params->{node_id};

    my $tree = $c->session->{"tree"};
    my $subtree = $c->forward( 'private/get_subtree', [ $tree, $node_id ] );

    my $node_params = $subtree->getNodeValue();

    foreach my $key (keys %$request_params) {
	$node_params->{$key} = $request_params->{$key};
    }

    $c->model('Library')->save_tree($tree);
    $c->stash->{success} = 'true';
    $c->forward('Paperpile::View::JSON');
}

sub rename_node : Local {
  my ( $self, $c ) = @_;

  my $node_id  = $c->request->params->{node_id};
  my $new_text = $c->request->params->{new_text};

  my $tree = $c->session->{"tree"};

  my $subtree = $c->forward( 'private/get_subtree', [ $tree, $node_id ] );

  my $pars = $subtree->getNodeValue();

  $pars->{text}         = $new_text;
  $pars->{plugin_title} = $new_text;

  $c->model('Library')->save_tree($tree);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub set_node_order : Local {
  my ( $self, $c ) = @_;

  my $target_node   = $c->request->params->{target_node};
  my $node_id_order = $c->request->params->{node_id_order};
  my @id_order;
  if ( ref $node_id_order eq 'ARRAY' ) {
    @id_order = @{$node_id_order};
  } else {
    @id_order = ($node_id_order);
  }

  my $tree = $c->session->{"tree"};
  my $root = $c->forward( 'private/get_subtree', [ $tree, $target_node ] );

  my @nodes;
  my $i = 0;
  foreach my $id (@id_order) {
    my $node = $c->forward( 'private/get_subtree', [ $tree, $id ] );
    push @nodes, $root->removeChild($node);
  }

  $i = 0;
  foreach my $node (@nodes) {
    $root->insertChild( $i, $node );
    $i++;
  }

  $c->forward( 'private/store_tags', [$root] );
  $c->model('Library')->save_tree($tree);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');
}

sub move_node : Local {
  my ( $self, $c ) = @_;

  # The node that was moved
  my $drop_node = $c->request->params->{drop_node};

  # The node to which it was moved
  my $target_node = $c->request->params->{target_node};

  # Either 'append' for dropping into the node, or 'below' or 'above'
  # for moving nodes on the same level
  my $point = $c->request->params->{point};

  my $tree = $c->session->{"tree"};

  # Get nodes from the ids
  my $drop_subtree   = $c->forward( 'private/get_subtree', [ $tree, $drop_node ] );
  my $target_subtree = $c->forward( 'private/get_subtree', [ $tree, $target_node ] );

  # Remove the subtree that was moved
  $drop_subtree = $drop_subtree->getParent->removeChild($drop_subtree);

  # Re-insert at the appropriate node
  if ( $point eq 'append' ) {
    $target_subtree->addChild($drop_subtree);
  } else {
    my $target_index = $target_subtree->getIndex();
    $target_index++ if ( $point eq 'below' );
    $target_subtree->getParent->insertChild( $target_index, $drop_subtree );
  }

  my $parent = $target_subtree->getParent;
  if ( $parent->getUID =~ /TAGS_ROOT/ ) {
    $c->forward( 'private/store_tags', [$parent] );
  }

  $c->model('Library')->save_tree($tree);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub _get_js_object {

  my ( $self, $node, $checked ) = @_;

  # make deep copy to avoid touching the tree structure which gave
  # unexpected results...
  my $h = { %{ $node->getNodeValue() } };

  # we store node ids explicitely as "UID"s in backend and as
  # "node.id" in frontend
  $h->{id} = $node->getUID;

  # draw a checkbox for configuration mode
  if ($checked) {
    if ( $h->{hidden} ) {
      $h->{checked} = \0;
      $h->{hidden}  = 0;    # During configuration we have to show all nodes
    } else {
      $h->{checked} = \1;
    }
  }

  if ( $h->{hidden} ) {
    $h->{hidden} = \1;
  } else {
    $h->{hidden} = \0;
  }

  if ( $node->isLeaf() ) {
    $h->{expanded} = \1;
    $h->{children} = [];
  }

  $h->{nodeType} = 'async';
  $h->{leaf}     = \0;

  return $h;

}

1;

