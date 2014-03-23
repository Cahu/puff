use strict;
use warnings;

use Curses;

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
		match => 1,
		path  => ".",
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

		else {
			my $subdirs = $t->{content};
			push @trees, $subdirs->{$_} for (sort keys %$subdirs);
		}
	}

	while (defined (my $match = shift @matching)) {

		# add
		push @in, $match->{path};

		my $subdirs = $match->{content};
		# schedule subdirs, still sorted (have to apply reverse order here...)
		for my $subdir (sort { $b cmp $a } keys %$subdirs) {
			unshift @matching, $subdirs->{$subdir};
		}
	}

	return \@in;
}


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


sub filter_res {
	my ($search) = @_;

	my $pattern = "";
	$pattern   .= "[^\Q$_\E]*\Q$_\E" for (split('', $search));

	my @trees = ($TREE);

	while (defined (my $t = shift @trees)) {
		$t->{match} = ($t->{path} =~ /$pattern/i);

		if ($t->{match}) {
			# this dir matches => all subdirs match
			next;
		} else {
			# add subdirs for checking
			push @trees, values %{ $t->{content} };
		}
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

	# print the current line
	$cmd_win->addstr(0, 0, $prompt . $line_before . $line_after);
	$cmd_win->clrtoeol();

	# set cursor position
	$cmd_win->move(0, length($prompt) + length($line_before));

	$cmd_win->refresh;
}

endwin;
