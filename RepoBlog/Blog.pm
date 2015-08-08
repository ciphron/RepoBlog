
# This code is adpated and extended from Blosxom blog
# (blosxom.cgi found at http://blosxom.sourceforce.net)
# The code in this file is licensed under the same terms as Blosxom itself.
# See the license below.
#
# The copyright notice below applies to the parts of this code taken from blosxom.cgi
#
# Blosxom
# Copyright 2003, Rael Dornfest
#
# Adapted by Michael Clear in 2014
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies
# or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
# FOR ANY CLAIM, DAMAGES OR OTHER #LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE. 

package RepoBlog::Blog;

use Moose;

use FileHandle;
use File::Find;
use File::stat;
use Time::Local;
use Data::Dumper;

###############################################################################
# Definitions and Utilities
###############################################################################

my %month2num = (
    nil => '00',
    Jan => '01',
    Feb => '02',
    Mar => '03',
    Apr => '04',
    May => '05',
    Jun => '06',
    Jul => '07',
    Aug => '08',
    Sep => '09',
    Oct => '10',
    Nov => '11',
    Dec => '12'
);
my @num2month = sort { $month2num{$a} <=> $month2num{$b} } keys %month2num;

sub nice_date {
    my ($unixtime) = @_;

    my $c_time = CORE::localtime($unixtime);
    my ( $dw, $mo, $da, $hr, $min, $sec, $yr )
        = ( $c_time
            =~ /(\w{3}) +(\w{3}) +(\d{1,2}) +(\d{2}):(\d{2}):(\d{2}) +(\d{4})$/
        );
    my $ti = "$hr:$min";
    $da = sprintf( "%02d", $da );
    my $mo_num = $month2num{$mo};

    my $offset
        = timegm( $sec, $min, $hr, $da, $mo_num - 1, $yr - 1900 ) - $unixtime;
    my $utc_offset = sprintf( "%+03d", int( $offset / 3600 ) )
        . sprintf( "%02d", ( $offset % 3600 ) / 60 );

    return ( $dw, $mo, $mo_num, $da, $ti, $yr, $utc_offset );
}

sub create_date {
    my $time = shift;
    my ($dw, $mo, $mo_num, $da, $ti, $yr, $utc_offset )
	= nice_date($time);
    my ($hr, $min ) = split /:/, $ti;
    my ($hr12, $ampm) = $hr >= 12 ? ( $hr - 12, 'pm' ) : ( $hr, 'am' );
    $hr12 =~ s/^0//;
    if ( $hr12 == 0 ) { $hr12 = 12 }
    my %date = (
	'dw' => $dw,
	'mo' => $mo,
	'mo_num' => $mo_num,
	'da' => $da,
	'ti' => $ti,
	'yr' => $yr,
	'utc_offset' => $utc_offset,
	'hr' => $hr,
	'min' => $min,
	'hr12' => $hr12,
	'ampm' => $ampm
    );

    return %date;
}

sub process_path {
    my $path = shift;
    my @path_info = split m{/}, $path;

    # from blosxom.cgi (http://blosxom.sourceforce.net)
    my $path_info_full = join '/', @path_info;      # Equivalent to $ENV{PATH_INFO}
    shift @path_info;

    # Global variable to be used in head/foot.{flavour} templates
    my $path_info = '';

    if ($path_info_full =~ m</(.+)/revs(/(\d+))?>) {
	my %desc = (
	    'type' => 'revs',
	    'entry_name' => $1,
	    'rev_no' => $3
	);
	return %desc;
    }

    # Add all @path_info elements to $path_info till we come to one that could be a year
    while ( $path_info[0] && $path_info[0] !~ /^(19|20)\d{2}$/) {
	$path_info .= '/' . shift @path_info;
    }

    # Pull date elements out of path
    my $path_info_yr, my $path_info_mo_num, my $path_info_mo, my $path_info_da;
    if ($path_info[0] && $path_info[0] =~ /^(19|20)\d{2}$/) {
	$path_info_yr = shift @path_info;
	if ($path_info[0] && 
	    ($path_info[0] =~ /^(0\d|1[012])$/ || 
	     exists $month2num{ ucfirst lc $path_info_mo })) {
	    $path_info_mo = shift @path_info;
	    # Map path_info_mo to numeric $path_info_mo_num
	    $path_info_mo_num = $path_info_mo =~ /^\d{2}$/
		? $path_info_mo
		: $month2num{ ucfirst lc $path_info_mo };
	    if ($path_info[0] && $path_info[0] =~ /^[0123]\d$/) {
		$path_info_da = shift @path_info;
	    }
	}
    }

    # Add remaining path elements to $path_info
    $path_info .= '/' . join('/', @path_info);

    # Strip spurious slashes
    $path_info =~ s!(^/*)|(/*$)!!g;

    my %desc = (
	'type' => 'entries',
	'path_info' => $path_info,
	'path_info_yr' => $path_info_yr,
	'path_info_mo_num' => $path_info_mo_num,
	'path_info_da' => $path_info_da
    );

    return %desc;
}


###############################################################################
# Attributes
###############################################################################

# url and data_directory must be specified in constructor

has 'url' => (
    is => 'ro',
    isa => 'Str',
    traits => ['String'],
    required => 1
);


has 'data_directory' => (
    is => 'ro',
    isa => 'Str',
    traits => ['String'],
    required => 1
);

has 'depth' => (
    is => 'rw',
    isa => 'Int',
    traits => ['Number'],
    default => 0
);

has 'num_entries' => (
    is => 'rw',
    isa => 'Int',
    traits => ['Number'],
    default => 40
);

has 'show_future_entries' => (
    is => 'rw',
    isa => 'Bool',
    traits => ['Bool'],
    default => 0
);

has 'encode_xml_entities' => (
    is => 'rw',
    isa => 'Bool',
    traits => ['Bool'],
    default => 1
);


has 'file_extension' => (
    is => 'rw',
    isa => 'Str',
    traits => ['String'],
    default => 'txt'
);

has 'callbacks' => (
    is => 'ro',
    isa => 'HashRef[ArrayRef]',
    traits => ['Hash'],
    default => sub {{}}
);



###############################################################################
# Methods
###############################################################################

sub BUILD {
    my $self = shift;
}

sub add_callback {
    my ($self, $type, $callback) = @_;
    push(@{$self->callbacks->{$type}}, $callback);
}

sub generate {
    my ($self, $path, $content_type, $repo)
        = @_;

    # Local copies of attributes; these are interpolated
    my $file_extension = $self->file_extension;	
    my $datadir = $self->data_directory;

    my $url = $self->url;

    my %mapping = ();

    my $output = ''; # This is what we produce and return

    # Append head
    $output .= $self->_invoke_callbacks('head', \%mapping);

    my %desc = process_path($path);
    if ($desc{'type'} eq 'revs') {
	my $entry_name = $desc{'entry_name'};
	my $fn = $entry_name;
	my $fn_ext = $fn . '.' . $self->file_extension;
	my @revs = $repo->get_revisions($fn_ext);

	if (!defined($desc{'rev_no'})) {
	    # show list of revisions
	    $output .= "<h2>Revisions ($entry_name) </h2></br>";
	    my $rev_no = 1;

	    foreach my $rev (reverse @revs) {
		my $ctime = CORE::localtime($rev->{'time'});
		$output .= "<a href=\"$url/$entry_name/revs/$rev_no\"> Revision $rev_no ($ctime)</a></br>";
		$rev_no++;
	    }
	}
	else {
	    my $rev_no = (defined($desc{'rev_no'})) ? $desc{'rev_no'} : 0;
	    my %mdate = create_date($revs[-$rev_no]->{'time'});
	    my %cdate = create_date($revs[-1]->{'time'});
	    my $raw = join("\n", $repo->fetch_commit($fn_ext, $revs[-$rev_no]->{'commit'}));
	
	    $output .= $self->_generate_post($fn, \%mdate, \%cdate, $raw, $url, $path, $content_type);
	}
    }
    elsif ($desc{'type'} eq 'entries') {	
	my $currentdir = $desc{'path_info'};
	my $path_info_yr = $desc{'path_info_yr'};
	my $path_info_mo_num = $desc{'path_info_mo_num'};
	my $path_info_da = $desc{'path_info_da'};


	my $fh = new FileHandle;

	my ($files, $indexes, $others) = $self->_entries($repo);
	my %files = %$files;
	my %indexes = %$indexes;
	my %others = ref $others ? %$others : ();

	my %f = %files;


	# Stories
	my $ne = $self->num_entries;

	if ( $currentdir =~ /(.*?)([^\/]+)\.(.+)$/ and $2 ne 'index' ) {
	    $currentdir = "$1$2.$file_extension";
	    %f = ("$datadir/$currentdir" => $files{"$datadir/$currentdir"})
		if $files{"$datadir/$currentdir"};
	}
	else {
	    $currentdir =~ s!/index\..+$!!;
	}

	# Define a default sort subroutine
	my $sort = sub {
	    my ($files_ref) = @_;
	    return
		sort { $files_ref->{$b}->[0]->{'time'} <=> $files_ref->{$a}->[0]->{'time'} }
	    keys %$files_ref;
	};


	foreach my $path_file ( &$sort( \%f, \%others ) ) {
	    last if $ne <= 0 && !($path_info_yr || $path_info_mo_num || $path_info_da);
	    my ($path, $fn)
		= $path_file =~ m!^$datadir/(?:(.*)/)?(.*)\.$file_extension!;
	    $path = '' unless defined($path);

	    # Only stories in the right hierarchy
	    $path =~ /^$currentdir/
		or $path_file eq "$datadir/$currentdir"
		or next;
	    

	    # Prepend a slash for use in templates only if a path exists
	    $path &&= "/$path";

	    # Date fiddling for by-{year,month,day} archive views
	    my %mdate = create_date($files{"$path_file"}->[0]->{'time'});
	    my %cdate = create_date($files{"$path_file"}->[-1]->{'time'});
	    my $yr = $cdate{'yr'};
	    my $mo = $cdate{'mo'};
	    my $da = $cdate{'da'};

	    # Only stories from the right date
	    next if $path_info_yr     && $yr != $path_info_yr;
	    last if $path_info_yr     && $yr < $path_info_yr;
	    next if $path_info_mo_num && $mo ne $num2month[$path_info_mo_num];
	    next if $path_info_da     && $da != $path_info_da;
	    last if $path_info_da     && $da < $path_info_da;


	    my $title, my $body, my $raw;
	    if ( -f "$path_file" && $fh->open("< $path_file") ) {
		chomp($title = <$fh> );
		chomp($body = join '', <$fh> );
		$fh->close;
		$raw = "$title\n$body";
	    }
	    $output .= $self->_generate_post($fn, \%mdate, \%cdate, $raw, $url, $path, $content_type);
	    $fh->close;
	    
	    $ne--;
	}
    }
    
    # Append footer
    $output .= $self->_invoke_callbacks('foot', \%mapping);
    
    return $output;
}


sub _generate_post {
    my ($self, $fn, $mdate, $cdate, $raw, $url, $path, $content_type) = @_;

    my %mapping = ();

    my %mdate = %{$mdate};
    my %cdate = %{$cdate};
    my $yr = $cdate{'yr'};
    my $mo = $cdate{'mo'};
    my $da = $cdate{'da'};

    my @parts = split(/\n/, $raw);
    my $title = $parts[0];
    my $body = join("\n", splice(@parts, 1));

    if ( $self->encode_xml_entities() &&
	 $content_type =~ m{\bxml\b} &&
	 $content_type !~ m{\bxhtml\b} ) {
	# Escape special characters inside the <link> container
	
	# The following line should be moved more towards to top for
	# performance reasons -- Axel Beckert, 2008-07-22
	my $url_escape_re = qr([^-/a-zA-Z0-9:._]);

	$url   =~ s($url_escape_re)(sprintf('%%%02X', ord($&)))eg;
	$path  =~ s($url_escape_re)(sprintf('%%%02X', ord($&)))eg;
	$fn    =~ s($url_escape_re)(sprintf('%%%02X', ord($&)))eg;

	# Escape <, >, and &, and to produce valid RSS
	my %escape = (
	    '<' => '&lt;',
	    '>' => '&gt;',
	    '&' => '&amp;',
	    '"' => '&quot;',
	    "'" => '&apos;'
        );
	my $escape_re = join '|' => keys %escape;
	$title =~ s/($escape_re)/$escape{$1}/g;
	$body  =~ s/($escape_re)/$escape{$1}/g;
	$url   =~ s/($escape_re)/$escape{$1}/g;
	$path  =~ s/($escape_re)/$escape{$1}/g;
	$fn    =~ s/($escape_re)/$escape{$1}/g;
    }

    $mapping{'post'} = {
	'title' => $title,
	'body' => $body,
	'url' => $url,
	'path' => $path,
	'fn' => $fn,
	'cdate' => \%cdate,
	'mdate' => \%mdate
    };
	
    # Append story
    my $output = $self->_invoke_callbacks('story', \%mapping);
    $output .= "</br><a href=\"$url/$fn/revs\">Revisions</a>";
    return $output;
}

sub _entries {
    my $self = shift;
    my $repo = shift;
    my $file_extension = $self->file_extension;
    my $datadir = $self->data_directory;
    my $depth = $self->depth;

    my (%files, %indexes, %others);
    find(
        sub {
            my $d;
            my $curr_depth = $File::Find::dir =~ tr[/][];
            return if $depth and $curr_depth > $depth;

            if (
                # a match
                $File::Find::name
                =~ m!^$datadir/(?:(.*)/)?(.+)\.$file_extension$!

                # not an index, .file, and is readable
                and $2 ne 'index' and $2 !~ /^\./ and ( -r $File::Find::name )
                )
            {

                # read modification time
                #my $mtime = stat($File::Find::name)->mtime or return;
		my @revs = $repo->get_revisions($File::Find::name);
		return unless scalar(@revs) > 0;
		my $mtime = $revs[0]->{'time'};

                # to show or not to show future entries
                return unless ($self->show_future_entries() or $mtime < time);

                # add the file and its associated mtime to the list of files
                $files{$File::Find::name} = \@revs;
            }

            # not an entries match
            elsif ( !-d $File::Find::name and -r $File::Find::name ) {
                $others{$File::Find::name} = stat($File::Find::name)->mtime;
            }
        },
        $datadir
    );

    return ( \%files, \%indexes, \%others );
}


sub _invoke_callbacks {
    my $self = shift;
    my $type = shift;
    my $arg = shift;

    return '' unless defined($self->callbacks()->{$type});

    my @callbacks = @{$self->callbacks()->{$type}};
    my $result = '';
    foreach my $callback (@callbacks) {
	$result .= &$callback($arg);
    }

    return $result;
}




no Moose;

1;
