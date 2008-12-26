package PaperPile::Library::Source::File;

use Carp;
use Data::Page;
use Moose;
use Moose::Util::TypeConstraints;

use PaperPile::Library;
use PaperPile::Model::DB;

extends 'PaperPile::Library::Source';

has 'file' => ( is => 'rw', isa => 'Str' );

my %map = (
  'TY' => 'pubtype',
  'T1' => 'title',
  'TI' => 'title',
  'CT' => 'title',
  'BT' => 'title',
  'T2' => 'journal',
  'T3' => 'journal',
  'N1' => 'notes',
  'AB' => 'abstract',
  'N2' => 'abstract',
  'JO' => 'journal_short',
  'JF' => 'journal_short',
  'JA' => 'journal_short',
  'VL' => 'volume',
  'IS' => 'issue',
  'CP' => 'issue',
  'SN' => 'issn',
  'CY' => 'city',
  'PB' => 'publisher',
  'AD' => 'address',
  'UR' => 'url',
  'L1' => 'pdf',
  #'ID' => 'id',
);

sub connect {
  my $self = shift;
  $self->_data( $self->_read_file() );

  $self->total_entries( scalar( @{ $self->_data } ) );

  $self->_iter( MooseX::Iterator::Array->new( collection => $self->_data ) );
  $self->_pager( Data::Page->new() );
  $self->_pager->total_entries( $self->total_entries );
  $self->_pager->entries_per_page( $self->entries_per_page );
  $self->_pager->current_page(1);

  return $self->total_entries;
}

sub _get_data_for_page {
  my $self = shift;

  my @output = ();

  for my $i ( $self->_pager->first .. $self->_pager->last ) {
    push @output, $self->_data->[ $i - 1 ];
  }

  

  return [@output];

}

sub _read_file {

  my $self = shift;
  my $file = $self->file;

  my @data;

  open( RIS, "<$file" ) || croak("Could not open file $file for reading. ($!)");

  my $ris = '';
  $ris .= $_ while (<RIS>);

  while ( $ris =~ /(TY.*?)ER/sg ) {

    my @lines = split( /\r?\n/, $1 ); # consider DOS line ends here.

    my @authors   = ();
    my @editors   = ();
    my $journal   = PaperPile::Library::Journal->new();
    my $startPage = '';
    my $endPage   = '';

    my $pub = PaperPile::Library::Publication->new();

    foreach my $line (@lines) {
      if ( $line =~ /^\s*(\w\w)\s*-\s*(.*?)$/ ) {
        ( my $tag, my $value ) = ( $1, $2 );
        if ( not $2 ) {
          carp("Tag $tag has no value\n");
          next;
        }

        #print "$tag, $value\n------------------------------\n";

        if ( $tag =~ /(AU|A1|A2|A3|ED)/ ) {
          ( my $lastName, my $firstName, my $suffix ) = split( /,/, $value );
          $suffix    = '' if not defined $suffix;
          $firstName = '' if not defined $firstName;
          $lastName  = '' if not defined $firstName;

          my $author = PaperPile::Library::Author->new(
            last_name       => $lastName,
            first_names_raw => $firstName,
            suffix          => $suffix
          );

          $author->parse_initials;
          $author->create_id;

          if ( $tag =~ /(A1|AU)/ ) {
            push @authors, $author;
          }
          elsif ( $tag =~ /(A2|ED)/ ) {
            push @editors, $author;
          }
        }
        elsif ( $tag =~ /(PY|Y1)/ ) {

          # only year handled right now, the RIS file we used for testing
          # was created by BibUtils and it gets this field wrong... TODO:
          # do this later properly...

          ( my $year, my $month, my $day ) = split( /\//, $value );

          $pub->year($year);

        }
        elsif ( $tag =~ /(JO|JF|JA)/ ) {
          $journal->name($value);
          $value =~ s/[.,-]/ /g;
          $value =~ s/(^\s+|\s+$)//g;
          $value =~ s/(^\s+|\s+$)//g;
          $value =~ s/\s+/_/g;
          $value =~ s/_\)/\)/g;
          $journal->id($value);
          $journal->short($value);
        }
        elsif ( $tag =~ /(EP)/ ) {
          $startPage = $value;
        }
        elsif ( $tag =~ /(SP)/ ) {
          $endPage = $value;
        }
        # Content of these fields are not specified, can contain DOIs
        elsif ( $tag =~ /(M1|M2|M3)/ ) {
          if ($value=~/(doi\s*:\s*)?(10\.\d+\/\d+)/){
            $pub->doi($2);
          }
        }
        else {
          my $field = $map{$tag};
          if ( defined $field ) {
            $pub->$field($value);
          }
          else {
            carp("Tag $tag not handled.\n");
          }
        }
      }
    }
    $pub->pages("$startPage-$endPage");
    $pub->authors( [@authors] );
    $pub->editors( [@editors] );
    $pub->journal($journal);
    $pub->calculate_sha1;
    $pub->refresh_fields;

    push @data, $pub;
  }

  return [@data];

}

1;