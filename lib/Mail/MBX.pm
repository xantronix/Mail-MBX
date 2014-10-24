package Mail::MBX;

use strict;
use warnings;

use Mail::MBX::Message ();

our $VERSION = '0.01';

sub open {
    my ( $class, $file ) = @_;

    my $uidvalidity;
    my @keywords;

    open( my $fh, '<', $file ) or die("Unable to open mailbox file $file: $!");

    my $line = readline($fh);

    #
    # If the first line of the file is empty, then
    #
    if ( !defined $line ) {
        return;
    }

    elsif ( $line ne "*mbx*\r\n" ) {
        die("File $file is not an MBX file");
    }

    $line = readline($fh);

    if ( $line =~ /^([[:xdigit:]]{8})([[:xdigit:]]{8})\r\n$/ ) {
        $uidvalidity = hex($1);
    }
    else {
        die("File $file has invalid UID line");
    }

    foreach ( 0 .. 29 ) {
        chomp( $line = readline($fh) );

        if ( $line ne '' ) {
            push( @keywords, $line );
        }
    }

    seek( $fh, 2048, 0 );

    return bless {
        'file'        => $file,
        'fh'          => $fh,
        'uidvalidity' => $uidvalidity,
        'keyword'     => \@keywords,
        'uid'         => 0
    }, $class;
}

sub close {
    my ($self) = @_;

    if ( defined $self->{'fh'} ) {
        close $self->{'fh'};
        undef $self->{'fh'};
    }

    return;
}

sub DESTROY {
    my ($self) = @_;

    $self->close;

    return;
}

sub message {
    my ($self) = @_;

    if ( eof $self->{'fh'} ) {
        return;
    }

    my $message = Mail::MBX::Message->read( $self->{'fh'} );

    if ( $message->{'uid'} == 0 ) {
        $message->{'uid'} = ++$self->{'uid'};
    }

    return $message;
}

sub import_to_maildir {
    my ( $self, $maildir ) = @_;

    my $delivered = 0;

    while ( my $mbx_message = $self->message ) {
        my $maildir_message = $maildir->deliver(
            sub {
                my ($fh) = @_;

                $mbx_message->write_to_handle($$fh);

                $delivered++;
            }
        );

        $maildir_message->mark( $mbx_message->{'flags'} );
    }

    return $delivered;
}

1;
