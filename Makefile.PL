use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'HTML::Widget::DBIC',
    VERSION_FROM => 'lib/HTML/Widget/DBIC.pm', # finds $VERSION
    AUTHOR       => 'Zbigniew Lukasiak (a.u.thor@a.galaxy.far.far.away)',
    ABSTRACT     => '',
    PREREQ_PM    => {
                     'Test::Simple' => 0.44,
                     'HTML::Widget' => 0,
                     'DBIx::Class'  => 0,
                    },
);
