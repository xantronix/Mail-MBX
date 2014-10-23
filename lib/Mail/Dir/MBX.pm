package Mail::Dir::MBX;

use strict;
use warnings;

use Mail::Dir              ();
use Mail::Dir::MBX::Header ();

our @ISA = qw(Mail::Dir);

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
        chomp($line = readline($fh));

        if ( $line ne '' ) {
            push( @keywords, $line );
        }
    }

    seek( $fh, 2048, 0 );

    my $lazyuid   = 0;
    my $delivered = 0;

    while ( $line = readline($fh) ) {
        my $header = Mail::Dir::MBX::Header->parse($line);

        if ($header->{'uid'} == 0) {
            $header->{'uid'} = ++$lazyuid;
        }

        my $start = tell($fh);
        my $end   = $start + $header->{'size'} - 1;

        my $message = $self->deliver(sub {
            my ($out) = @_;

            my $remaining = $header->{'size'};
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

        $message->mark($header->{'flags'});
    }

    close $fh;

    return $delivered;
}
