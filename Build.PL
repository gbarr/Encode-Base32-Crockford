#!/usr/bin/perl

use warnings;
use strict;

use Module::Build;

my $mb = Module::Build->new(
	'module_name' => 'Encode::Base32::Crockford',
	'license'     => 'perl',
	'requires'    => {
		'Scalar::Util' => 0,
	},
	create_makefile_pl => 'passthrough',
);

$mb->create_build_script;
