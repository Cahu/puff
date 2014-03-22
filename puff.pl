use strict;
use warnings;

use Curses;

my $cmd = "find . -maxdepth 10";
my $str = `$cmd` or die "'$cmd' returned an error";

my @list = sort grep { $_ !~ m@^(..|.)$@ } split("\n", $str);

my $win = Curses->new;
noecho();


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

	$win->move(prompt_pos);
	$win->clrtoeol();
	$win->addstr(prompt_pos, $prompt . $line_before . $line_after);
	$win->refresh;
}

endwin;
