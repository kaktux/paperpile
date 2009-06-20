package Paperpile::Controller::Screens;

use strict;
use warnings;
use parent 'Catalyst::Controller';


sub patterns : Local {
  my ( $self, $c ) = @_;
  $c->stash->{template} = '/screens/patterns.mas';
  $c->forward('Paperpile::View::Mason');
}

sub settings : Local {
  my ( $self, $c ) = @_;
  $c->stash->{template} = '/screens/settings.mas';
  $c->forward('Paperpile::View::Mason');
}

sub dashboard : Local {
  my ( $self, $c ) = @_;
  $c->stash->{template} = '/screens/dashboard.mas';
  $c->forward('Paperpile::View::Mason');
}



1;
