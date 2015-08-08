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


#!/usr/bin/perl

use System::Command;
use Getopt::Long;
use Git::Repository;
use Cwd;

# my @o = ('/bin/echo', 'hello');
# my $cmd = System::Command->new(@o);
# my $ot = $cmd->stdout();
# my $line = $ot->getline;
# $cmd->close();

# print $line;

run();

sub get_revision_info {
    my ($rep, $fn) = @_;

    my @lines = $rep->run(('log', '--pretty=format:%H,%at', $fn));
    my @revs = ();
    foreach (@lines) {
    	my ($c, $tm) = /^([0-9a-fA-F]+),(\d+)/;
    	push(@revs, {'commit' => $c, 'time' => $tm});
    }

    return @revs;
}

sub fetch_commit {
    my ($rep, $fn, $commit) = @_;

    my @lines = $rep->run(('show', "$commit:$fn"));

    return @lines;
}



sub run {
    my $cmd;

    my $working_dir = cwd();
    my $git_bin = '/usr/bin/git';

    GetOptions('dir:s' => \$working_dir, 'git:s' => \$git_bin) or die("Invalid options");

    my $n_args = @ARGV;
    die("Not enough arguments") unless $n_args >= 2;

    my $rep = Git::Repository->new(work_tree => $working_dir,
	{git => $git_bin});

    if ($ARGV[0] eq 'revs') {
	my $fn = $ARGV[1];
	my @revs = get_revision_info($rep, $fn);
	print $_->{'commit'}, "\t", $_->{'time'}, "\n", foreach (@revs);
    }
    elsif ($ARGV[0] eq 'fetch' && $n_args == 3) {
	my $fn = $ARGV[1];
	my $commit = $ARGV[2];
	my @lines = fetch_commit($rep, $fn, $commit);
	print $_, "\n" foreach (@lines);
    }
    else {
	die("Invalid command");
    }
}
