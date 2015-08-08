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

package RepoBlog::Handler;
use Plack::Handler::Apache2;
use Apache2::SubProcess;
use Data::Dumper;
use Carp;


require RepoBlog::App;

use constant CONFIG_FILE => '/opt/ciphron/blog/blog.config';

sub trim {
    my $str = shift;

    # Regex from http://perlmaven.com/trim
    $str =~ s/^\s+|\s+$//g;
    return $str;
}

sub read_config_file {
    my $file_name = shift;

    open(my $fh, '<', $file_name) or die "Cannot open file $file_name";

    my %config = ();

    foreach (<$fh>) {
        chomp;
        unless ($_ eq "") {
            my @parts = split('=');

            unless (@parts == 2) {
                die 'Invalid configuration setting';
            }

            $config{trim($parts[0])} = trim($parts[1]);
        }   
    }

    close($fh);

    return \%config;
}


{
    package RepoBlog::GitRepository;
    use Moose;
   
    sub BUILD {
	my $self = shift;	
	my $args = shift;
    
	$self->{'req'} = $args->{'req'};
	$self->{'config'} = $args->{'config'};
    }

    sub get_revisions {
	my $self = shift;
	my $fn = shift;

	my $fetch_script = $self->{'config'}->{'FETCH_SCRIPT'};
	my $posts_dir = $self->{'config'}->{'POSTS_DIR'};

	my $out_fh = $self->{'req'}->spawn_proc_prog($fetch_script,
						     ['--dir', $posts_dir,
						      'revs', $fn]);
	my @revs;
	foreach (<$out_fh>) {
	    my @parts = split;
	    push(@revs, {'commit' => $parts[0], 'time' => $parts[1]});
	}

	return @revs;
    }

    sub fetch_commit {
	my $self = shift;
	my $fn = shift;
	my $commit = shift;

	my $fetch_script = $self->{'config'}->{'FETCH_SCRIPT'};
	my $posts_dir = $self->{'config'}->{'POSTS_DIR'};

	my $out_fh = $self->{'req'}->spawn_proc_prog($fetch_script,
						     ['--dir', $posts_dir,
						      'fetch', $fn, $commit]);

	my @lines = <$out_fh>;
	return @lines;
    }

	with 'RepoBlog::Repository';
}


sub handler {
    my $r = shift;
    my $config = read_config_file(CONFIG_FILE);
    my $repo = RepoBlog::GitRepository->new(req => $r, config => $config);
    my $app = RepoBlog::App::get_app($repo, $config);
    Plack::Handler::Apache2->call_app($r, $app);
}

1;
