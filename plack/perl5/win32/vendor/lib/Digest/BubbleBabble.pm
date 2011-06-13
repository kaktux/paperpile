package Digest::BubbleBabble;
use strict;

use Exporter;
use vars qw( @EXPORT_OK @ISA $VERSION );
@ISA = qw( Exporter );
@EXPORT_OK = qw( bubblebabble );

$VERSION = '0.01';

use vars qw( @VOWELS @CONSONANTS );
@VOWELS = qw( a e i o u y );
@CONSONANTS = qw( b c d f g h k l m n p r s t v z x );

sub bubblebabble {
    my %param = @_;
    my @dgst = map ord, split //, $param{Digest};
    my $dlen = length $param{Digest};

    my $seed = 1;
    my $rounds = ($dlen / 2) + 1;
    my $retval = 'x';
    for my $i (0..$rounds-1) {
        if ($i+1 < $rounds || $dlen % 2) {
            my $idx0 = ((($dgst[2 * $i] >> 6) & 3) + $seed) % 6;
            my $idx1 = ($dgst[2 * $i] >> 2) & 15;
            my $idx2 = (($dgst[2 * $i] & 3) + $seed / 6) % 6;
            $retval .= $VOWELS[$idx0] . $CONSONANTS[$idx1] . $VOWELS[$idx2];
            if ($i+1 < $rounds) {
                my $idx3 = ($dgst[2 * $i + 1] >> 4) & 15;
                my $idx4 = $dgst[2 * $i + 1] & 15;
                $retval .= $CONSONANTS[$idx3] . '-' . $CONSONANTS[$idx4];
                $seed = ($seed * 5 + $dgst[2 * $i] * 7 +
                        $dgst[2 * $i + 1]) % 36;
            }
        }
        else {
            my $idx0 = $seed % 6;
            my $idx1 = 16;
            my $idx2 = $seed / 6;
            $retval .= $VOWELS[$idx0] . $CONSONANTS[$idx1] . $VOWELS[$idx2];
        }
    }
    $retval .= 'x';
    $retval;
}

1;
__END__

=head1 NAME

Digest::BubbleBabble - Create bubble-babble fingerprints

=head1 SYNOPSIS

    use Digest::BubbleBabble qw( bubblebabble );
    use Digest::SHA1 qw( sha1 );

    my $fingerprint = bubblebabble( Digest => sha1($message) );

=head1 DESCRIPTION

I<Digest::BubbleBabble> takes a message digest (generated by
either of the MD5 or SHA-1 message digest algorithms) and creates
a fingerprint of that digest in "bubble babble" format.
Bubble babble is a method of representing a message digest
as a string of "real" words, to make the fingerprint easier
to remember. The "words" are not necessarily real words, but
they look more like words than a string of hex characters.

Bubble babble fingerprinting is used by the SSH2 suite
(and, consequently, by I<Net::SSH::Perl>, the Perl SSH
implementation) to display easy-to-remember key fingerprints.
The key (a DSA or RSA key) is converted into a textual form,
digested using I<Digest::SHA1>, and run through I<bubblebabble>
to create the key fingerprint.

=head1 USAGE

I<Digest::BubbleBabble> conditionally exports one function called
I<bubblebabble>; to import the function you must choose to
import it, like this:

    use Digest::BubbleBabble qw( bubblebabble );

=head2 bubblebabble( Digest => $digest )

Currently takes only one pair of arguments, the key of
which must be I<Digest>, the value of which is the actual
message digest I<$digest>. You should generate this message
digest yourself using either I<Digest::MD5> of I<Digest::SHA1>.

Returns the bubble babble form of the digest.

=head1 AUTHOR & COPYRIGHTS

Benjamin Trott, ben@rhumba.pair.com

Except where otherwise noted, Digest::BubbleBabble is Copyright
2001 Benjamin Trott. All rights reserved. Digest::BubbleBabble is
free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=cut