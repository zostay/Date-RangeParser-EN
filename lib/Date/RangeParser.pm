package Date::RangeParser;

use strict;
use warnings;

our $VERSION = '0.05';

use Class::Load ();
use Carp ();

=head1 NAME

Date::RangeParser - Generic parser for date/time range strings

=head1 SYNOPSIS

  use Date::RangeParser;

  my $parser = Date::RangeParser->new;
  my ($begin, $end) = $parser->parse_range("this week");

=head1 DESCRIPTION

Parses plain-language string representing date/time ranges. Currently, only
English is supported.

=head1 METHODS

=head2 new

  $parser = Date::RangeParser->new(%options);

Constructs a new L<Date::RangeParser> object and returns it.  The C<%options>
may contain the following key/value pairs:

=over

=item C<language>

This is a shortcut for C<implementation> and will result in an error if you try
to use both C<language> and C<implementation>. This option tells
L<Date::RangeParser> to use "Date::RangeParser::$language" for the parser
implementation.

=item C<implementation>

Do not use this option with the C<language> option. This option is the name of
the class or an object instance implementing the actual range parser. See
L</IMPLEMENTING A RANGE PARSER> for additional information. By default,
L</Date::RangeParser::EN> is used.

=item C<datetime_class>

By default, Date::RangeParser::EN returns two L<DateTime> objects representing
the beginning and end of the range. If you use a subclass of DateTime (or
another module that implements the DateTime API), you may pass the name of this
class to use it instead.

At the very least, this given class must implement a C<new> method that accepts
a hash of arguments, where the following keys will be set:

  year
  month
  day
  hour
  minute
  second

This gives you the freedom to set your time zones and such however you need to.


=item C<now_callback>

By default, Date::RangeParser::EN uses DateTime->now to determine the current
date/time for calculations. If you need to work with a different time (for
instance, if you need to adjust for time zones), you may pass a callback (code
reference) which returns a DateTime object.

=back

=cut

sub new {
    my ($class, %options) = @_;

    my $language       = delete $options{language};
    my $implementation = delete $options{implementation};

    Carp::croak("You must not use both the language and implementation options to Date::RangeParser")
        if defined $language and defined $implementation;

    $implementation = "Date::RangeParser::$language"
        if defined $language;

    $impementation = "Date::RangeParser::EN"
        unless defined $language;

    Class::Load::load_class($implementation);

    my $self = {
        %options,
        implementation => $implementation,
    };
    bless $self, $class;

    return $self;
}

=head2 parse_range

  ($beginning, $end) = $parser->parse_range("today");

Given a string to parse, this will return two date objects representing that
date. If date cannot be parsed, it returns an empty list instead.

=cut

sub parse_range {
    my ($self, $string) = @_;
    my $impl = $self->{implementation};

    my $skip_words = $impl->skip_words;
    for my $skip_word (map { quotemeta } @$skip_words) {
        s/\b$skip_word\b//;
    }

    # Trim and compact whitespace
    $string =~ s/^\s+//g;
    $string =~ s/\s+$//g;
    $string =~ s/\s+/ /g;

    $self->_process_string(\$string, $self->{implementation}->cleanup_instructions);
    $self->_match_string($
    my $cleanup_phase = 


}

=head1 IMPLEMENTING A RANGE PARSER




