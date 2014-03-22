use strict;
use warnings;

use Curses;

my $cmd = "find . -maxdepth 10";
my $str = `$cmd` or die "'$cmd' returned an error";

my @list = sort grep { $_ !~ m@^(..|.)$@ } split("\n", $str);

my $win = Curses->new;

# Don't print typed keys, we will handle it ourself
noecho;

# Allow mapping of keys to constants (such as KEY_DOWN, etc)
$win->keypad(1);

# Screen size
my ($row, $col);
$win->scrollok(1);
$win->getmaxyx($row, $col);


# Prompt
my $prompt = ">>> ";

sub prompt_pos {
	($row-1, 0);
}


for (@list) {
	$win->addstr("$_\n");
}

$win->addstr(prompt_pos(), $prompt);

my $line_before = "";
my $line_after  = "";
while (defined (my $char = $win->getch())) {

	# handle resizing
	if ($char eq KEY_RESIZE) {
		$win->move(prompt_pos());
		$win->clrtoeol();

		$win->getmaxyx($row, $col);
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
	$win->move(prompt_pos);
	$win->clrtoeol();
	$win->addstr(prompt_pos, $prompt . $line_before . $line_after);

	# set cursor position
	my ($row, $col) = prompt_pos();
	$win->move($row, $col + length($prompt) + length($line_before));

	$win->refresh;
}

endwin;
