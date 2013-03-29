#!/usr/local/bin/perl -w

########################################################################
#
# $Id$
#
# Copyright (c) 2013  Michael J. Radwin.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following
# conditions are met:
#
#  * Redistributions of source code must retain the above
#    copyright notice, this list of conditions and the following
#    disclaimer.
#
#  * Redistributions in binary form must reproduce the above
#    copyright notice, this list of conditions and the following
#    disclaimer in the documentation and/or other materials
#    provided with the distribution.
#
#  * Neither the name of Hebcal.com nor the names of its
#    contributors may be used to endorse or promote products
#    derived from this software without specific prior written
#    permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
########################################################################

require 5.008_001;

use lib "/home/hebcal/local/share/perl";
use lib "/home/hebcal/local/share/perl/site_perl";

use strict;
use open ":utf8";
use Hebcal ();
use Date::Calc ();
use Time::Local ();
use POSIX qw(strftime);

my $HOSTNAME = "www.hebcal.com";

my $dbh = DBI->connect("dbi:SQLite:dbname=$Hebcal::LUACH_SQLITE_FILE", "", "")
    or die $DBI::errstr;
my $sth = $dbh->prepare("SELECT num,reading FROM leyning WHERE dt = ?");

my($syear,$smonth,$sday) = Hebcal::upcoming_dow(6); # saturday

my @events = Hebcal::invoke_hebcal("$Hebcal::HEBCAL_BIN -s -h -x $syear", "", 0, $smonth);
for (my $i = 0; $i < @events; $i++)
{
    if ($events[$i]->[$Hebcal::EVT_IDX_MDAY] == $sday)
    {
	my $parasha = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my $href = Hebcal::get_holiday_anchor($parasha,undef,undef);
	if ($href)
	{
	    my $stime = sprintf("%02d %s %d",
				$sday, Date::Calc::Month_to_Text($smonth), $syear);

	    my $pubDate = strftime("%a, %d %b %Y %H:%M:%S GMT",
				   gmtime(time()));

	    my $dow = $Hebcal::DoW[Hebcal::get_dow($syear, $smonth, $sday)];
	    my $parasha_pubDate = sprintf("%s, %02d %s %d 12:00:00 GMT",
					 $dow,
					 $sday,
					 $Hebcal::MoY_short[$smonth - 1],
					 $syear);
	    my $dt = sprintf("%d%02d%02d", $syear, $smonth, $sday);
	    open(RSS,">$Hebcal::WEBDIR/sedrot/index.xml") || die;
	    my $link = "http://$HOSTNAME$href?tag=rss";
	    my $memo = Hebcal::torah_calendar_memo($dbh, $sth, $syear, $smonth, $sday);
	    $memo =~ s/\\n/<\/p>\n<p>/g;
	    $memo = "<![CDATA[<p>" . $memo . "</p>]]>";
	    print RSS qq{<?xml version="1.0" ?>
<rss version="2.0">
<channel>
<title>Hebcal Parsahat ha-Shavua</title>
<link>http://$HOSTNAME/sedrot/</link>
<description>Torah reading of the week from Hebcal.com</description>
<language>en-us</language>
<copyright>Copyright (c) $syear Michael J. Radwin. All rights reserved.</copyright>
<lastBuildDate>$pubDate</lastBuildDate>
<item>
<title>$parasha - $stime</title>
<link>$link</link>
<description>$memo</description>
<pubDate>$parasha_pubDate</pubDate>
<guid isPermaLink="false">$link&amp;dt=$dt</guid>
</item>
</channel>
</rss>
};
	    close(RSS);
	}

	last;
    }
}

undef $sth;
undef $dbh;

my $hdate = `$Hebcal::HEBCAL_BIN -T -x -h | grep -v Omer`;
chomp($hdate);

if ($hdate =~ /^(\d+)\w+ of ([^,]+), (\d+)$/)
{
    my($hm,$hd,$hy) = ($2,$1,$3);
    my $hebrew = Hebcal::build_hebrew_date($hm,$hd,$hy);

    my $outfile = "$Hebcal::WEBDIR/etc/hdate-en.js";
    open(OUT,">$outfile") || die;
    print OUT "document.write(\"$hdate\");\n";
    close(OUT);

    $outfile = "$Hebcal::WEBDIR/etc/hdate-he.js";
    open(OUT,">$outfile") || die;
    print OUT "document.write(\"$hebrew\");\n";
    close(OUT);

    my $pubDate = strftime("%a, %d %b %Y %H:%M:%S GMT", gmtime(time()));

    my $hmonth = $hm;
    if ($hmonth eq "Adar I") {
	$hmonth = "Adar1";
    } elsif ($hmonth eq "Adar II") {
	$hmonth = "Adar2";
    } elsif ($hmonth eq "Adar") {
	$hmonth = "Adar1";
    }

    $hmonth =~ s/[^A-Za-z0-9]+//g;

    open(RSS,">$Hebcal::WEBDIR/etc/hdate-en.xml") || die;
    print RSS qq{<?xml version="1.0" ?>
<rss version="2.0">
<channel>
<title>Hebrew Date</title>
<link>http://$HOSTNAME/converter/</link>
<description>Today\'s Hebrew Date from Hebcal.com</description>
<language>en-us</language>
<copyright>Copyright (c) $syear Michael J. Radwin. All rights reserved.</copyright>
<lastBuildDate>$pubDate</lastBuildDate>
<item>
<title>$hdate</title>
<link>http://$HOSTNAME/converter/?hd=$hd&amp;hm=$hmonth&amp;hy=$hy&amp;h2g=1&amp;tag=rss</link>
<description>$hdate</description>
<pubDate>$pubDate</pubDate>
</item>
</channel>
</rss>
};
    close(RSS);

    open(RSS,">$Hebcal::WEBDIR/etc/hdate-he.xml") || die;
    print RSS qq{<?xml version="1.0" ?>
<rss version="2.0">
<channel>
<title>Hebrew Date</title>
<link>http://$HOSTNAME/converter/</link>
<description>Today\'s Hebrew Date from Hebcal.com</description>
<language>he</language>
<copyright>Copyright (c) $syear Michael J. Radwin. All rights reserved.</copyright>
<lastBuildDate>$pubDate</lastBuildDate>
<item>
<title>$hebrew</title>
<link>http://$HOSTNAME/converter/?hd=$hd&amp;hm=$hmonth&amp;hy=$hy&amp;h2g=1&amp;heb=on&amp;tag=rss</link>
<description>$hebrew</description>
<pubDate>$pubDate</pubDate>
</item>
</channel>
</rss>
};
    close(RSS);
}
