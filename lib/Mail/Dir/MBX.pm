package Mail::Dir::MBX;

use strict;
use warnings;

use Mail::Dir            ();
use Mail::Dir::MBX::File ();

our @ISA = qw(Mail::Dir);

sub import_mbx_file {
    my ( $self, $file ) = @_;

    my $mbx       = Mail::Dir::MBX::File->open($file);
    my $delivered = 0;

    while ( my $mbx_message = $mbx->message ) {
        my $maildir_message = $self->deliver(
            sub {
                my ($fh) = @_;

                $mbx_message->write_to_handle($$fh);

                $delivered++;
            }
        );

        $maildir_message->mark( $mbx_message->{'flags'} );
    }

    $mbx->close;

    return $delivered;
}
