use strict;
use warnings;

use Test::More;

use Emplacken::Stderr;

{
    my $buffer = q{};
    open my $fh, '>', \$buffer;

    {
        local *STDERR = *STDERR;
        tie *STDERR, 'Emplacken::Stderr', fh => $fh;

        local $Emplacken::Stderr::Env = { REMOTE_ADDR => '127.0.0.1' };

        warn "Test \r 1\n";
    }

    close $fh;

    like(
        $buffer,
         qr/^\[\w{3} \w{3} \d{2} \d{2}:\d{2}:\d{2} \d{4}\Q] [error] [client 127.0.0.1] Test \x0d 1\E\n$/,
        'Emplacken::Stderr caught warning and formatted it for logging'
    );
}

done_testing();
