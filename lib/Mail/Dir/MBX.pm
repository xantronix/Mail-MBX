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
        $line =~ m/( \d|\d\d)-(\w\w\w)-(\d\d\d\d) (\d\d):(\d\d):(\d\d) ([+-])(\d\d)(\d\d),(\d+);([[:xdigit:]]{8})([[:xdigit:]]{4})-([[:xdigit:]]{8})\r\n$/ or die("Syntax error in MBX file $file");

        if ( $13 eq '00000000' ) {
            $lazyuid++;
        }
        else {
            $lazyuid = hex($13);
        }

        # tidyoff -- perltidy would wreak havoc on this poor expression
        my $hexuid = sprintf( '%08x', $lazyuid );

        my $flags = 
          ( ( hex($12) & 0x1 ) ? 'S' : '' )
          . ( ( hex($12) & 0x2 ) ? 'T' : '' )
          . ( ( hex($12) & 0x4 ) ? 'F' : '' )
          . ( ( hex($12) & 0x8 ) ? 'R' : '' );
    
        my $timestamp = Time::Local::timegm(
            $6, $5, $4, $1 + 0, $MONTHS{$2}, $3 )
            + ( ( $8 eq '-' ? 1 : -1 ) * ( $8 * 60 + $9 ) * 60 );
        # tidyon

        my $size  = $10;
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
