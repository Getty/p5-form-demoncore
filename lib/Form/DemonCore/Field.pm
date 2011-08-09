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

has param_name => (
	is => 'ro',
	isa => 'Str',
	lazy_build => 1,
);

sub _build_param_name {
	my ( $self ) = @_;
	return $self->form->name.$self->form->param_split_char.$self->name;
}

has default_value => (
	is => 'rw',
	trigger => sub { shift->reset },
	predicate => 'has_default_value',
);

has input_value => (
	is => 'rw',
	trigger => sub { shift->reset },
	predicate => 'has_input_value',
	clearer => 'clear_input_value',
);

has output_value => (
	is => 'rw',
	predicate => 'has_output_value',
	clearer => 'clear_output_value',
);

sub session_value {
	my ( $self ) = @_;
	return $self->session->{value} if ($self->has_session_value);
}

sub has_session_value {
	my ( $self ) = @_;
	return 0 unless $self->form->has_session;
	return defined $self->session->{value} ? 1 : 0;
}

sub session {
	my $self = shift;
	if ($self->form->has_session) {
		$self->form->session->{demoncore} = {} if !defined $self->form->session->{demoncore};
		$self->form->session->{demoncore}->{$self->param_name} = {} if !defined $self->form->session->{demoncore}->{$self->param_name};
		return $self->form->session->{demoncore}->{$self->param_name};
	}
	die __PACKAGE__." can't use session without session on the form";
}

has is_valid => (
	is => 'ro',
	isa => 'Bool',
	lazy_build => 1,
	predicate => 'is_validated',
	clearer => 'reset_validation',
);

sub _build_is_valid {
	my $self = shift;
	$self->populate;
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
	return $self->has_errors ? 0 : 1;
}

has value => (
	is => 'rw',
	predicate => 'has_value',
	clearer => 'reset_value',
	trigger => sub { shift->value_changed },
);

sub BUILD {
	my ( $self ) = @_;
	$self->populate;
}

sub clear_session {
	my ( $self ) = @_;
	delete $self->form->session->{demoncore}->{$self->param_name} if $self->form->has_session;
}

sub reset {
	my ( $self ) = @_;
	$self->populate;
}

sub value_changed {
	my ( $self ) = @_;
	$self->value_to_session;
	$self->value_to_output;
}

sub value_to_session {
	my ( $self ) = @_;
	if ( $self->form->has_session ) {
		$self->session->{value} = $self->value;
	}
}

sub populate {
	my ( $self ) = @_;
	$self->reset_validation;
	if ($self->form->has_session) {
		if (defined $self->session->{value}) {
			$self->session_value($self->session->{value});
		}
	}
	$self->reset_value;
	$self->clear_output_value;
	if ($self->has_input_value) {
		$self->input_to_value if ( $self->has_input_value );
	} elsif ($self->form->has_session && $self->has_session_value) {
		$self->value($self->session_value);
	} elsif ($self->has_default_value) {
		$self->value($self->default_value);
	}
}

sub input_to_value {
	my ( $self ) = @_;
	$self->value($self->input_value);
}

sub value_to_output {
	my ( $self ) = @_;
	$self->output_value($self->value);
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