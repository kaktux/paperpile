package Paperpile::Build;
use Moose;

use Paperpile::Model::User;
use Paperpile::Model::Library;
use Paperpile::Utils;

use Data::Dumper;
use File::Path;
use File::Find;
use File::Spec::Functions qw(catfile);
use File::Copy::Recursive qw(fcopy dircopy);
use YAML qw(LoadFile DumpFile);

has cat_dir  => ( is => 'rw' );    # catalyst directory
has ti_dir   => ( is => 'rw' );    # titanium directory
has dist_dir => ( is => 'rw' );    # distribution directory
has yui_jar  => ( is => 'rw' );    #YUI compressor jar

# File patterns to ignore while packaging

my %ignore = (
  all => [
    qr([~#]),                qr{/tmp/},
    qr{/t/},                 qr{\.gitignore},
    qr{base/CORE/},          qr{base/pod/},
    qr{(base|cpan)/CPAN},    qr{(base|cpan)/Test},
    qr{base/unicore/.*txt$}, qr{runtime/(template|webinspector|installer)},
    qr{ext3/examples},       qr{ext3/src}
  ],

  linux64 => [qr{/(perl5|bin)/(linux32|osx|win32)}],
  linux32 => [qr{/(perl5|bin)/(linux64|osx|win32)}],

);


## Initialize database files

sub initdb {

  my $self = shift;

  chdir $self->cat_dir . "/db";

  foreach my $key ( 'app', 'user', 'library' ) {
    print STDERR "Initializing $key.db...\n";
    unlink "$key.db";
    my @out = `sqlite3 $key.db < $key.sql`;
    print @out;
  }

  my $model = Paperpile::Model::Library->new();
  $model->set_dsn( "dbi:SQLite:" . "library.db" );

  my $config = LoadFile('../paperpile.yaml');

  foreach my $field ( keys %{ $config->{pub_fields} } ) {
    $model->dbh->do("ALTER TABLE Publications ADD COLUMN $field TEXT");
  }

  # Just for now set some defaults here, will be refactored to set these
  # defaults with all other defaults in the Controller
  $model->dbh->do("INSERT INTO Tags (tag,style) VALUES ('Important',11);");
  $model->dbh->do("INSERT INTO Tags (tag,style) VALUES ('Review',22);");

  print STDERR "Importing journal list into app.db...\n";

  open( JOURNALS, "<../data/journals.list" );
  $model = Paperpile::Model::App->new();
  $model->set_dsn( "dbi:SQLite:" . "../db/app.db" );

  $model->dbh->begin_work();

  my %data = ();

  my %seen = ();

  foreach my $line (<JOURNALS>) {

    next if $line =~ /^$/;
    next if $line =~ /^\s*#/;

    my ( $long, $short, $issn, $essn, $source, $url, $reviewed ) = split( /;/, $line );

    $short    = $model->dbh->quote($short);
    $long     = $model->dbh->quote($long);
    $issn     = $model->dbh->quote($issn);
    $essn     = $model->dbh->quote($essn);
    $source   = $model->dbh->quote($source);
    $url      = $model->dbh->quote($url);
    $reviewed = $model->dbh->quote($reviewed);

    next if $seen{$short};

    $seen{$short} = 1;

    $model->dbh->do(
      "INSERT OR IGNORE INTO Journals (short, long, issn, essn, source, url, reviewed) VALUES ($short, $long, $issn, $essn, $source, $url, $reviewed);"
    );

    my $rowid = $model->dbh->func('last_insert_rowid');
    print STDERR "$rowid $short $long\n";
    $model->dbh->do("INSERT INTO Journals_lookup (rowid,short,long) VALUES ($rowid,$short,$long)");

  }

  $model->dbh->commit();

}

## Pack everything in directory for distribution

sub make_dist {

  my ( $self, $platform, $build_number ) = @_;

  my ( $dist_dir, $cat_dir, $ti_dir ) = ( $self->dist_dir, $self->cat_dir, $self->ti_dir );

  $ti_dir = catfile( $ti_dir, $platform );

  `rm -rf $dist_dir/$platform`;

  my @ignore = ();

  push @ignore, @{ $ignore{all} };
  push @ignore, @{ $ignore{$platform} };

  mkpath( catfile("$dist_dir/$platform/catalyst") );

  my $list = $self->_get_list( $cat_dir, \@ignore );
  $self->_copy_list( $list, $cat_dir, "$platform/catalyst" );

  $list = $self->_get_list( $ti_dir, \@ignore );
  $self->_copy_list( $list, $ti_dir, $platform );

  symlink "catalyst/root", "$dist_dir/$platform/Resources";


  # Update configuration file for current build
  my $yaml = "$dist_dir/$platform/catalyst/paperpile.yaml";
  my $config = LoadFile($yaml);

  $config->{app_settings}->{platform} = $platform;

  if ($build_number){
    $config->{app_settings}->{build_number} = $build_number;
  }

  DumpFile($yaml, $config);

}

## Concatenate/minify Javascript and CSS

sub minify {

  my $self = shift;

  my $cat_dir = $self->cat_dir;

  my $yui = $self->yui_jar;

  if ( not -e $yui ) {
    die("YUI compressor jar file not found. $yui does not exist");
  }

  my $data = LoadFile("$cat_dir/data/resources.yaml");

  my $all_css = "$cat_dir/root/css/all.css";

  unlink($all_css);

  foreach my $file ( @{ $data->{css} } ) {
    `cat $cat_dir/root/$file >> $all_css`;
  }

  my $all_js = "$cat_dir/root/js/all.js";

  unlink($all_js);

  foreach my $file ( @{ $data->{js} } ) {
    `cat $cat_dir/root/$file >> tmp.js`;
  }
  my @plugins = glob("$cat_dir/root/js/??port/plugins/*js");
  foreach my $file (@plugins) {
    `cat $file >> tmp.js`;
  }

  `java -jar $yui tmp.js -o $all_js`;

  unlink('tmp.js');

}

sub _get_list {

  my ( $self, $source_dir, $ignore ) = @_;

  my @list = ();

  find( {
      no_chdir => 1,
      wanted   => sub {
        my $name = $File::Find::name;
        return if -d $name;
        foreach my $r (@$ignore) {
          return if $name =~ $r;
        }
        push @list, File::Spec->abs2rel( $name, $source_dir );
        }
    },
    $source_dir
  );

  return \@list;

}

sub _copy_list {
  my ( $self, $list, $source_dir, $prefix ) = @_;
  foreach my $file (@$list) {
    fcopy( catfile( $source_dir, $file ), catfile( $self->dist_dir, $prefix, $file ) )
      or die( $!, $file );
  }
}

