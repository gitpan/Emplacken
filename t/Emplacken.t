use strict;
use warnings;

use Test::Fatal;
use Test::More;

use Emplacken;
use Path::Class qw( file );

my $exit_status;

{
    no warnings 'redefine';

    sub Emplacken::_exit { $exit_status = shift; }
}

{
    local @ARGV = (
        '--dir' => '.',
        'bad_command'
    );

    my $emplacken = Emplacken->new_with_options();

    like(
        exception { $emplacken->run() },
        qr/Invalid command for emplacken: bad_command/,
        'emplacken dies on bad commands'
    );
}

{
    local @ARGV = (
        '--dir' => '.',
        'start'
    );

    my $emplacken = Emplacken->new_with_options();

    like(
         exception { $emplacken->run() },
         qr/\QDid not find any PSGI application config files in ./,
         'error when no config files are found in the specified directory'
        );
}

{
    local @ARGV = (
        '--file' => $0,
        'start'
    );

    my $emplacken = Emplacken->new_with_options();

    like(
         exception { $emplacken->run() },
         qr/\QEmplacken.t is not a PSGI application config file/,
         'error when a single file is specified that is not a config file'
        );
}

{
    my $emplacken
        = Emplacken->new( dir => file($0)->dir()->subdir( 'conf', 'good' ) );

    my @apps = $emplacken->_psgi_apps();

    is(
        scalar @apps,
        2,
        'found two apps in conf dir (ignored empty file)'
    );

    is_deeply(
        [ sort map { $_->name() } @apps ],
        [ 'Special Name', 'app1' ],
        'found all the apps in the conf dir'
    );
}

{
    like(
        exception {
            Emplacken->new( dir => file($0)->dir()->subdir( 'conf', 'bad' ) )
                ->_psgi_apps();
        },
        qr/\Qbad1.conf does not contain a server key/,
        'error loading a config file without a server key'
    );
}

done_testing();
