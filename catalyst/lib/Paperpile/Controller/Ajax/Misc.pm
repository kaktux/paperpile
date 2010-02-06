package Paperpile::Controller::Ajax::Misc;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Paperpile::Utils;
use Data::Dumper;
use File::Spec;
use File::Path;
use File::Copy;
use Paperpile::Exceptions;
use MooseX::Timestamp;
use LWP;
use HTTP::Request::Common;
use File::Temp qw(tempfile);
use YAML qw(LoadFile);

use 5.010;

sub reset_db : Local {

  my ( $self, $c ) = @_;

  $c->model('Library')->init_db( $c->config->{pub_fields}, $c->config->{user_settings} );

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub tag_list : Local {

  my ( $self, $c ) = @_;

  my $tags=$c->model('Library')->get_tags;

  my @data=();

  foreach my $row (@$tags){
    push @data, {tag  =>$row->{tag},
                 style=> $row->{style},
                };
  }

  my %metaData = (
   root          => 'data',
   fields        => ['tag', 'style'],
  );

  $c->stash->{data}          = [@data];

  $c->stash->{metaData}      = {%metaData};

  $c->forward('Paperpile::View::JSON');

}

sub journal_list : Local {

  my ( $self, $c ) = @_;
  my $query = $c->request->params->{query};
  my $query_bak = $c->request->params->{query};

  my $model = $c->model('App');

  $query = $model->dbh->quote("$query*");

  my $sth = $model->dbh->prepare(
    "SELECT Journals.short, Journals.long FROM Journals 
     JOIN Journals_lookup ON Journals.rowid=Journals_lookup.rowid 
     WHERE Journals_lookup MATCH $query
     ORDER BY Journals.short;"
  );

  my ( $short, $long );
  $sth->bind_columns( \$short, \$long );
  $sth->execute;

  # we process the raw SQL output in three ways
  # 1) On top we rank those hits that exactly match the query
  # 2) Next we take those hits that start with the query. These
  #    hits are then sorted by the second word in the short title
  # 3) anything else
  my @data = ( );
  my @quality1 = ( );
  my @quality2 = ( );
  
  while ( $sth->fetch ) {
      if ( $long =~ m/^$query_bak$/i ) {
	  push @data, { long => $long, short => $short };
	  next;
      }
      if ( $short =~ m/^$query_bak$/i ) {
	  push @data, { long => $long, short => $short };
	  next;
      }
      if ( $long =~ m/^$query_bak/i and $long !~ m/\s/ ) {
	  push @data, { long => $long, short => $short };
	  next;
      }
      if ( $long =~ m/^$query_bak/i ) {
	  ( my $next_words = $short ) =~ s/(\S+\s)(\S+)/$2/;
	  if ( $next_words =~ m/^\(/ ) {
	    push @data, { long => $long, short => $short };
	    next;
	  }
	  push @quality1, { long => $long, short => $short, next_words => $next_words };
	  next;
      }
      push @quality2, { long => $long, short => $short };
  }

  my @sorted = sort { uc($a->{'next_words'}) cmp uc($b->{'next_words'}) } @quality1;
  foreach my $entry ( @sorted ) {
      push @data, $entry;
  }
  foreach my $entry ( @quality2 ) {
      push @data, $entry;
  }

  $c->stash->{data} = [@data];
  $c->forward('Paperpile::View::JSON');

}

sub get_settings : Local {

  my ( $self, $c ) = @_;

  # app_settings are read from the config file, they are never changed
  # by the user and constant for a specific version of the application
  my @list1 = %{ $c->config->{app_settings}};

  my @list2 = %{ $c->model('User')->settings };
  my @list3 = %{ $c->model('Library')->settings };

  my %merged = ( @list1, @list2, @list3 );

  my $fields = LoadFile($c->path_to('conf/fields.yaml'));

  foreach my $key ( 'pub_types', 'pub_fields', 'pub_tooltips', 'pub_identifiers' ) {
    $merged{$key} = $fields->{$key};
  }

  $c->stash->{data} = {%merged};

  $c->forward('Paperpile::View::JSON');

}

sub import_journals : Local {
  my ( $self, $c ) = @_;

  my $file="/home/wash/play/Paperpile/data/jabref.txt";

  my $sth=$c->model('Library')->dbh->prepare("INSERT INTO Journals (key,name) VALUES(?,?)");

  open( TMP, "<$file" );

  my %alreadySeen = ();

  while (<TMP>) {
    next if /^\s*\#/;
    ( my $long, my $short ) = split /=/, $_;
    $short =~ s/;.*$//;
    $short =~ s/[.,-]/ /g;
    $short =~ s/(^\s+|\s+$)//g;
    $long  =~ s/(^\s+|\s+$)//g;

    if ( not $alreadySeen{$short} ) {
      $alreadySeen{$short} = 1;
      next;
    }

    $sth->execute($short,$long);

  }

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub test_network : Local {

  my ( $self, $c ) = @_;

  my $browser = Paperpile::Utils->get_browser($c->request->params);

  my $response = $browser->get('http://google.com');

  if ( $response->is_error ) {
    NetGetError->throw(
      error => 'Error: ' . $response->message,
      code  => $response->code
    );
  }
}


sub preprocess_csl : Local {

  my ( $self, $c ) = @_;

  my $grid_id = $c->request->params->{grid_id};
  my $selection = $c->request->params->{selection};
  my $plugin = $c->session->{"grid_$grid_id"};

  my @data = ();

  if ($selection eq 'ALL'){
    @data = @{$plugin->all};
  } else {
    my @tmp;
    if ( ref($selection) eq 'ARRAY' ) {
      @tmp = @$selection;
    } else {
      push @tmp, $selection;
    }
    for my $sha1 (@tmp) {
      my $pub = $plugin->find_sha1($sha1);
      push @data, $pub;
    }
  }

  my @output=();

  my $style_file=$c->path_to('root/csl/style/nature.csl');
  my $locale_file=$c->path_to('root/csl/locale/locales-en-US.xml');

  my $style='';
  my $locale='';

  open(IN,"<$style_file");
  $style.=$_ while <IN>;

  open(IN,"<$locale_file");
  $locale.=$_ while <IN>;

  $locale=~s/<\?.*\?>//g;
  $style=~s/<\?.*\?>//g;

  print STDERR "$locale";

  foreach my $pub (@data){
    push @output, $pub->format_csl;
  }

  $c->stash->{data}=[@output];
  $c->stash->{style}=$style;
  $c->stash->{locale}=$locale;

}


sub clean_duplicates : Local {
  my ( $self, $c ) = @_;
  my $grid_id = $c->request->params->{grid_id};
  my $plugin = $c->session->{"grid_$grid_id"};

  $c->forward('Paperpile::View::JSON');

}


sub inc_read_counter : Local {

  my ( $self, $c ) = @_;
  my $rowid      = $c->request->params->{rowid};
  my $sha1       = $c->request->params->{sha1};
  my $times_read = $c->request->params->{times_read};

  my $touched = timestamp gmtime;
  $c->model('Library')
    ->dbh->do("UPDATE Publications SET times_read=times_read+1,last_read='$touched' WHERE rowid=$rowid");

  $c->stash->{data} =
    { pubs => { $sha1 => { last_read => $touched, times_read => $times_read + 1 } } };

}

sub report_error : Local {

  my ( $self, $c ) = @_;

  my $error        = $c->request->params->{error};
  my $catalyst_log = $c->request->params->{catalyst_log};

  my $browser = Paperpile::Utils->get_browser();

  my $version_name = $c->config->{app_settings}->{version_name};
  my $version_id     = $c->config->{app_settings}->{version_id};
  my $build_number   = $c->config->{app_settings}->{build_number};
  my $platform       = $c->config->{app_settings}->{platform};

  my $subject =
    "Unknown exception on $platform;  version: $version_id ($version_name); build: $build_number";

  my ( $fh, $filename ) = tempfile( "catalyst-XXXXX", SUFFIX => '.txt' );

  my $attachment = undef;

  if ($catalyst_log) {
    print $fh $catalyst_log;
    $attachment = [$filename];
  }

  my $r = POST 'http://stage.paperpile.com/api/v1/feedback/bugs',
    Content_Type => 'form-data',
    Content      => [
    subject    => $subject,
    body       => $error,
    from       => 'Paperpile client',
    attachment => $attachment,
    ];

  my $response = $browser->request($r);

  unlink($filename);

}





1;
