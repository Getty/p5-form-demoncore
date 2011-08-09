#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use Form::DemonCore;

my $form = Form::DemonCore->factory({
	name => 'testform',
	fields => [
		{
			name => 'testfield',
			notempty => 1,
		},
	],
	input_values => {
		testform => 1,
		testform_testfield => "test",
	},
});

is_deeply($form->result,{ testfield => 'test' }, "Checking simple form with one field filled");

done_testing;
