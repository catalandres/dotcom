#!/usr/local/bin/perl -w

use lib "/pub/m/r/mradwin/private/lib/perl5/site_perl";
use Hebcal;
use POSIX;
use strict;

my $outfile = "/pub/m/r/mradwin/hebcal.com/current.inc";
my $line = `/pub/m/r/mradwin/hebcal.com/bin/hebcal -S -t -x -h | grep Parashat`;
chomp($line);
my $wrote_parsha = 0;
if ($line =~ m,^\d+/\d+/\d+\s+(.+)\s*$,) {
    my $parsha = $1;
    my $href = &Hebcal::get_holiday_anchor($parsha);
    if ($href) {
	my($now) = time();
	my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	    localtime($now);
	my($saturday) = ($wday == 6) ?
	    $now + (60 * 60 * 24) : $now + ((6 - $wday) * 60 * 60 * 24);
	my($stime) = strftime("%d %B %Y", localtime($saturday));

	open(OUT,">$outfile") || die;
	$parsha =~ s/ /&nbsp;/g;
	print OUT "<br><br><span class=\"sm-grey\">&gt;</span>&nbsp;<b><a\n";
	print OUT "href=\"$href\">$parsha</a></b><br>$stime";
	close(OUT);
	$wrote_parsha = 1;
    }
}
unless ($wrote_parsha) {
    open(OUT,">$outfile") || die;
    close(OUT);
}

$outfile = '/pub/m/r/mradwin/hebcal.com/today.inc';
open(OUT,">$outfile") || die;
print OUT `/pub/m/r/mradwin/hebcal.com/bin/hebcal -T -x -h | grep -v Omer`;
close(OUT);

$outfile = '/pub/m/r/mradwin/hebcal.com/holiday.inc';
$line = `/pub/m/r/mradwin/hebcal.com/bin/hebcal -t | grep -v ' of '`;
chomp($line);
my $wrote_holiday = 0;
if ($line =~ m,^\d+/\d+/\d+\s+(.+)\s*$,) {
    my $holiday = $1;
    my $href = &Hebcal::get_holiday_anchor($holiday);
    if ($href) {
	my($stime) = strftime("%d %B %Y", localtime(time()));
	open(OUT,">$outfile") || die;
	$holiday =~ s/ /&nbsp;/g;
	print OUT "<br><br><span class=\"sm-grey\">&gt;</span>&nbsp;<b><a\n";
	print OUT "href=\"$href\">$holiday</a></b><br>$stime\n";
	close(OUT);
	$wrote_holiday = 1;
    }
}
unless ($wrote_holiday) {
    open(OUT,">$outfile") || die;
    close(OUT);
}


