use strict;
use warnings;

use Curses;

my $prompt = ">>> ";
my $cmd = "find . -maxdepth 10";
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
	$res_win->addstr(join("\n", @list));
	$res_win->refresh();

	# prepare prompt
	$cmd_win->addstr(0, 0, $prompt);
	$cmd_win->refresh();

	# Don't print typed keys, we will handle it ourself
	noecho;
}

initscr;

make_scr;

my $line_before = "";
my $line_after  = "";
while (defined (my $char = $cmd_win->getch())) {

	# handle resizing
	if ($char eq KEY_RESIZE) {
		$cmd_win->move(0, 0);
		$cmd_win->clrtoeol();

		$cmd_win->delwin();
		$res_win->delwin();

		make_scr;
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

	elsif ($char eq KEY_BACKSPACE) {
		if (length $line_before) {
			$line_before = substr($line_before, 0, -1);
		}
	}

	elsif ($char eq KEY_DC) {  # del
		if (length $line_after) {
			$line_after = substr($line_after, 1);
		}
	}

	elsif ($char eq "\n") {
		$line_before = "";
		$line_after  = "";
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

	else {
		$line_before .= $char;
	}

	# print the current line
	$cmd_win->addstr(0, 0, $prompt . $line_before . $line_after);
	$cmd_win->clrtoeol();

	# set cursor position
	$cmd_win->move(0, length($prompt) + length($line_before));

	$cmd_win->refresh;
}

endwin;
