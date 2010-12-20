
use strict;
use warnings;



use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
  'ABSTRACT' => 'Manage multiple plack apps with a directory of config files',
  'AUTHOR' => 'Dave Rolsky <autarch@urth.org>',
  'BUILD_REQUIRES' => {
    'File::Temp' => '0',
    'Test::Compile' => '0',
    'Test::Fatal' => '0',
    'Test::More' => '0.88'
  },
  'CONFIGURE_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.31'
  },
  'DISTNAME' => 'Emplacken',
  'EXE_FILES' => [
    'bin/emplacken'
  ],
  'LICENSE' => 'artistic_2',
  'NAME' => 'Emplacken',
  'PREREQ_PM' => {
    'Class::Load' => '0',
    'Config::Any' => '0',
    'File::Pid' => '0',
    'List::AllUtils' => '0',
    'Moose' => '0',
    'MooseX::Getopt' => '0',
    'MooseX::Types' => '0',
    'MooseX::Types::Path::Class' => '0',
    'MooseX::Types::Perl' => '0',
    'Path::Class' => '0',
    'Text::Template' => '0',
    'autodie' => '0',
    'namespace::autoclean' => '0'
  },
  'VERSION' => '0.01',
  'test' => {
    'TESTS' => 't/*.t'
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



