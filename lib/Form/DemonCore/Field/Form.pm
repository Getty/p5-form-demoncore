package Form::DemonCore::Field::Form;

use Moose;
extends 'Form::DemonCore::Field';

has field_forms => (
	isa => 'ArrayRef[Form::DemonCore]',
	is => 'ro',
	lazy_build => 1,
);

sub _build_field_forms {
	my ( $self ) = @_;
}

has _form_count => (
	isa => 'Int',
	is => 'rw',
);
sub form_count { shift->_form_count }

has form_count_min => (
	isa => 'Int',
	is => 'ro',
	default => sub { 1 },
);

has fields => (
	isa => 'ArrayRef[HashRef]',
	is => 'ro',
	required => 1,
);

has remove_empty => (
	isa => 'Bool',
	is => 'ro',
	default => sub { 1 },
);

1;