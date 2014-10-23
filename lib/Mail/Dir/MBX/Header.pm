package Mail::Dir::MBX::Header;

use strict;
use warnings;

use Time::Local ();

my %MONTHS = (
    'Jan' => 0,
    'Feb' => 1,
    'Mar' => 2,
    'Apr' => 3,
    'May' => 4,
    'Jun' => 5,
    'Jul' => 6,
    'Aug' => 7,
    'Sep' => 8,
    'Oct' => 9,
    'Nov' => 10,
    'Dec' => 11
);

sub parse {
    my ( $class, $header ) = @_;

    #
    # tidyoff -- perltidy would wreak havoc on this poor expression
    #
    my ( $date, $time, $metadata ) = split /\s+/, $header;

    my ( $day, $month, $year ) = (
        $date =~ /^( \d|\d\d)-(\w{3})-(\d{4})$/
    ) or die('Invalid syntax: Bad date');

    my ( $hour, $minute, $second ) = (
        $time =~ /^(\d{2}):(\d{2}):(\d{2})$/
    ) or die('Invalid syntax: Bad timestamp');

    my ( $tz, $size, $attributes ) = (
        $metadata =~ /^([+\-]\d{4}),(\d+);(\S+)$/
    ) or die('Invalid syntax: Bad metadata');

    my ( $tzNegative, $tzHourOffset, $tzMinuteOffset ) = (
        $tz =~ /^([+\-])(\d{2})(\d{2})$/
    ) or die('Invalid syntax: Bad timezone offset');

    my ( $unused, $hexFlags, $hexUid ) = (
        $attributes =~ /^([[:xdigit:]]{8})([[:xdigit:]]{4})-([[:xdigit:]]{8})$/
    ) or die('Invalid syntax: Bad attributes');

    my $flags = 
        ( ( hex($hexFlags) & 0x1 ) ? 'S' : '' )
      . ( ( hex($hexFlags) & 0x2 ) ? 'T' : '' )
      . ( ( hex($hexFlags) & 0x4 ) ? 'F' : '' )
      . ( ( hex($hexFlags) & 0x8 ) ? 'R' : '' );

    my $timestamp = Time::Local::timegm(
        $second, $minute, $hour, $day + 0, $MONTHS{$month}, $year
    ) + ( ( $tzNegative eq '-' ? 1 : -1 )
      * ( $tzHourOffset * 60 + $tzMinuteOffset ) * 60 );

    #
    # tidyon
    #

    return bless {
        'uid'       => hex($hexUid),
        'timestamp' => $timestamp,
        'flags'     => $flags,
        'size'      => $size
    }, $class;
}
