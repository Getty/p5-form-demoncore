package Form::DemonCore::Field;

use Moose;

has name => (
	isa => 'Str',
	is => 'ro',
	required => 1,
);

has form => (
	isa => 'Form::DemonCore',
	is => 'ro',
	required => 1,
);

has required => (
	isa => 'Bool',
	is => 'ro',
	default => sub { 0 },
);

has notempty => (
	isa => 'Bool',
	is => 'ro',
	default => sub { 0 },
);

has default_value => (
	is => 'rw',
	trigger => sub { shift->reset },
	predicate => 'has_default_value',
);

has input_value => (
	is => 'rw',
	trigger => sub { shift->reset },
	predicate => 'has_input_value',
);

has output_value => (
	is => 'rw',
	predicate => 'has_output_value',
);

has _is_valid => (
	isa => 'Bool',
	is => 'rw',
	predicate => 'is_validated',
	clearer => 'devalidate',
);
sub is_valid { my $self = shift; $self->populate; $self->validate; return $self->_is_valid }

has param_name => (
	is => 'ro',
	isa => 'Str',
	lazy_build => 1,
);

sub _build_param_name {
	my ( $self ) = @_;
	return $self->form->name.$self->form->param_split_char.$self->name;
}

sub reset {
	my ( $self ) = @_;
	$self->devalidate;
	$self->clear_value;
}

has empty_check => (
	is => 'ro',
	isa => 'CodeRef',
	lazy_build => 1,
);

sub _build_empty_check {
	return sub { shift =~ m/^$/ }
}

has required_error => (
	is => 'rw',
	default => sub { 'This field is required' },
);

has notempty_error => (
	is => 'rw',
	default => sub { 'This field may not be empty' },
);

sub validate {
	my ( $self ) = @_;
	return if $self->is_validated;
	if ($self->has_value) {
		my $empty = $self->empty_check->($self->value);
		if ($empty && $self->notempty) {
			$self->add_error($self->notempty_error);
		} elsif (!$empty) {
			for ($self->all_validators) {
				$self->add_error($_) for ($_->($self,$self->value));
			}
		}
	} elsif ($self->required) {
		$self->add_error($self->required_error);
	} elsif ($self->notempty) {
		$self->add_error($self->notempty_error);
	}
	$self->_is_valid($self->has_errors ? 0 : 1);
}

has value => (
	is => 'rw',
	predicate => 'has_value',
	clearer => 'clear_value',
);

sub populate {
	my ( $self ) = @_;
	return if $self->has_value;
	$self->value($self->default_value) if ( $self->has_default_value && !$self->has_input_value );
	$self->input_to_value if ( $self->has_input_value );
	$self->value_to_output if ( $self->has_value );
}

sub submit_errors {
	my ( $self ) = @_;
	return unless $self->form->is_submitted;
	return $self->errors;
}

has errors => (
	traits  => ['Array'],
	is      => 'ro',
	isa     => 'ArrayRef',
	default => sub {[]},
	handles => {
		all_errors => 'elements',
		add_error => 'push',
		count_errors => 'count',
		has_errors => 'count',
		has_no_errors => 'is_empty',
	},
);

has x => (
	traits  => ['Hash'],
	is      => 'ro',
	isa     => 'HashRef',
	default => sub {{}},
);

sub input_to_value {
	my ( $self ) = @_;
	$self->value($self->input_value);
}

sub value_to_output {
	my ( $self ) = @_;
	$self->output_value($self->value);
}

has validators => (
	traits  => ['Array'],
	is      => 'ro',
	isa     => 'ArrayRef[CodeRef]',
	default => sub {[]},
	handles => {
		all_validators => 'elements',
		add_validator => 'push',
		count_validators => 'count',
		has_validators => 'count',
		has_no_validators => 'is_empty',
	},
);

1;