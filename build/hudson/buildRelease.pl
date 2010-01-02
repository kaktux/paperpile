#! catalyst/perl5/linux32/bin/perl -w

# Our build machine is 32 bit and Hudson runs this script from the top
# level in the workspace. So we need the above perl binary.

use strict;

use FindBin;
use lib "$FindBin::Bin/../../catalyst/lib";
use YAML qw(LoadFile DumpFile);

use Data::Dumper;

use Paperpile;
use Paperpile::Build;


################# Setup configuration variables ######################

my @targets = ('linux32','linux64');

my $workspace = `pwd`;
chomp($workspace);

my $b = Paperpile::Build->new( {
    cat_dir  => "$workspace/catalyst",
    ti_dir   => "$workspace/titanium",
    dist_dir => "$workspace/dist/data",
    yui_jar  => $ENV{HOME} . '/bin/yuicompressor-2.4.2.jar',
  }
);

my $settings = LoadFile('catalyst/conf/settings.yaml');

my ( $version_name, $version_id ) =
  ( $settings->{app_settings}->{version_name}, $settings->{app_settings}->{version_id} );

my $prev_version = $version_id - 1;

#################### Create distribution #############################

unlink glob("dist/*tar.gz");

$b->echo("Minifying javascript");
$b->minify;

for my $target (@targets) {

  $b->echo("Making distribution $target");
  $b->make_dist( $target, $ENV{BUILD_NUMBER} );

  chdir "$workspace/dist/data";
  $b->echo("Packaging $target");
  `mv $target paperpile`;
  `tar czf ../paperpile-$version_name-$target.tar.gz paperpile`;
  `mv paperpile $target`;
}


######  Move data to release directory and set up symbolic links #####


my $rel_dir = $ENV{HOME} . "/release";

`rm -rf  $rel_dir/$version_name` if -e "$rel_dir/$version_name";
`rm  $rel_dir/$version_id`       if -l "$rel_dir/$version_id";

`mkdir $rel_dir/$version_name`;
`mv $workspace/dist/* $rel_dir/$version_name`;

chdir $rel_dir;

`ln -s $version_name $version_id`;
`rm  stage` if -l "stage";
`ln -s $version_name stage`;

#################### Create patches if necessary #####################

my $release_info = $settings->{release};

if ( $release_info->{patch} ) {

  if ( not -e "$rel_dir/$prev_version" ) {
    die("Version $prev_version does not exist for patch");
  }

  for my $target (@targets) {

    $b->echo("Create patch for $target");

    $b->create_patch(
      "$rel_dir/$prev_version/data/$target",
      "$rel_dir/$version_id/data/$target",
      "$rel_dir/$version_id/data/patch-$prev_version\_to_$version_id-$target"
    );


    $b->echo("Zipping patch for $target");
    chdir "$rel_dir/$version_id/data";
    `zip -r patch-$prev_version\_to_$version_id-$target patch-$prev_version\_to_$version_id-$target`;
    `mv patch-$prev_version\_to_$version_id-$target.zip ..`;


    my $stats =
      $b->file_stats("$rel_dir/$version_id/patch-$prev_version\_to_$version_id-$target.zip");

    $release_info->{md5}->{$target}  = $stats->{md5};
    $release_info->{size}->{$target} = $stats->{size};

  }
}

############ Update yaml file for the new new release ################

$release_info->{id}   = $settings->{app_settings}->{version_id};
$release_info->{name} = $settings->{app_settings}->{version_name};

my $update_info = LoadFile("$rel_dir/$prev_version/updates.yaml");
unshift @$update_info, { release => $release_info };

DumpFile( "$rel_dir/$version_id/updates.yaml", $update_info );


################### Tag the release on github ########################

chdir($workspace);

my $tag = "rel_$version_id\_$version_name";

`git tag -f -a -m "Release $version_id (v $version_name)" $tag`;

# Try to delete remote tag first in case it already exists
# (i.e. another build came to this point but was not accepted as
# release eventually)
`git push origin :refs/tags/$tag`;
`git push origin tag $tag`;