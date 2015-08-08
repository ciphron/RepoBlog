#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.

package RepoBlog::App;

use Apache2::SubProcess;
use Plack::Request;
use Data::Dumper;
use Template;
use Moose;

use constant BLOG_TITLE => 'ciphron\'s blog';
use constant DIRECTORY => '/opt/ciphron/blog';
use constant URL => 'http://localhost/blog';
use constant DATA_DIRECTORY => DIRECTORY . '/posts';

use System::Command;

require RepoBlog::Blog;

# These variables are defined below on demand
my $blog;
my $tt;


sub mk_callback {
    my $name = shift;
    my $config = shift;
    
    return sub {
	my $r = shift;
	my %mapping = %$r;
	$mapping{'title'} = $config->{'TITLE'};
	
	my $content;
	$tt->process("templates/$name.tt", \%mapping,
		     \$content) or die $tt->error;

	return $content;
    };
}


sub get_app {
    my $repo = shift;
    my $config = shift;

    unless (defined($blog)) {
	$tt = Template->new({
	    INCLUDE_PATH => $config->{'SITE_DIR'},
	    RELATIVE => 1
	});

	$blog = RepoBlog::Blog->new(url => $config->{'URL'},
				    data_directory => $config->{'POSTS_DIR'});

	$blog->add_callback($_, mk_callback($_, $config))
	    foreach ('head', 'story', 'foot');
    }

    return sub {
	my $r = shift;
	my $req = Plack::Request->new($r);
	my $out;
	my $body;

	# my @o = ('/bin/echo', 'hello');
	# my $cmd = System::Command->new(@o);
	# $cmd->close();
	# my $ot = $cmd->stdout();
	# my $line = $ot->getline;

	$out = $blog->generate($req->path_info, 'text/html', $repo);

	return [200, ['Content-Type', 'text/html'], [$out]]
    }
}

1;
