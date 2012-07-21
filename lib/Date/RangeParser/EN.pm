package Date::RangeParser::EN;

use strict;
use warnings;

use Date::Manip qw(ParseDate UnixDate);
use DateTime;

our $VERSION = '0.01';

=head1 NAME

Date::RangeParser::EN

=head1 SYNOPSIS

use Date::RangeParser::EN;

my $parser = Date::RangeParser::EN->new;
my ($begin, $end) = $parser->parse_range("this week");

=head1 DESCRIPTION

Parses plain-English strings representing date/time ranges

=cut

my %bod = (hour =>  0, minute =>  0, second =>  0);
my %eod = (hour => 23, minute => 59, second => 59);

my %weekday = (
    sunday    => 0,
    monday    => 1,
    tuesday   => 2,
    wednesday => 3,
    thursday  => 4,
    friday    => 5,
    saturday  => 6,
);

my $weekday = qr/(?:mon|tues|wednes|thurs|fri|satur|sun)day/;

my %ordinal = (
    qr/\bfirst\b/           => "1st",  qr/\bsecond\b/           => "2nd",
    qr/\bthird\b/           => "3rd",  qr/\bfourth\b/           => "4th",
    qr/\bfifth\b/           => "5th",  qr/\bsixth\b/            => "6th",
    qr/\bseventh\b/         => "7th",  qr/\beighth\b/           => "8th",
    qr/\bninth\b/           => "9th",  qr/\btenth\b/            => "10th",
    qr/\beleventh\b/        => "11th", qr/\btwelfth\b/          => "12th",
    qr/\bthirteenths\b/     => "13th", qr/\bfourteenth\b/       => "14th",
    qr/\bfifteenth\b/       => "15th", qr/\bsixteenth\b/        => "16th",
    qr/\bseventeenth\b/     => "17th", qr/\beighteenth\b/       => "18th",
    qr/\bnineteenth\b/      => "19th", qr/\btwentieth\b/        => "20th",
    qr/\btwenty-?first\b/   => "21st", qr/\btwenty-?second\b/   => "22nd",
    qr/\btwenty-?third\b/   => "23rd", qr/\btwenty-?fourth\b/   => "24th",
    qr/\btwenty-?fifth\b/   => "25th", qr/\btwenty-?sixth\b/    => "26th",
    qr/\btwenty-?seventh\b/ => "27th", qr/\btwenty-?eighth\b/   => "28th",
    qr/\btwenty-?ninth\b/   => "29th", qr/\bthirtieth\b/        => "30th",
    qr/\bthirty-?first\b/   => "31st",
);

my %month = (
    qr/jan(?:uary)?/    => 1,   qr/feb(?:ruary)?/   => 2,
    qr/mar(?:ch)?/      => 3,   qr/apr(?:il)?/      => 4,
    qr/may/             => 5,   qr/jun(?:e)?/       => 6,
    qr/jul(?:y)?/       => 7,   qr/aug(?:ust)?/     => 8,
    qr/sep(?:tember)?/  => 9,   qr/oct(?:ober)?/    => 10,
    qr/nov(?:ember)?/   => 11,  qr/dec(?:ember)?/   => 12,
);

my $month_re = qr/\b(?:
    a(?:pr(?:il)?|ug(?:ust)?)       |
    dec(?:ember)?                   |
    feb(?:ruary)?                   |
    j(?:an(?:uary)?|u(?:ne?|ly?))   |
    ma(?:y|r(?:ch)?)                |
    nov(?:ember)?                   |
    oct(?:ober)?                    |
    sep(?:tember)?
    )\b/x;

=head1 METHODS

=head2 new

Returns a new instance of Date::RangeParser::EN.

Takes an optional hash of parameters:

=over 4

=item * B<datetime_class>

By default, Date::RangeParser::EN returns two L<DateTime> objects representing the beginning and end of the range. If you use a subclass of DateTime (or another module that implements the DateTime API), you may pass the name of this class to use it instead.

=item * B<now_callback>

By default, Date::RangeParser::EN uses DateTime->now to determine the current date/time for calculations. If you need to work with a different time (for instance, if you need to adjust for time zones), you may pass a callback (code reference) which returns a DateTime object.

=back

=cut

sub new
{
    my ($class, %params) = @_;

    my $self = \%params;

    bless $self, $class;

    return $self;
}

=head2 parse_range

Accepts a string representing a plain-English date range, for instance:

=over 4

=item * today

=item * this week

=item * the past 2 months

=item * next Tuesday

=item * two weeks ago

=item * the next 3 hours

=item * the 3rd of next month

=item * the end of this month

=back

Returns two DateTime objects, reprensenting the beginning and end of the range.

=cut

sub parse_range
{
    my ($self, $string, %params) = @_;
    my ($beg, $end, $y, $m, $d);

    $string = lc $string;
    $string =~ s/^\s+//g;
    $string =~ s/\s+$//g;
    $string =~ s/\s+/ /g;

    # Special cases, except in even more special cases
    unless ($string =~ /\d+ (quarter|day|week|month|year)/)
    {
        if ($string =~ s/ ago$//)
        {
            $string = "past $string";
        }
        elsif ($string =~ s/ (?:hence|from\s+now)$//)
        {
            $string = "next $string";
        }
    }

    # We address the ordinals (let's not get silly, though).  If we wanted
    # to get silly, we'd use Lingua::EN::Words2Nums, which would horribly
    # complicate the general parsing
    while (my ($str, $num) = each %ordinal)
    {
        $string =~ s/$str/$num/g;
    }

    # The word "the" may be used with ridiculous impunity
    $string =~ s/\bthe\b//g;

    # Yes, again.
    $string =~ s/^\s+//g;
    $string =~ s/\s+$//g;

    $string =~ s/\s+/ /g;

    # "This thing" and "current thing"
    if ($string eq "today" || $string =~ /^(?:this|current) day$/)
    {
        $beg = $self->_bod();
        $end = $self->_eod();
    }
    elsif ($string =~ /^(?:this|current) week$/)
    {
        my $dow = $self->_now()->day_of_week % 7;       # Monday == 1
        $beg = $self->_bod()->subtract(days => $dow);   # Subtract to Sunday
        $end = $self->_eod()->add(days => 6 - $dow);    # Add to Saturday
    }
    elsif ($string =~ /^(?:this|current) month$/)
    {
        $beg = $self->_bod()->set_day(1);
        $end = $self->_datetime_class()->last_day_of_month(year => $self->_now()->year,
                                           month => $self->_now()->month, %eod);
    }
    elsif ($string =~ /^(?:this|current) quarter$/)
    {
        my $zq = int(($self->_now()->month - 1) / 3);     # 0..3
        $beg = $self->_bod()->set_month($zq * 3 + 1)->set_day(1);
        $end = $self->_datetime_class()->last_day_of_month(year => $self->_now()->year,
                                           month => $zq * 3 + 3 , %eod);
    }
    elsif ($string =~ /^(?:this|current) year$/)
    {
        $beg = $self->_datetime_class()->new(year => $self->_now()->year, month => 1, day => 1, %bod);
        $end = $self->_datetime_class()->new(year => $self->_now()->year, month => 12, day => 31, %eod);
    }
    elsif ($string =~ /^this ($weekday)$/)
    {
        my $dow = $self->_now()->day_of_week % 7;           # Monday == 1
        my $adjust = $weekday{$1} - $dow;
        if ($adjust < 0)
        {
            $beg = $self->_bod()->subtract(days => abs($adjust));
        }
        elsif ($adjust > 0)
        {
            $beg = $self->_bod()->add(days => $adjust);
        }
        else
        {
            $beg = $self->_bod();
        }
        $end = $beg->clone->add(days => 1)->subtract(seconds => 1);
    }
    # "Last N things" and "Past N things"
    elsif ($string =~ /^(?:last|past) (\d+) hours?$/)
    {
        # The "+0" math avoids call-by-reference side effects
        $beg = $self->_now();
        $beg->subtract(hours => $1 + 0);

        $end = $self->_now();
    }
    elsif ($string =~ /^(?:last|past) (\d+) days?$/)
    {
        $beg = $self->_bod()->subtract(days => $1 - 1);
        $end = $self->_eod();
    }
    elsif ($string =~ /^(?:last|past) (\d+) weeks?$/)
    {
        my $offset = $self->_now()->day_of_week % 7; # sun offset: 0 ... sat offset: 6
        $beg = $self->_bod()->subtract(days => $offset)->subtract(weeks => $1 - 1); # sunday
        $end = $self->_eod()->add(days => 6 - $offset); #saturday of current week
    }
    elsif ($string =~ /^(?:last|past) (\d+) months?$/)
    {
        $beg = $self->_bod()->set_day(1)->subtract(months => $1 - 1);
        $end = $self->_datetime_class()->last_day_of_month(year => $self->_now()->year,
                                       month => $self->_now()->month, %eod);
    }
    elsif ($string =~ /^(?:last|past) (\d+) years?$/)
    {
        $beg = $self->_bod()->set_month(1)->set_day(1)->subtract(years => $1 - 1);
        $end = $self->_eod()->set_month(12)->set_day(31);
    }
    elsif ($string =~ /^(?:last|past) (\d+) quarters?$/)
    {
        my $zq = int(($self->_now()->month - 1) / 3);
        $end = $self->_bod()->set_month($zq * 3 + 1)->set_day(1)
                    ->add(months => 3)->subtract(seconds => 1);
        $beg = $end->clone->set_day(1)
                   ->subtract(months => (3 * $1) - 1)
                   ->subtract(days => 1)->add(seconds => 1);
     }
    elsif ($string =~ /^(\d+) ((?:month|day|week|quarter)s?) ago$/)
    {
        # "N days|weeks|months ago"
        my $ct = $1 + 0;
        my $unit = $2;
        if($unit !~ /s$/) {
            $unit .= 's';
        }
        if($unit eq 'quarters') {
            $unit = 'months';
            $ct *= 3;
        }
        $beg = $self->_bod()->subtract($unit => $ct);
        $end = $beg->clone->set(hour => 23, minute => 59, second => 59);
     }
    elsif ($string =~ /^past (\d+) ($weekday)s?$/)
    {
        # really "N weekdays ago", thanks to s/ago/.../ above
        my $dow = $self->_now()->day_of_week % 7;          # Monday == 1
        my $adjust = $weekday{$2} - $dow;
        $adjust -= 7 if $adjust >=0;
        $adjust -= 7*($1 - 1);
        $beg = $self->_bod()->subtract(days => abs($adjust));
        $end = $beg->clone->add(days => 1)->subtract(seconds => 1);
    }
    # "Last thing" and "Previous thing"
    elsif ($string =~ /^yesterday$/)
    {
        $beg = $self->_bod()->subtract("days" => 1);
        $end = $beg->clone->set(hour => 23, minute => 59, second => 59);
    }
    elsif ($string =~ /^(?:last|previous) week$/)
    {
        my $dow = $self->_now()->day_of_week % 7;           # Monday == 1
        $beg = $self->_bod()->subtract(days => 7 + $dow);   # Subtract to last Sunday
        $end = $self->_eod()->subtract(days => 1 + $dow);   # Subtract to Saturday
    }
    elsif ($string =~ /^(?:last|previous) month$/)
    {
        $beg = $self->_bod()->set_day(1)->subtract(months => 1);
        $end = $self->_bod()->set_day(1)->subtract(seconds => 1);
    }
    elsif ($string =~ /^(?:last|previous) quarter$/)
    {
        my $zq = int(($self->_now()->month - 1) / 3);
        $beg = $self->_bod()->set_month($zq * 3 + 1)->set_day(1)->subtract(months => 3);
        $end = $beg->clone->add(months => 3)->subtract(seconds => 1);
    }
    elsif ($string =~ /^(?:last|previous) year$/)
    {
        $beg = $self->_bod()->set_month(1)->set_day(1)->subtract(months => 12);
        $end = $self->_bod()->set_month(1)->set_day(1)->subtract(seconds => 1);
    }
    elsif ($string =~ /^(?:last|previous) ($weekday)$/) {
        my $dow = $self->_now()->day_of_week % 7;           # Monday == 1
        my $adjust = $weekday{$1} - $dow - 7;
        $beg = $self->_bod()->subtract(days => abs($adjust));
        $end = $beg->clone->add(days => 1)->subtract(seconds => 1);
    }
    # "Past weekday" and "This past weekday"
    elsif ($string =~ /^(?:this )?past ($weekday)$/)
    {
        my $dow = $self->_now()->day_of_week % 7;           # Monday == 1
        my $adjust = $weekday{$1} - $dow;
        $adjust -= 7 if $adjust >= 0;
        $beg = $self->_bod()->subtract(days => abs($adjust));
        $end = $beg->clone->add(days => 1)->subtract(seconds => 1);
    }
    # "Coming weekday" and "This coming weekday"
    elsif ($string =~ /^(?:this )?coming ($weekday)$/)
    {
        my $dow = $self->_now()->day_of_week % 7;           # Monday == 1
        my $adjust = $weekday{$1} - $dow;
        $adjust += 7 if $adjust <= 0;
        $beg = $self->_bod()->add(days => $adjust);
        $end = $beg->clone->add(days => 1)->subtract(seconds => 1);
    }
    # "Next thing" and "Next N things"
    elsif ($string =~ /^next (\d+)?\s*hours?$/)
    {
        my $c = defined $1 ? $1 : 1;
        $beg = $self->_now();
        $end = $beg->clone->add(hours => $c);
    }
    elsif ($string =~ /^(?:next (\d+)?\s*days?|tomorrow)$/)
    {
        my $c = defined $1 ? $1 : 1;
        $beg = $self->_bod()->add(days => 1);
        $end = $beg->clone->add(days => $c)->subtract(seconds => 1)
    }
    elsif ($string =~ /^next (\d+)?\s*weeks?$/)
    {
        my $c = defined $1 ? $1 : 1;
        my $dow = $self->_now()->day_of_week % 7;        # Monday == 1
        $beg = $self->_bod()->add(days => 7 - $dow);        # Add to Sunday
        $end = $self->_eod()->add(days => 6 + 7*$c - $dow); # Add N Saturdays following
    }
    elsif ($string =~ /^next (\d+)?\s*months?$/)
    {
        my $c = defined $1 ? $1 : 1;
        $beg = $self->_bod()->add(months => 1, end_of_month => 'preserve')->set_day(1);
        my $em = $self->_now()->add(months => $c, end_of_month => 'preserve');
        $end = $self->_datetime_class()->last_day_of_month(year => $em->year, month => $em->month, %eod);
    }
    elsif ($string =~ /^next (\d+)?\s*quarters?$/)
    {
        my $c = defined $1 ? $1 : 1;
        my $zq = int(($self->_now()->month - 1) / 3);
        $beg = $self->_bod()->set_month($zq * 3 + 1)->set_day(1)
                    ->add(months => 3, end_of_month => 'preserve');
        $end = $beg->clone ->add(months => 3 * $c, end_of_month => 'preserve')
                    ->subtract(seconds => 1);
    }
    elsif ($string =~ /^next (\d+)?\s*years?$/)
    {
        my $c = defined $1 ? $1 : 1;
        $beg = $self->_bod()->set_month(1)->set_day(1)->add(years => 1);
        $end = $self->_eod()->set_month(12)->set_day(31)->add(years => $c);
    }
    elsif ($string =~ /^next (\d+)?\s*($weekday)s?$/)
    {
        # That's both "next sunday" and "3 sundays from now"
        my $c = defined $1 ? $1 : 1;
        my $dow = $self->_now()->day_of_week % 7;        # Monday == 1
        my $adjust = $weekday{$2} - $dow;        # get to right day of week
        $adjust += 7 if $adjust <= 0;            # add 7 days if its today or in the past
        $adjust += 7*($c - 1);
        $beg = $self->_bod()->add(days => $adjust);
        $end = $beg->clone->add(days => 1)->subtract(seconds => 1);
    }
    # The something of the month (or this, last, next, or previous...)
    elsif ($string =~ /^(\d+(?:st|nd|rd|th)?|end) of (this|last|next) month$/)
    {
        if ($1 eq "end") {
            $beg = $self->_datetime_class()->last_day_of_month(year => $self->_now()->year,
                                           month => $self->_now()->month, %bod);
        } else {
            my ($d) = $1 =~ /(^\d+)/;   # remove st/nd/rd/th
            $beg = $self->_bod()->set_day($d);
        }

        if ($2 eq "last") {
            $beg = $beg->subtract(months => 1, end_of_month => 'preserve');
        } elsif ($2 eq "next") {
            $beg = $beg->add(months => 1, end_of_month => 'preserve');
        }
        $end = $beg->clone->add(days => 1)->subtract(seconds => 1);
    }
    # The something of N month (ago|from now|hence)
    elsif ($string =~ /^(\d+(?:st|nd|rd|th)?|end) of (\d+) months? (ago|from now|hence)$/)
    {
        if ($1 eq "end") {
            $beg = $self->_datetime_class()->last_day_of_month(year => $self->_now()->year,
                                           month => $self->_now()->month, %bod);
        } else {
            my ($d) = $1 =~ /(^\d+)/;   # remove st/nd/rd/th
            $beg = $self->_bod()->set_day($d);
        }

        my $n = $2;     # Avoid call-by-reference side effects in add/subtract

        if ($3 eq "ago") {
            $beg = $beg->subtract(months => $n, end_of_month => 'preserve');
        } elsif ($3 eq "from now" || $3 eq "hence") {
            $beg = $beg->add(months => $n, end_of_month => 'preserve');
        }
        $end = $beg->clone->add(days => 1)->subtract(seconds => 1);
    }
    # Handle rewriting things with months in them
    elsif ($string =~ /^(this|last|next)?\s*($month_re)$/)
    {
        my ($y, $m) = ($1, $2);
        if ($y eq 'last') {
            $y = $self->_now->year - 1;
        } elsif ($y eq 'next') {
            $y = $self->_now->year + 1;
        } else {
            $y = $self->_now->year;
        }
        while (my ($re, $val) = each %month) {
            if ($m =~ /$re/) {
                $m = $val;
                keys %month;    # Reset each counter
                last;
            }
        }
        $beg = $self->_bod()->set(year => $y, month => $m, day => 1);
        $end = $self->_datetime_class()->last_day_of_month(year => $y, month => $m, %eod);
    }
    # If all else fails, see if Date::Manip can figure this out
    elsif ($beg = $self->_parse_date_manip($string))
    {
        $beg = $beg->set(%bod);
        $end = $beg->clone->set(hour => 23, minute => 59, second => 59);
    }
    else
    {
        return ();
    }

    return ($beg, $end);
}

sub _bod {
    my $self = shift;
    my $now = $self->_now();
    return $now->set(%bod);
}

sub _eod {
    my $self = shift;
    my $now = $self->_now();
    return $now->set(hour => 23, minute => 59, second => 59);
}

sub _now {
    my $self = shift;

    if (my $cb = $self->{now_callback}) {
        return &$cb($self);
    }

    return $self->_datetime_class->now;
}

sub _datetime_class {
    my $self = shift;
    return $self->{datetime_class} || 'DateTime';
}

sub _parse_date_manip
{
    my ($self, $val) = @_;

    my $date;

    # wrap in eval as Date::Manip fatally dies on strange input (ie. 010101)
    eval {
        # try parsing with Date::Manip
        my $parsed_date = ParseDate( $val );
        if ( $parsed_date )
        {
            my ($date_part, $time_part) = split(/ /, UnixDate($parsed_date, '%Y-%m-%d %T'));
            my ($year, $month, $day) = split(/\-/, $date_part);
            my ($hour, $minute, $second) = split( /\:/, $time_part);

            $date = $self->_datetime_class->new(
                year   => $year,
                month  => $month,
                day    => $day,
                hour   => $hour,
                minute => $minute,
                second => $second,
            );
        }
    };

    return $date;
}

=head1 TO DO

There's a lot more that this module could handle. A few items that come to mind:

=over 4

=item * allow full words instead of digits ("two weeks ago" vs "2 weeks ago")

=item * allow simple, easily-parsable ranges ("1/1/2012-12/31/2012")

=item * allow larger ranges ("between last February and this Friday")

=back

=head1 DEPENDENCIES

L<DateTime>, L<Date::Manip>

=head1 AUTHORS

This module was authored by Grant Street Group (L<http://grantstreet.com>), which was kind enough to give it back to the Perl community.

The CPAN distribution is maintained by Michael Aquilina (aquilina@cpan.org).

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 Grant Street Group.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;

