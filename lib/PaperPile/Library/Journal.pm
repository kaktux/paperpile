package PaperPile::Library::Journal;
use Moose;
use Moose::Util::TypeConstraints;

has 'id'    => ( is => 'rw', isa => 'Str' );
has 'name'  => ( is => 'rw', isa => 'Str' );
has 'short' => ( is => 'rw', isa => 'Str', default => '');
has 'issn'  => ( is => 'rw', isa => 'Str' );
has 'url'   => ( is => 'rw', isa => 'Str' );
has 'icon'  => ( is => 'rw', isa => 'Str' );
has 'is_user_journal'  => ( is => 'rw', isa => 'Bool' );

1;

