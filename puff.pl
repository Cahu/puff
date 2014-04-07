use strict;
use warnings;

use Curses;
use Carp qw(croak);

$SIG{__DIE__} = sub {
	endwin;
	croak;
};

my $prompt = ">>> ";
my $cmd = "find -L . 2> /dev/null";

print "Running: `$cmd`...\n";
my $str = `$cmd` or die "'$cmd' returned an error";

my @list =
	map  { $_ =~ s/\.\///r   }  # remove leading './'
	grep { $_ !~ m@^(..|.)$@ }  # filter out '.' and '..'
	split("\n", $str);          # separate each file path


# make a directory tree
print "Building the directory tree...\n";
my $TREE = build_tree(\@list);



sub build_tree {
	my ($list) = @_;

	my %tree = (
		match   => 1,
		cmatch  => 1,
		path    => ".",
		content => {},
	);

	for my $f (@$list) {
		my @parts  = split('/', $f);

		my @path   = ();
		my $folder = $tree{content};

		while (defined (my $p = shift @parts)) {
			push @path, $p;
			$folder->{$p} //= {
				match   => 1,                 # include this dir in the results?
				cmatch  => 1,                 # children match?
				path    => join("/", @path),  # the full path
				content => { },               # this dir's contents
			};
			$folder = $folder->{$p}{content};
		}
	}

	return \%tree;
}


sub flatten_tree {
	my ($tree) = @_;

	my @trees = ($tree);

	my @in = ();
	my @matching = ();

	while (defined (my $t = shift @trees)) {

		# filter matching dirs
		if ($t->{match}) {
			# thanks to sorting, dirs are pushed in alphabetical order
			push @matching, $t;
		}

		elsif (!$t->{cmatch}) {
			# don't bother going down, no child match
			next;
		}

		else {
			# find subdirs that match
			my $subdirs = $t->{content};
			push @trees, $subdirs->{$_} for (sort keys %$subdirs);
		}
	}

	while (defined (my $match = shift @matching)) {

		# add
		push @in, $match->{path};

		my $subdirs = $match->{content};
		# schedule subdirs, still sorted (have to apply reverse order here...)
		for my $subdir (reverse sort keys %$subdirs) {
			unshift @matching, $subdirs->{$subdir};
		}
	}

	return \@in;
}


my $M = "M";

my $res_win;
my $cmd_win;
my ($row, $col);
sub make_scr {
	getmaxyx($row, $col);

	$res_win = newwin($row-1, $col  , 0     , 0);
	$cmd_win = newwin(1     , $col  , $row-1, 0);

	$res_win->scrollok(1);

	$cmd_win->scrollok(1);
	$cmd_win->keypad(1);     # Allow mapping of keys to constants (such as KEY_DOWN, etc)

	# Populate results window
	&populate_result;

	# prepare prompt
	$cmd_win->addstr(0, 0, $prompt);
	$cmd_win->refresh();

	# Don't print typed keys, we will handle it ourself
	noecho;
}


sub populate_result {
	$res_win->clear();
	$res_win->move(0, 0);
	$res_win->addstr(join("\n", @{$_[0]}[-$row..-1]));
	$res_win->refresh();
}


my $prev_search = "";
my $prev_pattern = "";

sub filter_res {
	my ($search) = @_;

	my $pattern = "";
	$pattern   .= "[^\Q$_\E]*\Q$_\E" for (split('', $search));

	my $more_restrictive = ($search =~ /$prev_pattern/i);
	my $less_restrictive = ($prev_search =~ /$pattern/i);

	croak "Restrictiveness inconsistencies" if ($more_restrictive && $less_restrictive);

	$prev_search  = $search;
	$prev_pattern = $pattern;

	$M = $more_restrictive ? "M" : "L";

	my @in; # keep track of match
	my @trees = ($TREE);

	while (defined (my $t = shift @trees)) {

		if ($more_restrictive) {
			# search more restrictive than before

			if ($t->{match}) {
				# try the more restrictive match on dirs that matched before
				$t->{match} = ($t->{path} =~ /$pattern/i);

				if ($t->{match}) {
					push @in, $t->{path};
				} else {
					# didn't match the new search, maybe some hope on children?
					for (values %{ $t->{content} }) {
						# propagate the previous matching status to children. it
						# is a bug if we don't do this because the re-checking
						# for children's path won't happen otherwise.
						$_->{match} = 1;
						push @trees, $_;
					}
				}
			}

			elsif (! $t->{cmatch}) {
				# more restrictive search and no child matched previously
				# => don't bother going down
				;
			}

			else {
				# add subdirs for checking since there is hope a child will
				# match
				push @trees, values %{ $t->{content} };
			}
		}

		elsif ($less_restrictive) {
			# search less restrictive than before

			if ($t->{match}) {
				# less restrictive will match for sure on previous matches
				push @in, $t->{path};
			}

			else {
				# re-examine dirs that failed in the previous, more restrictive,
				# match
				$t->{match} = ($t->{path} =~ /$pattern/i);

				if ($t->{match}) {
					# no need to add childs, they will match too
					push @in, $t->{path};
				} else {
					# maybe some hope on childs?
					push @trees, values %{ $t->{content} };
				}
			}
		}

		else {
			$M = "N";
			# whole new search

			$t->{match} = ($t->{path} =~ /$pattern/i);

			if ($t->{match}) {
				push @in, $t->{path};
			} else {
				push @trees, values %{ $t->{content} };
			}
		}

		# reset child match flag. will be increased later if childs match
		$t->{cmatch} = 0;
	}

	for my $path (@in) {

		my $dir   = $TREE;
		my @parts = split('/', $path);

		while (defined (my $p = shift @parts)) {
			$dir->{cmatch} = 1;
			$dir = $dir->{content}{$p};
		} $dir->{cmatch} = 1;
	}
}



my $line_before = "";
my $line_after  = "";
my $results = flatten_tree($TREE);


initscr;

make_scr($results);

while (defined (my $char = $cmd_win->getch())) {

	my $need_repopulate = 0;

	# handle resizing
	if ($char eq KEY_RESIZE) {
		$cmd_win->move(0, 0);
		$cmd_win->clrtoeol();

		$cmd_win->delwin();
		$res_win->delwin();

		make_scr($results);
	}

	elsif ($char eq KEY_UP) {
	}

	elsif ($char eq KEY_DOWN) {
	}

	elsif ($char eq KEY_LEFT) {
		if (length $line_before) {
			$line_after  = substr($line_before, -1) . $line_after;
			$line_before = substr($line_before, 0, -1);
		}
	}

	elsif ($char eq KEY_RIGHT) {
		if (length $line_after) {
			$line_before = $line_before . substr($line_after, 0, 1);
			$line_after  = substr($line_after, 1);
		}
	}

	elsif ($char eq KEY_BACKSPACE || ord($char) == 127) { # backspace hack
		if (length $line_before) {
			my $char     = substr($line_before, -1);    # identify the removed char
			$line_before = substr($line_before, 0, -1); # update the line
			$need_repopulate = 1;
		}
	}

	elsif ($char eq KEY_DC) {  # del
		if (length $line_after) {
			my $char    = substr($line_after, 0, 1);
			$line_after = substr($line_after, 1);
			$need_repopulate = 1;
		}
	}

	elsif ($char eq "\n") {
		last;
	}

	elsif ($char eq "\x04") { # ^D
		last;
	}

	elsif ($char eq "\x15") { # ^U
		$line_before = "";
		$need_repopulate = 1;
	}

	elsif ($char eq "\x17") { # ^W
		$line_before =~ s/\S+\s*$//;
		$need_repopulate = 1;
	}

	elsif ($char eq "\x01") { # ^A
		$line_after  = $line_before . $line_after;
		$line_before = "";
	}

	elsif ($char eq "\x05") { # ^E
		$line_before = $line_before . $line_after;
		$line_after  = "";
	}

	else {
		$line_before .= $char;
		$need_repopulate = 1;
	}

	# refresh results list if necessary
	if ($need_repopulate) {
		my $fullpattern = $line_before . $line_after;
		filter_res($fullpattern);
		$results = flatten_tree($TREE);
		populate_result($results);
	}

	#use Data::Dumper;
	#$res_win->clear();
	#$res_win->move(0, 0);
	#$res_win->addstr(Dumper($results));
	#$res_win->addstr(Dumper($TREE));
	#$res_win->refresh();

	# print the current line
	$cmd_win->addstr(0, 0, "$M $prompt" . $line_before . $line_after);
	$cmd_win->clrtoeol();

	# set cursor position
	$cmd_win->move(0, 2 + length($prompt) + length($line_before));

	$cmd_win->refresh;
}

endwin;
