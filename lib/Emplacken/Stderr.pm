package Emplacken::Stderr;
BEGIN {
  $Emplacken::Stderr::VERSION = '0.01';
}

use strict;
use warnings;

use base 'Tie::Handle';

use POSIX ();

our $Env;

sub TIEHANDLE {
    my $class = shift;
    my %p = @_;

    my $self = bless \%p, $class;

    $self->{format} ||= '[%t] [error] [client %a] %M';

    return $self;
}

sub PRINT {
    my $self = shift;

    my $error = join q{}, grep {defined} @_;
    $error =~ s/\n$//;
    $error =~ s/([^[:print:]])/"\\x" . unpack("H*", $1)/eg;

    my $output = $self->{format};
    $output =~ s/%t/_strftime()/eg;
    $output =~ s/%a/$Env->{REMOTE_ADDR}/g;
    $output =~ s/%M/$error/g;

    print { $self->{fh} } $output, "\n";
}

# Stolen from Plack::Middleware::AccessLog
sub _strftime {
    my $old_locale = POSIX::setlocale(&POSIX::LC_ALL);
    POSIX::setlocale( &POSIX::LC_ALL, 'en' );
    my $out = POSIX::strftime( '%a %b %d %T %Y', localtime );
    POSIX::setlocale( &POSIX::LC_ALL, $old_locale );
    return $out;
}

1;
