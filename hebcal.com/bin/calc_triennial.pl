#!/usr/local/bin/perl -w -I/pub/p/e/perl/lib/site_perl:/home/mradwin/local/lib/perl5:/home/mradwin/local/lib/perl5/site_perl

# $Id$

use Hebcal;
use Getopt::Std;
use XML::Simple;
use Data::Dumper;
use strict;

$0 =~ s,.*/,,;  # basename

my($usage) = "usage: $0 [-h] [-H <year>] aliyah.xml output-dir
    -h        Display usage information.
    -H <year> Start with hebrew year <year> (default this year)
";

my(%opts);
&getopts('hH:c:', \%opts) || die "$usage\n";
$opts{'h'} && die "$usage\n";
(@ARGV == 2) || die "$usage";

my($this_year) = (localtime)[5];
$this_year += 1900;

my($rcsrev) = '$Revision$'; #'
$rcsrev =~ s/\s*\$//g;

my($infile) = shift;
my($outdir) = shift;

if (! -d $outdir) {
    die "$outdir: $!\n";
}

my($mtime) = (stat($infile))[9];
my($hhmts) = "Last modified:\n" . localtime($mtime);

my(@combined) = ('Vayakhel-Pekudei',
		 'Tazria-Metzora',
		 'Achrei Mot-Kedoshim',
		 'Behar-Bechukotai',
		 'Chukat-Balak',
		 'Matot-Masei',
		 'Nitzavim-Vayeilech');

my(@all_inorder) =
    ("Bereshit",
     "Noach",
     "Lech-Lecha",
     "Vayera",
     "Chayei Sara",
     "Toldot",
     "Vayetzei",
     "Vayishlach",
     "Vayeshev",
     "Miketz",
     "Vayigash",
     "Vayechi",
     "Shemot",
     "Vaera",
     "Bo",
     "Beshalach",
     "Yitro",
     "Mishpatim",
     "Terumah",
     "Tetzaveh",
     "Ki Tisa",
     "Vayakhel",
     "Pekudei",
     "Vayikra",
     "Tzav",
     "Shmini",
     "Tazria",
     "Metzora",
     "Achrei Mot",
     "Kedoshim",
     "Emor",
     "Behar",
     "Bechukotai",
     "Bamidbar",
     "Nasso",
     "Beha'alotcha",
     "Sh'lach",
     "Korach",
     "Chukat",
     "Balak",
     "Pinchas",
     "Matot",
     "Masei",
     "Devarim",
     "Vaetchanan",
     "Eikev",
     "Re'eh",
     "Shoftim",
     "Ki Teitzei",
     "Ki Tavo",
     "Nitzavim",
     "Vayeilech",
     "Ha'Azinu",
     "Vezot Haberakhah");

my(%combined);
foreach (@combined) {
    my($p1,$p2) = split(/-/);
    $combined{$p1} = $_;
    $combined{$p2} = $_;
}

my($hebrew_year);
if ($opts{'H'}) {
    $hebrew_year = $opts{'H'};
} else {
    $hebrew_year = `./hebcal -t`;
    chomp($hebrew_year);
    $hebrew_year =~ s/^.+, (\d{4})/$1/;
}

# year I in triennial cycle was 5756
my $year_num = (($hebrew_year - 5756) % 3) + 1;
my $start_year = $hebrew_year - ($year_num - 1);
print "$hebrew_year is year $year_num.  cycle starts at year $start_year\n";

my(@events);
foreach my $cycle (0 .. 3)
{
    my($yr) = $start_year + $cycle;
    my(@ev) = &Hebcal::invoke_hebcal("./hebcal -s -h -x -H $yr", '');
    push(@events, @ev);
}

my $bereshit_idx;
for (my $i = 0; $i < @events; $i++)
{
    if ($events[$i]->[$Hebcal::EVT_IDX_SUBJ] eq 'Parashat Bereshit')
    {
	$bereshit_idx = $i;
	last;
    }
}

die "can't find Bereshit for Year I" unless defined $bereshit_idx;

my(%pattern);
for (my $i = $bereshit_idx; $i < @events; $i++)
{
    next unless ($events[$i]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Parashat (.+)/);
    my $subj = $1;

#    print "idx=$i, subj=$subj\n";

    if ($subj =~ /^([^-]+)-(.+)$/ &&
	defined $combined{$1} && defined $combined{$2})
    {
	push(@{$pattern{$1}}, 'T');
	push(@{$pattern{$2}}, 'T');
    }
    else
    {
	push(@{$pattern{$subj}}, 'S');
    }
}

my $parshiot = XMLin($infile);
my %cycle_option;
&calc_variation_options($parshiot, \%cycle_option);
my %triennial_aliyot;
&read_aliyot_metadata($parshiot, \%triennial_aliyot);

my %readings;
my $year = 1;
for (my $i = $bereshit_idx; $i < @events; $i++)
{
    if ($events[$i]->[$Hebcal::EVT_IDX_SUBJ] eq 'Parashat Bereshit' &&
	$i != $bereshit_idx)
    {
	$year++;
	last if ($year == 4);
    }

    next unless ($events[$i]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Parashat (.+)/);
    my $h = $1;

    my $month = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;
    my $stime = sprintf("%02d %s %04d",
			$events[$i]->[$Hebcal::EVT_IDX_MDAY],
			$Hebcal::MoY_long{$month},
			$events[$i]->[$Hebcal::EVT_IDX_YEAR]);

    if (defined $combined{$h})
    {
	my $variation = $cycle_option{$h} . "." . $year;
	my $a = $triennial_aliyot{$h}->{$variation};
	die unless defined $a;
	$readings{$h}->[$year] = [$a, $stime, $h];
    }
    elsif (defined $triennial_aliyot{$h}->{$year})
    {
	my $a = $triennial_aliyot{$h}->{$year};
	die unless defined $a;

	$readings{$h}->[$year] = [$a, $stime, $h];

	if ($h =~ /^([^-]+)-(.+)$/ &&
	    defined $combined{$1} && defined $combined{$2})
	{
	    $readings{$1}->[$year] = [$a, $stime, $h];
	    $readings{$2}->[$year] = [$a, $stime, $h];
	}
    }
    elsif (defined $triennial_aliyot{$h}->{"Y.$year"})
    {
	my $a = $triennial_aliyot{$h}->{"Y.$year"};
	die unless defined $a;

	$readings{$h}->[$year] = [$a, $stime, $h];

	if ($h =~ /^([^-]+)-(.+)$/ &&
	    defined $combined{$1} && defined $combined{$2})
	{
	    $readings{$1}->[$year] = [$a, $stime, $h];
	    $readings{$2}->[$year] = [$a, $stime, $h];
	}
    }
    else
    {
	die "can't find aliyot for $h, year $year";
    }
}

my(%prev,%next,$h2);
foreach my $h (@all_inorder)
{
    $prev{$h} = $h2;
    $h2 = $h;
}

$h2 = undef;
foreach my $h (reverse @all_inorder)
{
    $next{$h} = $h2;
    $h2 = $h;
}

foreach my $h (keys %readings)
{
    &write_sedra_page($h,$prev{$h},$next{$h},$readings{$h});
}
{
    my $h = "Vezot Haberakhah";
    &write_sedra_page($h,$prev{$h},$next{$h},$readings{$h});
}

exit(0);

sub calc_variation_options
{
    my($parshiot,$option) = @_;

    foreach my $parsha (@combined)
    {
	my($p1,$p2) = split(/-/, $parsha);
	my $pat = '';
	foreach my $yr (0 .. 2) {
	    $pat .= $pattern{$p1}->[$yr];
	}

	if ($pat eq 'TTT')
	{
	    $option->{$parsha} = 'all-together';
	}
	else
	{
	    my $vars =
		$parshiot->{'parsha'}->{$parsha}->{'variations'}->{'cycle'};
	    foreach my $cycle (@{$vars}) {
		if ($cycle->{'pattern'} eq $pat) {
		    $option->{$parsha} = $cycle->{'option'};
		    $option->{$p1} = $cycle->{'option'};
		    $option->{$p2} = $cycle->{'option'};
		    last;
		}
	    }

	    die "can't find option for $parsha (pat == $pat)"
		unless defined $option->{$parsha};
	}

	print "$parsha: $pat ($option->{$parsha})\n";
    }

    1;
}

sub read_aliyot_metadata
{
    my($parshiot,$aliyot) = @_;

    # build a lookup table so we don't have to follow num/variation/sameas
    foreach my $parsha (keys %{$parshiot->{'parsha'}}) {
	my $val = $parshiot->{'parsha'}->{$parsha};
	my $yrs = $val->{'triennial'}->{'year'};
	
	foreach my $y (@{$yrs}) {
	    if (defined $y->{'num'}) {
		$aliyot->{$parsha}->{$y->{'num'}} = $y->{'aliyah'};
	    } elsif (defined $y->{'variation'}) {
		if (! defined $y->{'sameas'}) {
		    $aliyot->{$parsha}->{$y->{'variation'}} = $y->{'aliyah'};
		}
	    } else {
		warn "strange data for Parashat $parsha";
		die Dumper($y);
	    }
	}

	# second pass for sameas
	foreach my $y (@{$yrs}) {
	    if (defined $y->{'variation'} && defined $y->{'sameas'}) {
		my $sameas = $y->{'sameas'};
		die "Bad sameas=$sameas for Parashat $parsha"
		    unless defined $aliyot->{$parsha}->{$sameas};
		$aliyot->{$parsha}->{$y->{'variation'}} =
		    $aliyot->{$parsha}->{$sameas};
	    }
	}
    }

    1;
}

sub write_sedra_page {
    my($h,$prev,$next,$triennial) = @_;

    my($hebrew,$torah,$haftarah,$haftarah_seph,
       $torah_href,$haftarah_href,$drash_href) = &get_parsha_info($h);

    my $seph = '';
    my $ashk = '';

    if (defined($haftarah_seph) && ($haftarah_seph ne $haftarah))
    {
	$seph = "\n<br>Haftarah for Sephardim: $haftarah_seph";
	$ashk = " for Ashkenazim";
    }

    my($anchor) = lc($h);
    $anchor =~ s/[^\w]//g;

    my($prev_link) = '';
    my($prev_anchor);
    if ($prev)
    {
	$prev_anchor = lc($prev);
	$prev_anchor =~ s/[^\w]//g;
	$prev_anchor .= ".html";

	my $title = "Previous Parsha";
	$prev_link = qq{<a name="prev" href="$prev_anchor"\n} .
	    qq{title="$title">&lt;&lt; $prev</a>};
    }

    my($next_link) = '';
    my($next_anchor);
    if ($next)
    {
	$next_anchor = lc($next);
	$next_anchor =~ s/[^\w]//g;
	$next_anchor .= ".html";

	my $title = "Next Parsha";
	$next_link = qq{<a name="next" href="$next_anchor"\n} .
	    qq{title="$title">$next &gt;&gt;</a>};
    }

    open(OUT2, ">$outdir/$anchor.html") || die "$outdir/$anchor.html: $!\n";

    print OUT2 <<EOHTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html><head><title>Torah Readings: $h</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<base href="http://www.hebcal.com/sedrot/$anchor.html" target="_top">
<link rel="stylesheet" href="/style.css" type="text/css">
EOHTML
;

    print OUT2 qq{<link rel="prev" href="$prev_anchor" title="Parashat $prev">\n}
    	if $prev_anchor;
    print OUT2 qq{<link rel="next" href="$next_anchor" title="Parashat $next">\n}
    	if $next_anchor;

    my @tri_date;
    if ($h eq 'Vezot Haberakhah')
    {
	$tri_date[1] = $tri_date[2] = $tri_date[3] =
	    "To be read on Simchat Torah.<br>\nSee holiday readings.";
    }
    else
    {
	foreach (1 .. 3)
	{
	    $tri_date[$_] = (defined $triennial->[$_]) ?
		$triennial->[$_]->[1] : '(read separately)';
	}
    }

    print OUT2 <<EOHTML;
</head>
<body>
<table width="100%" class="navbar">
<tr><td><small>
<strong><a href="/">hebcal.com</a></strong> <tt>-&gt;</tt>
<a href="/sedrot/">Torah Readings</a> <tt>-&gt;</tt>
$h
</small></td>
<td align="right"><small><a
href="/search/">Search</a></small>
</td></tr></table>

<br>
<table width="100%">
<tr>
<td><h1>Parashat $h</h1></td>
<td><h1 dir="rtl" class="hebrew" name="hebrew"
lang="he">$hebrew</h1></td>
</tr>
</table>
<h3><a name="torah">Torah Portion:</a>
<a href="$torah_href"\ntitle="Translation from JPS Tanakh">$torah</a></h3>
&nbsp;
<table border="1" cellpadding="5">
<tr>
<td align="center" width="25%"><b>Full Kriyah<b></td>
<td align="center" width="25%"><b>Triennial Year I</b>
<br><small>$tri_date[1]</small>
</td>
<td align="center" width="25%"><b>Triennial Year II</b>
<br><small>$tri_date[2]</small>
</td>
<td align="center" width="25%"><b>Triennial Year III</b>
<br><small>$tri_date[3]</small>
</td>
</tr>
<tr>
<td>
<dl compact>
EOHTML
;

    my $aliyot = $parshiot->{'parsha'}->{$h}->{'fullkriyah'}->{'aliyah'};
    my %fk;
    foreach my $a (@{$aliyot})
    {
	my($c1,$v1) = ($a->{'begin'} =~ /^(\d+):(\d+)$/);
	my($c2,$v2) = ($a->{'end'}   =~ /^(\d+):(\d+)$/);
	my($info);
	if ($c1 == $c2) {
	    $info = "$c1:$v1-$v2";
	} else {
	    $info = "$c1:$v1-$c2:$v2";
	}

	if ($a->{'numverses'}) {
	    $info .= "\n<span class=\"tiny\">(" .
		$a->{'numverses'} . " p'sukim)</span>";
	}

	$fk{$a->{'num'}} = $info;
    }

    foreach (1 .. 7, 'M')
    {
	my($info) = $fk{$_};
	next if (!defined $info && $_ eq 'M');
	die "no fk $_ defined for $h" unless defined $info;
	my($label) = ($_ eq 'M') ? 'maf' : $_;
	print OUT2 qq{<dt><a name="fk-$label">$label:</a>\n}, 
		qq{<dd>$info\n};
    }

    print OUT2 "</dl>\n</td>\n";

    foreach my $yr (1 .. 3)
    {
	print OUT2 "<td>\n";

	if ($h eq 'Vezot Haberakhah')
	{
	    print OUT2 "&nbsp;</td>\n";
	    next;
	}
	elsif (! defined $triennial->[$yr])
	{
	    my($p1,$p2) = split(/-/, $h);

	    print OUT2 "Read separately.  See:\n<ul>\n";

	    my($anchor) = lc($p1);
	    $anchor =~ s/[^\w]//g;
	    print OUT2 "<li><a href=\"$anchor.html\">$p1</a>\n";

	    $anchor = lc($p2);
	    $anchor =~ s/[^\w]//g;
	    print OUT2 "<li><a href=\"$anchor.html\">$p2</a>\n";
	    print OUT2 "</ul>\n";

	    print OUT2 "</td>\n";
	    next;
	}
	elsif ($triennial->[$yr]->[2] ne $h)
	{
	    my($h_combined) = $triennial->[$yr]->[2];
	    my($p1,$p2) = split(/-/, $h_combined);

	    my($other) = ($p1 eq $h) ? $p2 : $p1;

	    print OUT2 "Read together with<br>\nParashat $other.<br>\n";

	    my($anchor) = lc($h_combined);
	    $anchor =~ s/[^\w]//g;
	    print OUT2 "See <a href=\"$anchor.html\">$h_combined</a>\n";

	    print OUT2 "</td>\n";
	    next;
	}

	my %tri;
	die "no aliyot array for $h (year $yr)"
	    unless defined $triennial->[$yr]->[0];


	foreach my $a (@{$triennial->[$yr]->[0]})
	{
	    my($c1,$v1) = ($a->{'begin'} =~ /^(\d+):(\d+)$/);
	    my($c2,$v2) = ($a->{'end'}   =~ /^(\d+):(\d+)$/);
	    my($info);
	    if ($c1 == $c2) {
		$info = "$c1:$v1-$v2";
	    } else {
		$info = "$c1:$v1-$c2:$v2";
	    }

	    $tri{$a->{'num'}} = $info;
	}

	print OUT2 "<dl compact>\n";
	foreach (1 .. 7, 'M')
	{
	    my($info) = $tri{$_};
	    next if (!defined $info && $_ eq 'M');
	    die "no aliyah $_ defined for $h" unless defined $info;
	    my($label) = ($_ eq 'M') ? 'maf' : $_;
	    print OUT2 qq{<dt><a name="tri-$yr-$label">$label:</a>\n}, 
	    qq{<dd>$info\n};
	}
	print OUT2 "</dl>\n</td>\n";
    }

    print OUT2 <<EOHTML;
</tr>
</table>
<h3><a name="haftarah">Haftarah$ashk:</a>
<a href="$haftarah_href"
title="Translation from JPS Tanakh">$haftarah</a>$seph</h3>
EOHTML
;

    my $c_year = '';
    if ($drash_href =~ m,/(\d{4})/,) {
	$c_year = " for $1";
    }

    print OUT2 
	qq{<h3><a name="drash"\nhref="$drash_href">Commentary$c_year</a></h3>\n}
    if $drash_href;

    if ($prev_link || $next_link)
    {
	print OUT2 <<EOHTML;
<p>
<table width="100%">
<tr>
<td align="left" width="33%">
$prev_link
</td>
<td align="center" width="33%">
Reference: <em><a
href="http://www.amazon.com/exec/obidos/ASIN/0827607121/hebcal-20">Etz
Hayim: Torah and Commentary</a></em>,
David L. Lieber et. al., Jewish Publication Society, 2001.
</td>
<td align="right" width="33%">
$next_link
</td>
</tr>
</table>
EOHTML
;
    }

    print OUT2 <<EOHTML;
<p>
<hr noshade size="1">
<span class="tiny">Copyright
&copy; $this_year Michael J. Radwin. All rights reserved.
<a href="/privacy/">Privacy Policy</a> -
<a href="/help/">Help</a> -
<a href="/contact/">Contact</a>
<br>
$hhmts
($rcsrev)
</span>
</body></html>
EOHTML
;

}

sub get_parsha_info
{
    my($h) = @_;

    my $parashat = "\xD7\xA4\xD7\xA8\xD7\xA9\xD7\xAA";  # UTF-8 for "parashat"

    my($hebrew);
    my($torah,$haftarah,$haftarah_seph);
    my($torah_href,$haftarah_href,$drash_href);
    if ($h =~ /^([^-]+)-(.+)$/ &&
	defined $combined{$1} && defined $combined{$2})
    {
	my($p1,$p2) = ($1,$2);

	# UTF-8 for HEBREW PUNCTUATION MAQAF (U+05BE)
	$hebrew = sprintf("%s %s%s%s",
			  $parashat,
			  $parshiot->{'parsha'}->{$p1}->{'hebrew'},
			  "\xD6\xBE", 
			  $parshiot->{'parsha'}->{$p2}->{'hebrew'});

	my $torah_end = $parshiot->{'parsha'}->{$p2}->{'verse'};
	$torah_end =~ s/^.+\s+(\d+:\d+)\s*$/$1/;

	$torah = $parshiot->{'parsha'}->{$p1}->{'verse'};
	$torah =~ s/\s+\d+:\d+\s*$/ $torah_end/;

	# on doubled parshiot, read only the second Haftarah
	$haftarah = $parshiot->{'parsha'}->{$p2}->{'haftara'};
	$haftarah_seph = $parshiot->{'parsha'}->{$p2}->{'sephardic'};

	my $links = $parshiot->{'parsha'}->{$p1}->{'links'}->{'link'};
	foreach my $l (@{$links})
	{
	    if ($l->{'rel'} eq 'drash')
	    {
		$drash_href = $l->{'href'};
	    }
	    elsif ($l->{'rel'} eq 'torah')
	    {
		$torah_href = $l->{'href'};
	    }
	}

	$haftarah_href = $torah_href;
	$haftarah_href =~ s/.shtml$/_haft.shtml/;
    }
    else
    {
	$hebrew = sprintf("%s %s",
			  $parashat,
			  $parshiot->{'parsha'}->{$h}->{'hebrew'});
	$torah = $parshiot->{'parsha'}->{$h}->{'verse'};
	$haftarah = $parshiot->{'parsha'}->{$h}->{'haftara'};
	$haftarah_seph = $parshiot->{'parsha'}->{$h}->{'sephardic'};

	my $links = $parshiot->{'parsha'}->{$h}->{'links'}->{'link'};
	foreach my $l (@{$links})
	{
	    if ($l->{'rel'} eq 'drash')
	    {
		$drash_href = $l->{'href'};
	    }
	    elsif ($l->{'rel'} eq 'torah')
	    {
		$torah_href = $l->{'href'};
	    }
	}

	$haftarah_href = $torah_href;
	$haftarah_href =~ s/.shtml$/_haft.shtml/;
    }

    ($hebrew,$torah,$haftarah,$haftarah_seph,
     $torah_href,$haftarah_href,$drash_href);
}
