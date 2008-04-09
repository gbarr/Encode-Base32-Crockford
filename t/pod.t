#!/usr/bin/perl

use warnings;
use strict;

use Test::More;

SKIP: {
		eval "use Test::Pod 1.00";
		skip "Test::Pod 1.00 required for testing POD", 1 if $@;

		all_pod_files_ok();
}
