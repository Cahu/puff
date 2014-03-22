use strict;
use warnings;

use Curses;

my $prompt = ">>> ";
my $cmd = "find -L .";
my $str = `$cmd` or die "'$cmd' returned an error";

my @list = sort grep { $_ !~ m@^(..|.)$@ } split("\n", $str);

# Screen size
my ($row, $col);

my $res_win;
my $cmd_win;
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
	$res_win->addstr(join("\n", @{$_[0]}));
	$res_win->refresh();
}


sub filter_res {
	my ($search, $list) = @_;

	my $pattern = "";
	$pattern .= "[^$_]*$_" for (split('', $search));

	my (@in, @out) = (), ();
	for (@$list) {
		if (/$pattern/i) {
			push @in, $_;
		} else {
			push @out, $_;
		}
	}

	return (\@in, \@out);
}


sub reinsert {
	my ($search, $reinsert) = @_;

	my %out;
	my $keep = [ @$reinsert ];

	for my $i (0 .. (length $search) - 1) {
		my $char = substr($search, $i, 1   );
		my $filt = substr($search,  0, $i+1);

		($keep, my $out) = filter_res($filt, $keep);

		push @{ $out{$char} }, @$out;
	}

	return ($keep, \%out);
}


sub merge_sort {
	my ($l1, $l2) = @_;

	my @res = sort @$l1, @$l2;

	#my ($i, $j, @res) = (0, 0, ());
	#my ($len1, $len2) = ($#{ $l1 }, $#{ $l2 });

	#while ($i <= $len1 && $j <= $len2) {

	#	next unless (defined $l1->[$i] && defined $l2->[$j]);

	#	if (($l1->[$i] cmp $l2->[$j]) > 0) {
	#		push @res, $l2->[$j];
	#		$j++;
	#	} else {
	#		push @res, $l1->[$i];
	#		$i++;
	#	}
	#}

	## add remaining elements
	#push(@res, $l1->[$i .. $len1]) if ($i <= $len1);
	#push(@res, $l2->[$j .. $len2]) if ($j <= $len2);

	return \@res;
}



initscr;

make_scr(\@list);

my $line_before = "";
my $line_after  = "";
my $results = \@list;

my %filtered_out;

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
			my $char     = substr($line_before, -1);
			$line_before = substr($line_before, 0, -1);

			my $reinsert = $filtered_out{$char};
			$filtered_out{$char} = [];

			if ($reinsert) {
				my ($keep, $out) = reinsert($line_before . $line_after, $reinsert);

				$results = merge_sort($results, $keep);

				while (my ($c, $l) = each %$out) {
					push @{ $filtered_out{$c} }, @$l;
				}

				$need_repopulate = 1;
			}
		}
	}

	elsif ($char eq KEY_DC) {  # del
		if (length $line_after) {
			my $char    = substr($line_after, 0, 1);
			$line_after = substr($line_after, 1);

			my $reinsert = $filtered_out{$char};
			$filtered_out{$char} = [];

			if ($reinsert) {
				my ($keep, $out) = reinsert($line_before . $line_after, $reinsert);

				$results = merge_sort($results, $keep);

				while (my ($c, $l) = each %$out) {
					push @{ $filtered_out{$c} }, @$l;
				}

				$need_repopulate = 1;
			}
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
	}

	elsif ($char eq "\x17") { # ^W
		$line_before =~ s/\S+\s*$//;
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

		my $fullpattern     = $line_before . $line_after;
		($results, my $out) = filter_res($fullpattern, $results);

		push @{ $filtered_out{$char} }, @$out;

		$need_repopulate = 1;
	}

	# refresh results list if necessary
	populate_result($results) if ($need_repopulate);

	# print the current line
	$cmd_win->addstr(0, 0, $prompt . $line_before . $line_after);
	$cmd_win->clrtoeol();

	# set cursor position
	$cmd_win->move(0, length($prompt) + length($line_before));

	$cmd_win->refresh;
}

endwin;
