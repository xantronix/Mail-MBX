package Mail::Dir::MBX::File;

use strict;
use warnings;

use Mail::Dir::MBX::Message ();

our @ISA = qw(Mail::Dir);

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

sub DESTROY {
    my ($self) = @_;

    $self->close;

    return;
}

sub close {
    my ($self) = @_;

    if ( defined $self->{'fh'} ) {
        close $self->{'fh'};
        undef $self->{'fh'};
    }

    return;
}

sub message {
    my ($self) = @_;

    if ( eof $self->{'fh'} ) {
        return;
    }

    my $message = Mail::Dir::MBX::Message->read( $self->{'fh'} );

    if ( $message->{'uid'} == 0 ) {
        $message->{'uid'} = ++$self->{'uid'};
    }

    return $message;
}
