use strict;
use warnings;
use autodie;

use Test::Compile;
use Test::Fatal;
use Test::More;

use Class::Load qw( try_load_class );
use Emplacken::App;
use Emplacken::App::Starman;
use File::Temp qw( tempdir );
use Path::Class qw( dir file );

my $test_code = eval {
    require Perl::Tidy;
    require Test::Differences;
    1;
};

# need to set this so that compilation tests can see MyApp.pm
$ENV{PERL5LIB} = join ':', ( $ENV{PERL5LIB} || () ), dir( 't', 'lib' );

my $tempdir = dir( tempdir( CLEANUP => 1 ) );
my $conf_base = file($0)->dir()->subdir('conf');
my $conf_file = $conf_base->file( 'good', 'app1.conf' );
my $psgi_file = $tempdir->file('app1.psgi');

{
    my $app = Emplacken::App->new(
        file              => $conf_file,
        psgi_app_file     => $psgi_file,
        builder           => 'Catalyst',
        app_class         => 'MyApp1',
        server            => 'plackup',
        include           => [ '/foo', '/bar' ],
        modules           => [ 'Mod::X', 'Mod::Y' ],
        listen            => 'localhost:9876',
        user              => 'www-data',
        group             => 'nobody',
        pid_file          => 'foo.pid',
        reverse_proxy     => 1,
        access_log        => 'access.log',
        access_log_format => '%a %b %c',
        error_log         => 'error.log',
    );

    is(
        $app->name(),
        'app1',
        'name is built from file basename w/o extension',
    );

    is_deeply(
        $app->_command_line(),
        [
            qw(
                plackup -D
                -I /foo -I /bar
                -M Mod::X -M Mod::Y
                --listen localhost:9876
                ),
            $psgi_file,
        ],
        'command line for app'
    );

    my $code = _slurp($psgi_file);

    my $expect = <<'EOF';
use strict;
use warnings;

use Plack::Builder;
use MyApp1;
use autodie;
use Emplacken::Stderr;
use File::Pid;

open my $access_log_fh, '>>', "access.log";
open my $error_log_fh, '>>', "error.log";
tie *STDERR, 'Emplacken::Stderr', fh => $error_log_fh;

my $pid = File::Pid->new( file => "foo.pid" );
die 'The ' . "app1" . " application is already running\n" if $pid->running();
$pid = File::Pid->new( file => "foo.pid", pid => $$ );
$pid->write();

MyApp1->setup_engine('PSGI');

builder {
    local $Emplacken::Stderr::Env = $_[0];

    enable_if { $_[0]->{REMOTE_ADDR} eq '127.0.0.1' } 'Plack::Middleware::ReverseProxy';
    enable 'Plack::Middleware::AccessLog',
        format => "%a %b %c",
        logger => sub { print {$access_log_fh} @_ };

    sub { MyApp1->run(@_) };
};

$pid->remove();
EOF

    _tidy_compare( $code, $expect, 'generated psgi app code for Catalyst app' );

 SKIP:
    {
        skip 'This test requires Catalyst to be installed', 1
            unless try_load_class('Catalyst::Runtime');

        pl_file_ok( $psgi_file, 'Catalyst psgi app' );
    }
}

{
    my $app = Emplacken::App->new(
        file          => $conf_file,
        psgi_app_file => $psgi_file,
        builder       => 'Mojo',
        app_class     => 'MyApp1',
        server        => 'plackup',
        listen        => 'localhost:9876',
        pid_file      => 'foo.pid',
    );

    $app->_write_psgi_app();

    my $code = _slurp($psgi_file);

    my $expect = <<'EOF';
use strict;
use warnings;

use Plack::Builder;
use Mojo::Server::PSGI;
use MyApp1;
use File::Pid;

my $pid = File::Pid->new( file => "foo.pid" );
die 'The ' . "app1" . " application is already running\n" if $pid->running();
$pid = File::Pid->new( file => "foo.pid", pid => $$ );
$pid->write();

my $server = Mojo::Server::PSGI->new( app_class => 'MyApp1' );

builder {

    sub { $server->run(@_) };
};

$pid->remove();
EOF

    _tidy_compare( $code, $expect, 'generated psgi app code for Mojo app' );

 SKIP:
    {
        skip 'This test requires Mojo to be installed', 1
            unless try_load_class('Mojo::Server::PSGI');

        pl_file_ok( $psgi_file, 'Mojo PSGI app compiles' );
    }
}

{
    my $app = Emplacken::App->new(
        file          => $conf_file,
        psgi_app_file => $psgi_file,
        builder       => 'Mason',
        comp_root     => '/comp/root',
        data_dir      => '/data/dir',
        server        => 'plackup',
        listen        => 'localhost:9876',
        pid_file      => 'foo.pid',
    );

    $app->_write_psgi_app();

    my $code = _slurp($psgi_file);

    my $expect = <<'EOF';
use strict;
use warnings;

use Plack::Builder;
use HTML::Mason::PSGIHandler;
use File::Pid;

my $pid = File::Pid->new( file => "foo.pid" );
die 'The ' . "app1" . " application is already running\n" if $pid->running();
$pid = File::Pid->new( file => "foo.pid", pid => $$ );
$pid->write();

my $handler = HTML::Mason::PSGIHandler->new(
    comp_root => "/comp/root",
    data_dir  => "/data/dir",
);

builder {

    sub { $handler->handle_psgi(@_) };
};

$pid->remove();
EOF

    _tidy_compare( $code, $expect, 'generated psgi app code for Mojo app' );


 SKIP:
    {
        skip 'This test requires HTML::Mason::PSGIHandler', 1
            unless try_load_class('HTML::Mason::PSGIHandler');

        pl_file_ok( $psgi_file, 'Mason PSGI app compiles' );
    }
}

{
    my $app = Emplacken::App->new(
        file          => $conf_file,
        psgi_app_file => $psgi_file,
        builder       => 'FromTemplate',
        template      => file( 't', 'share', 'app.psgi.tmpl' ),
        server        => 'plackup',
        listen        => 'localhost:9876',
        pid_file      => 'foo.pid',
    );

    $app->_write_psgi_app();

    my $code = _slurp($psgi_file);

    my $expect = <<'EOF';
use strict;
use warnings;

use Mojo::Server::PSGI;
use MyApp1;
use Plack::Builder;
use File::Pid;

my $pid = File::Pid->new( file => "foo.pid" );
die 'The ' . "app1" . " application is already running\n" if $pid->running();
$pid = File::Pid->new( file => "foo.pid", pid => $$ );
$pid->write();

my $server = Mojo::Server::PSGI->new( app_class => 'MyApp1' );

builder {

    sub { $server->run(@_) };
};

$pid->remove();
EOF

    _tidy_compare( $code, $expect, 'generated psgi app code for Mojo app built from user-supplied template' );

 SKIP:
    {
        skip 'This test requires Mojo to be installed', 1
            unless try_load_class('Mojo::Server::PSGI');

        pl_file_ok( $psgi_file, 'user-supplied template app compiles' );
    }
}

{
    my $app = Emplacken::App::Starman->new(
        file              => $conf_file,
        psgi_app_file     => $psgi_file,
        builder           => 'Mojo',
        app_class         => 'MyApp1',
        server            => 'Starman',
        include           => [ '/foo', '/bar' ],
        modules           => [ 'Mod::X', 'Mod::Y' ],
        listen            => 'localhost:9876',
        user              => 'www-data',
        group             => 'nobody',
        pid_file          => 'foo.pid',
        disable_keepalive => 1,
        workers           => 3,
        max_requests      => 500,
        preload_app       => 1,
        backlog           => 1000,
    );

    is_deeply(
        $app->_command_line(),
        [
            qw(
                starman -D
                --workers 3
                --disable-keepalive
                --preload-app
                --backlog 1000
                --max-requests 500
                --user www-data
                --group nobody
                --pid foo.pid
                -I /foo -I /bar
                -M Mod::X -M Mod::Y
                --listen localhost:9876
                ),
            $psgi_file,
        ],
        'command line for app'
    );
}

sub _slurp {
    open my $fh, '<', shift;
    local $/;
    return <$fh>;
}

sub _tidy_compare {
    my $got    = shift;
    my $expect = shift;
    my $desc   = shift;

SKIP:
    {
        skip 'This test requires Perl::Tidy and Test::Differences', 1
            unless $test_code;

        my $got_tidy;
        Perl::Tidy::perltidy(
            source      => \$got,
            destination => \$got_tidy,
        );

        my $expect_tidy;
        Perl::Tidy::perltidy(
            source      => \$expect,
            destination => \$expect_tidy,
        );

        Test::Differences::eq_or_diff( $got_tidy, $expect_tidy, $desc );
    }
}

done_testing();
