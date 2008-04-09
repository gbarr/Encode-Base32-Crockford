package Encode::Base32::Crockford;

use warnings;
use strict;

our $VERSION = '1.11';

use base qw(Exporter);
our @EXPORT_OK = qw(
	base32_encode base32_encode_with_checksum
	base32_decode base32_decode_with_checksum
	normalize
);
our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK );

use Carp qw(croak);
use Scalar::Util qw(looks_like_number);

# Note: regular digits do not include I, L, O or U. See spec in documentation.
my %SYMBOLS = ( 
	A => 10,
	B => 11,
	C => 12,
	D => 13,
	E => 14,
	F => 15,
	G => 16,
	H => 17,
	J => 18,
	K => 19,
	M => 20,
	N => 21,
	P => 22,
	Q => 23,
	R => 24,
	S => 25,
	T => 26,
	V => 27,
	W => 28,
	X => 29,
	Y => 30,
	Z => 31,
	# checksum symbols only from here
	'*' => 32,
	'~' => 33,
	'$' => 34,
	'=' => 35,
	'U' => 36,
);

my %SYMBOLS_INVERSE = reverse %SYMBOLS;

sub base32_encode {
	my $number = shift;

	die qq("$number" isn't a number) unless looks_like_number($number);

	my @digits;

	# Cut a long story short: keep dividing by 32. Use the remainders to make the 
	# digits of the converted number, right to left; the quotient goes to the next
	# iteration to be divided again. When the quotient hits zero, i.e. there's not
	# enough for 32 to be a divisor, the value being divided is the final digit.
	DIGITS: {
		my $quotient = int($number / 32);

		if ($quotient != 0) {
			my $remainder = $number % 32;
			$number = $quotient;

			if ($remainder > 9) {
				push @digits, $SYMBOLS_INVERSE{$remainder};
			} else {
				push @digits, $remainder;
			}

			redo DIGITS;
		} else {
			push @digits, $number;
			return join '', reverse @digits;
		}
	}
}

sub base32_encode_with_checksum {
	my $number = shift;

	my $modulo = $number % 37;
	
	my $checksum = $modulo < 10 ? $modulo : $SYMBOLS_INVERSE{$modulo};

	return base32_encode($number) . $checksum;
}

sub normalize {
	my ($string, $options) = @_;

	my $orig_string = $string;

	$string = uc($string);
	_normalize_actions($orig_string, $string, $options->{"mode"}) if $string ne $orig_string;

	# fix possible transcription errors and remove chunking symbols
	_normalize_actions($orig_string, $string, $options->{"mode"}) if $string =~ tr/IiLlOo-/111100/d;

	$string;
}

# Actions to carry out if normalize() is operating in a particular mode.
sub _normalize_actions {
	my ($old_string, $new_string, $mode) = @_;

	$mode ||= '';

	warn qq(String "$old_string" corrected to "$new_string") if $mode eq "warn";
	die  qq(String "$old_string" requires normalization) if $mode eq "strict";
}

sub base32_decode {
	my ($string, $options) = @_;

	croak "string is undefined" if not defined $string;
	croak "string is empty" if $string eq '';

	$string = normalize($string, $options);

	my $valid;

	if ($options->{"is_checksum"}) {
		die qq(Checksum "$string" is too long; should be one character)
			if length($string) > 1;

		$valid = qr/^[A-Z0-9\*\~\$=U]$/;

	} else {
		# 'U' is only valid as a checksum symbol.
		$valid = qr/^[A-TV-Z0-9]+$/;
	}

	croak qq(String "$string" contains invalid characters) if $string !~ /$valid/;
	
	
	my $total = 0;

	# For each base32 digit B of position P counted (using zero-based counting)
	# from right in a number, its decimal value D is calculated with the
	# following expression:
	# 	D = B * 32^P.
	# As any number raised to the power of 0 is 1, we can define an "offset" value
	# of 1 for the first digit calculated and simply multiply the offset by 32
	# after deriving the value for each digit.
	my $offset = 1;

	foreach my $symbol (reverse(split(//, $string))) {
		my $subtotal;
		my $value;
		
		$value = $symbol =~ /\d/ ? $symbol : $SYMBOLS{$symbol};
		
		$subtotal = $value * $offset;
		$total += $subtotal;
		$offset *= 32;
	}
	
	$total;
}

sub base32_decode_with_checksum {
	my ($string, $options) = @_;
	my $check_string = $string;

	my $checksum = substr($check_string, (length($check_string) - 1), 1, "");

	my $value = base32_decode($check_string, $options);
	my $checksum_value = base32_decode($checksum, { "is_checksum" => 1 });
	my $modulo = $value % 37;

	croak qq(Checksum symbol "$checksum" is not correct for value "$check_string".)
		if $checksum_value != $modulo;
	
	$value;
}

1;

__END__

=head1 NAME

Encode::Base32::Crockford - encode/decode numbers using Douglas Crockford's Base32
Encoding

=head1 DESCRIPTION

Douglas Crockford describes a I<Base32 Encoding> at 
L<http://www.crockford.com/wrmg/base32.html>. He says: "[Base32 Encoding is] a
32-symbol notation for expressing numbers in a form that can be conveniently and 
accurately transmitted between humans and computer systems."

This module provides methods to convert numbers to and from that notation.

=head1 SYNOPSIS

    use Encode::Base32::Crockford qw(:all); # import all methods

or

    use Encode::Base32::Crockford qw(base32_decode); # your choice of methods
    
    my $decoded = base32_decode_with_checksum("16JD");
    my $encoded = base32_encode_with_checksum(1234);

=head1 METHODS

=head2 base32_encode

    print base32_encode(1234); # prints "16J"

Encode a base 10 number. Will die on inappropriate input.

=head2 base32_encode_with_checksum

    print base32_encode_with_checksum(1234); # prints "16JD"

Encode a base 10 number with a checksum symbol appended. See the spec for a
description of the checksum mechanism. Wraps the previous method so will also
die on bad input.

=head2 base32_decode

    print base32_decode("16J"); # prints "1234"

    print base32_decode("IO", { mode => "warn"   }); # print "32" but warn
    print base32_decode("IO", { mode => "strict" }); # dies

Decode an encoded number into base 10. Will die on inappropriate input. The
function is case-insensitive, and will strip any hyphens in the input (see
C<normalize()>). A hashref of options may be passed, with the only valid option
being C<mode>. If set to "warn", normalization will produce a warning; if set
to "strict", requiring normalization will cause a fatal error.

=head2 base32_decode_with_checksum

    print base32_decode_with_checksum("16JD"); # prints "1234"

Decode an encoded number with a checksum into base 10. Will die if the checksum
isn't correct, and die on inappropriate input. Takes the same C<mode> option as
C<base32_decode>.

=head2 normalize

    my $string = "ix-Lb-Ko";
    my $clean = normalize($string);

    # $string is now '1X1BK0'.

The spec allows for certain symbols in encoded strings to be read as others, to
avoid problems with misread strings. This function will perform the following
conversions in the input string:

=over 4

=item * "i" or "I" to 1

=item * "l" or "L" to 1

=item * "o" or "O" to 0

=back

It will also remove any instances of "-" in the input, which are permitted by the
spec as chunking symbols to aid human reading of an encoded string, and uppercase
the output.

=head1 AUTHOR

Earle Martin <hex@cpan.org>

=head1 COPYRIGHT

This code is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.

=cut
