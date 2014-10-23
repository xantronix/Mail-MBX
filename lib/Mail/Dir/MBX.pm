package Mail::Dir::MBX;

use strict;
use warnings;

use Time::Local ();
use Mail::Dir   ();

our @ISA = qw(Mail::Dir);

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

sub import_mbx_file {
    my ($self, $file) = @_;

    open( my $fh, '<', $file ) or die("Unable to open mailbox file $file: $!");

    my $line = readline($fh);

    #
    # If the first line of the file is empty, then 
    #
    if (!defined $line) {
        return;
    } elsif ( $line ne "*mbx*\r\n" ) {
        die("File $file is not an MBX file: $line");
    }

    my $uidvalidity;
    my @keywords;

    $line = readline($fh);

    if ( $line =~ /^([[:xdigit:]]{8})([[:xdigit:]]{8})\r\n$/ ) {
        $uidvalidity = hex($1);
    } else {
        die("File $file has invalid UID line");
    }

    foreach my $n ( 0 .. 29 ) {
        $line = readline($fh);
        $line =~ s/\r\n//;
        if ( $line ne '' ) {
            push( @keywords, $line );
        }
    }

    seek( $fh, 2048, 0 );

    my $lazyuid   = 0;
    my $delivered = 0;

    while ( $line = readline($fh) ) {
        #
        # tidyoff -- perltidy would wreak havoc on this poor expression
        #
        my ( $date, $time, $metadata ) = split /\s+/, $line;

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

        my ( $unused, $hexFlags, $uid ) = (
            $attributes
                =~
            /^([[:xdigit:]]{8})([[:xdigit:]]{4})-([[:xdigit:]]{8})$/
        ) or die('Invalid syntax: Bad attributes');

        if ( $uid eq '00000000' ) {
            $lazyuid++;
        }
        else {
            $lazyuid = hex($uid);
        }

        my $hexuid = sprintf( '%08x', $lazyuid );

        my $flags = 
            ( ( hex($hexFlags) & 0x1 ) ? 'S' : '' )
          . ( ( hex($hexFlags) & 0x2 ) ? 'T' : '' )
          . ( ( hex($hexFlags) & 0x4 ) ? 'F' : '' )
          . ( ( hex($hexFlags) & 0x8 ) ? 'R' : '' );
    
        my $timestamp = Time::Local::timegm(
            $second, $minute, $hour, $day + 0, $MONTHS{$month}, $year
        ) + ( ( $tzNegative eq '-' ? 1 : -1 )
          * ( $tzHourOffset * 60 + $tzMinuteOffset ) * 60 );

        # tidyon

        my $start = tell($fh);
        my $end   = $start + $size - 1;

        my $message = $self->deliver(sub {
            my ($out) = @_;

            my $remaining = $size;
            my $chunk     = 4096;

            while ($remaining > 0) {
                my $len = $chunk < $remaining? $chunk: $remaining;

                my $readlen = read($fh, my $buf, $len);

                if (!defined $readlen) {
                    die("Error reading @{[tell $fh]} from file $file: $!");
                }

                print {$out} $buf;

                $remaining -= $readlen;
            }

            $delivered++;
        });

        $message->mark($flags);
    }

    close $fh;

    return $delivered;
}
