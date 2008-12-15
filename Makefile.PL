use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'			=> 'Alchemy::Blog',
    'VERSION_FROM'	=> 'lib/Alchemy/Blog.pm', # finds $VERSION
	'INSTALLSCRIPT'	=> '/usr/local/bin',
    'PREREQ_PM'		=> 	{	
							'KrKit'				=> '0',
							'Apache2::Request' 	=> '0',
							'XML::RSS'			=> '1.02',
							'XMLRPC::Lite'		=> '0.55',
						},
	'EXE_FILES'		=> 	[ 
							'bin/blog_rpc_notify.pl',
							'bin/blog_roll.pl',
						],
);
