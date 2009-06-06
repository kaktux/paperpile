package Paperpile::Controller::Root;

use strict;
use warnings;
use MIME::Types qw(by_suffix);
use parent 'Catalyst::Controller';

__PACKAGE__->config->{namespace} = '';


sub index : Path : Args(0) {
  my ( $self, $c ) = @_;

  # Add dynamically all *js files in the  plugins directory
  my @list=glob($c->path_to('root/js/import/plugins')."/*js");
  push @list, glob($c->path_to('root/js/export/plugins')."/*js");

  my @plugins=();

  foreach my $plugin (@list){
    my ($volume,$directories,$file) = File::Spec->splitpath( $plugin );
    if ($directories =~/import/){
      push @plugins, "import/plugins/$file";
    } else {
      push @plugins, "export/plugins/$file";
    }

  }
  $c->stash->{plugins}=[@plugins];

  $c->stash->{template} = 'main.mas';
  $c->forward('Paperpile::View::Mason');
}

sub scratch : Local {
  my ( $self, $c ) = @_;
  $c->stash->{template} = 'scratch.mas';
  $c->forward('Paperpile::View::Mason');
}

sub scratch2 : Local {
  my ( $self, $c ) = @_;
  $c->stash->{template} = 'scratch2.mas';
  $c->forward('Paperpile::View::Mason');
}

sub default : Path {
  my ( $self, $c ) = @_;
  $c->response->body('Page not found');
  $c->response->status(404);

}

sub serve : Regex('^serve/(.*)$') {

  my ( $self, $c ) = @_;

  my $file = $c->req->captures->[0];

  my $root= $c->model('User')->get_setting('paper_root');

  my $path= File::Spec->catfile( $root, $file );

  if (not open(IN, $path)){
    $c->response->status(404);
    $c->response->body("Could not open $path.");
  } else {

    my $data='';

    my ($mime_type, $encoding) = by_suffix($file);

    $data.=$_ foreach (<IN>);
    $c->response->status(200);
    $c->response->content_type($mime_type);
    $c->response->body($data);
  }
}


sub end : Private {
  my ( $self, $c ) = @_;

  if ( scalar @{ $c->error } ) {
    $c->response->status(500);
    $c->stash->{error}   = join('<br>',@{$c->error});
    $c->forward('Paperpile::View::JSON');

    foreach my $error (@{$c->error}){
      $c->log->error($error);
    }

    $c->error(0);
  }

  return 1 if $c->response->status =~ /^3\d\d$/;
  return 1 if $c->response->body;

  $c->forward('Paperpile::View::JSON');

}



#sub end : ActionClass('RenderView') {
#}


1;
