package Mail::Dir::MBX::Message;

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

my $BUF_SIZE = 4096;

sub read {
    my ( $class, $fh ) = @_;

    if ( eof $fh ) {
        return;
    }

    my $header = readline($fh);
    my $offset = tell($fh);

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
        'fh'        => $fh,
        'uid'       => hex($hexUid),
        'timestamp' => $timestamp,
        'flags'     => $flags,
        'size'      => $size,
        'offset'    => $offset
    }, $class;
}

sub write_to_handle {
    my ( $self, $outfh ) = @_;

    my $remaining = $self->{'size'};

    seek( $self->{'fh'}, $self->{'offset'}, 0 );

    while ( $remaining > 0 ) {
        my $len = $BUF_SIZE < $remaining ? $BUF_SIZE : $remaining;

        my $readlen = CORE::read( $self->{'fh'}, my $buf, $len );

        if ( !defined $readlen ) {
            die("Error reading message from file: $!");
        }

        print {$outfh} $buf;

        $remaining -= $readlen;
    }

    return $self->{'size'};
}
