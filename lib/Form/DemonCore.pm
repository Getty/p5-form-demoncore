package Form::DemonCore;
# ABSTRACT: The demon core of form managements

use Moose;
use Form::DemonCore::Field;

has name => (
	isa => 'Str',
	is => 'ro',
	required => 1,
);

has param_name => (
	isa => 'Str',
	is => 'ro',
	lazy_build => 1,
);

sub _build_param_name { shift->name }

has fields => (
	traits  => ['Array'],
	is      => 'ro',
	isa     => 'ArrayRef[Form::DemonCore::Field]',
	default => sub {[]},
	handles => {
		all_fields => 'elements',
		add_field => 'push',
		map_fields => 'map',
		filter_fields => 'grep',
		get_field => 'get',
		count_fields => 'count',
		has_fields => 'count',
		has_no_fields => 'is_empty',
		sorted_fields => 'sort',
	},
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

has default_field_class => (
	isa => 'Str',
	is => 'ro',
	lazy_build => 1,
);

sub _build_default_field_class { 'Form::DemonCore::Field' }

has field_namespace => (
	isa => 'Str',
	is => 'rw',
	predicate => 'has_field_namespace',
);

sub factory {
	my ( $class, $config ) = @_;
	my %input_values = %{delete $config->{input_values}} if defined $config->{input_values};
	my @field_defs = @{delete $config->{fields}} if defined $config->{fields};
	my %defaults = %{delete $config->{defaults}} if defined $config->{defaults};
	my @fields;
	die "no fields defined" unless @field_defs;
	my $form = $class->new(
		%{$config},
	);
	for (@field_defs) {
		push @fields, $form->field_factory(delete $_->{name}, delete $_->{type}, $_);
	}
	for (@fields) {
		$form->add_field($_);
	}
	if (%defaults) {
		$form->insert_defaults(\%defaults);
	}
	if (%input_values) {
		$form->insert_inputs(\%input_values);
		$form->validate;
	}
	return $form;
}

sub result {
	my ( $self ) = @_;
	return $self->get_values if ( $self->is_submitted && $self->is_valid );
	return;
}

sub get_values {
	my ( $self ) = @_;
	my %values;
	for ($self->all_fields) {
		$values{$_->name} = $_->value if $_->has_value;
	}
	return \%values;
}

sub field_factory {
	my ( $self, $name, $type, $attributes ) = @_;
	my $class;
	if (!defined $type) {
		$class = $self->default_field_class;
	} elsif ($self->has_field_namespace) {
		$class = $self->field_namespace.'::'.$type;
	}
	die __PACKAGE__." can't handle type ".$type if !$class;
	my $file = $class;
	$file =~ s/::/\//g;
	$file .= '.pm';
	require $file;
	return $class->new(
		form => $self,
		name => $name,
		%{$attributes},
	);
}

has param_split_char => (
	isa => 'Str',
	is => 'ro',
	default => sub { '_' },
);

has param_split_char_regex => (
	isa => 'Str',
	is => 'ro',
	default => sub { '_' },
);

sub insert_defaults {
	my ( $self, $defaults ) = @_;
	for ($self->all_fields) {
		if (defined $defaults->{$_->name}) {
			$_->default_value($defaults->{$_->name});
		}
	}
}

sub insert_inputs {
	my ( $self, $params ) = @_;
	$self->is_submitted(1) if ($params->{$self->name});
	my $param_split_char_regex = $self->param_split_char_regex;
	for ($self->all_fields) {
		if ($_->can('input_from_params')) {
			$_->input_from_params($params);
		} else {
			my $param_name = $_->param_name;
			if (defined $params->{$param_name}) {
				$_->input_value($params->{$param_name});
			} else {
				my %values;
				for (keys %{$params}) {
					if ($_ =~ m/^${param_name}${param_split_char_regex}(.+)/) {
						$values{$1} = $params->{$_} if defined $params->{$_};
					}
				}
				$_->input_value(\%values) if %values;
			}
		}
	}
}

has _is_valid => (
	isa => 'Bool',
	is => 'rw',
	predicate => 'is_validated',
	clearer => 'devalidate',
);
sub is_valid { my $self = shift; $self->validate; return $self->_is_valid }

has is_submitted => (
	isa => 'Bool',
	is => 'rw',
	clearer => 'unsubmit',
	default => sub { 0 },
);

sub validate {
	my ( $self ) = @_;
	return if $self->is_validated;
	for ($self->all_validators) {
		$self->add_error($_) for ($_->($self,$self->get_values));
	}
	my $valid_fields = 1;
	for ($self->all_fields) {
		$valid_fields = 0 if !$_->is_valid;
	}
	$self->_is_valid(!$self->has_errors && $valid_fields ? 1 : 0);
}

has x => (
	traits  => ['Hash'],
	is      => 'ro',
	isa     => 'HashRef',
	default => sub {{}},
);

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

1;

=head1 SYNOPSIS

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

  if (my $result = $form->result) {
    ...
  }

=head1 SUPPORT

IRC

  Join #demoncore on irc.perl.org.

Repository

  http://github.com/Getty/p5-form-demoncore
  Pull request and additional contributors are welcome
 
Issue Tracker

  http://github.com/Getty/p5-form-demoncore/issues

=cut
