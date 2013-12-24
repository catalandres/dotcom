########################################################################
# Hebcal Interactive Jewish Calendar is a web site that lets you
# generate a list of Jewish holidays for any year. Candle lighting
# times are calculated from your latitude and longitude (which can
# be determined by your zip code or closest city).
#
# Copyright (c) 2013 Michael J. Radwin.
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

package Hebcal;

use strict;
use utf8;
use POSIX qw(strftime);
use lib "/home/hebcal/local/share/perl";
use lib "/home/hebcal/local/share/perl/site_perl";
use Date::Calc ();
use Time::Local ();		# needed for Hebcal::event_to_time
use URI::Escape;
use HebcalConst;
use Digest::MD5 ();
use Encode qw(encode_utf8 decode_utf8);
use Config::Tiny;
use HebcalGPL;

my $eval_use_DBI;
my $eval_use_DateTime;
my $eval_use_JSON;

if ($^V && $^V ge v5.8.1) {
    binmode(STDOUT, ":utf8");
}

########################################################################
# constants
########################################################################

our $WEBDIR = $ENV{"DOCUMENT_ROOT"} || "/home/hebcal/web/hebcal.com";
our $HEBCAL_BIN = "$WEBDIR/bin/hebcal";
our $LUACH_SQLITE_FILE = "$WEBDIR/hebcal/luach.sqlite3";
our $CONFIG_INI_PATH = "/home/hebcal/local/etc/hebcal-dot-com.ini";

my $ZIP_SQLITE_FILE = "$WEBDIR/hebcal/zips.sqlite3";
my $GEONAME_SQLITE_FILE = "$WEBDIR/hebcal/geonames.sqlite3";

my $CONFIG_INI;
my $HOSTNAME;
my $CACHE_DIR = $ENV{"DOCUMENT_ROOT"} || ($ENV{"HOME"} . "/tmp");
$CACHE_DIR .= "/cache/";

# boolean options
our @opts = qw(c o s i a d D);
our $havdalah_min = 50;

our @DoW = qw(Sun Mon Tue Wed Thu Fri Sat);
our @DoW_long = qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday);
our @MoY_short = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
our %MoY_long = (
	     'x' => '- Entire year -',
	     1   => 'January',
	     2   => 'February',
	     3   => 'March',
	     4   => 'April',
	     5   => 'May',
	     6   => 'June',
	     7   => 'July',
	     8   => 'August',
	     9   => 'September',
	     10  => 'October',
	     11  => 'November',
	     12  => 'December',
	     );

our %lang_names =
    (
     "s"  => "Sephardic transliterations",
     "sh" => "Sephardic translit. + Hebrew",
     "a"  => "Ashkenazis transliterations",
     "ah" => "Ashkenazis translit. + Hebrew",
     "h"  => "Hebrew only",
     );

our %CONTINENTS =
    (
     'AF' => 'Africa',
     'AS' => 'Asia',
     'EU' => 'Europe',
     'NA' => 'North America',
     'SA' => 'South America',
     'OC' => 'Oceania',
     'AN' => 'Antarctica',
    );

our %CITIES_OLD = (
'Ashdod' => 'IL-Ashdod',
'Atlanta' => 'US-Atlanta-GA',
'Austin' => 'US-Austin-TX',
'Baghdad' => 'IQ-Baghdad',
'Beer Sheva' => 'IL-Beer Sheva',
'Berlin' => 'DE-Berlin',
'Baltimore' => 'US-Baltimore-MD',
'Bogota' => 'CO-Bogota',
'Boston' => 'US-Boston-MA',
'Buenos Aires' => 'AR-Buenos Aires',
'Buffalo' => 'US-Buffalo-NY',
'Chicago' => 'US-Chicago-IL',
'Cincinnati' => 'US-Cincinnati-OH',
'Cleveland' => 'US-Cleveland-OH',
'Dallas' => 'US-Dallas-TX',
'Denver' => 'US-Denver-CO',
'Detroit' => 'US-Detroit-MI',
'Eilat' => 'IL-Eilat',
'Gibraltar' => 'GI-Gibraltar',
'Haifa' => 'IL-Haifa',
'Hawaii' => 'US-Honolulu-HI',
'Houston' => 'US-Houston-TX',
'Jerusalem' => 'IL-Jerusalem',
'Johannesburg' => 'ZA-Johannesburg',
'Kiev' => 'UA-Kiev',
'La Paz' => 'BO-La Paz',
'Livingston' => 'US-Livingston-NY',
'London' => 'GB-London',
'Los Angeles' => 'US-Los Angeles-CA',
'Miami' => 'US-Miami-FL',
'Melbourne' => 'AU-Melbourne',
'Mexico City' => 'MX-Mexico City',
'Montreal' => 'CA-Montreal',
'Moscow' => 'RU-Moscow',
'New York' => 'US-New York-NY',
'Omaha' => 'US-Omaha-NE',
'Ottawa' => 'CA-Ottawa',
'Panama City' => 'PA-Panama City',
'Paris' => 'FR-Paris',
'Petach Tikvah' => 'IL-Petach Tikvah',
'Philadelphia' => 'US-Philadelphia-PA',
'Phoenix' => 'US-Phoenix-AZ',
'Pittsburgh' => 'US-Pittsburgh-PA',
'Saint Louis' => 'US-Saint Louis-MO',
'Saint Petersburg' => 'RU-Saint Petersburg',
'San Francisco' => 'US-San Francisco-CA',
'Seattle' => 'US-Seattle-WA',
'Sydney' => 'AU-Sydney',
'Tel Aviv' => 'IL-Tel Aviv',
'Tiberias' => 'IL-Tiberias',
'Toronto' => 'CA-Toronto',
'Vancouver' => 'CA-Vancouver',
'White Plains' => 'US-White Plains-NY',
'Washington DC' => 'US-Washington-DC',
'IL-Bene Beraq' => 'IL-Bnei Brak',
);

# based on cities.txt and loaded into HebcalConst.pm
our %CITY_TZID = ();
our %CITY_COUNTRY = ();
our %CITY_LATLONG = ();
while(my($id,$info) = each(%HebcalConst::CITIES_NEW)) {
    my($country,$city,$latitude,$longitude,$tzName,$woeid) = @{$info};
    $CITY_TZID{$id} = $tzName;
    $CITY_COUNTRY{$id} = $country;
    $CITY_LATLONG{$id} = [$latitude,$longitude];
}

# translate from Askenazic transiliterations to Separdic
our %ashk2seph =
 (
  # parshiot translations
  "Bereshis"			=>	"Bereshit",
  "Toldos"			=>	"Toldot",
  "Shemos"			=>	"Shemot",
  "Yisro"			=>	"Yitro",
  "Ki Sisa"			=>	"Ki Tisa",
  "Sazria"			=>	"Tazria",
  "Achrei Mos"			=>	"Achrei Mot",
  "Bechukosai"			=>	"Bechukotai",
  "Beha'aloscha"		=>	"Beha'alotcha",
  "Chukas"			=>	"Chukat",
  "Matos"			=>	"Matot",
  "Vaeschanan"			=>	"Vaetchanan",
  "Ki Seitzei"			=>	"Ki Teitzei",
  "Ki Savo"			=>	"Ki Tavo",

  # fixed holiday translations
  "Erev Sukkos"			=>	"Erev Sukkot",
  "Sukkos I"			=>	"Sukkot I",
  "Sukkos II"			=>	"Sukkot II",
  "Sukkos III (CH''M)"		=>	"Sukkot III (CH''M)",
  "Sukkos IV (CH''M)"		=>	"Sukkot IV (CH''M)",
  "Sukkos V (CH''M)"		=>	"Sukkot V (CH''M)",
  "Sukkos VI (CH''M)"		=>	"Sukkot VI (CH''M)",
  "Sukkos VII (Hoshana Raba)"	=>	"Sukkot VII (Hoshana Raba)",
  "Shmini Atzeres"		=>	"Shmini Atzeret",
  "Simchas Torah"		=>	"Simchat Torah",
  "Erev Shavuos"		=>	"Erev Shavuot",
  "Shavuos I"			=>	"Shavuot I",
  "Shavuos II"			=>	"Shavuot II",

  # variable holidays
  "Ta'anis Esther"		=>	"Ta'anit Esther",
  "Purim Koson"			=>	"Purim Katan",
  "Purim Koton"			=>	"Purim Katan",
  "Ta'anis Bechoros"		=>	"Ta'anit Bechorot",

  # special shabbatot
  "Shabbas Shuvah"		=>	"Shabbat Shuva",
  "Shabbas Shekalim"		=>	"Shabbat Shekalim",
  "Shabbas Zachor"		=>	"Shabbat Zachor",
  "Shabbas Parah"		=>	"Shabbat Parah",
  "Shabbas HaChodesh"		=>	"Shabbat HaChodesh",
  "Shabbas HaGadol"		=>	"Shabbat HaGadol",
  "Shabbas Chazon"		=>	"Shabbat Chazon",
  "Shabbas Nachamu"		=>	"Shabbat Nachamu",
  "Shabbos Shuvah"		=>	"Shabbat Shuva",
  "Shabbos Shekalim"		=>	"Shabbat Shekalim",
  "Shabbos Zachor"		=>	"Shabbat Zachor",
  "Shabbos Parah"		=>	"Shabbat Parah",
  "Shabbos HaChodesh"		=>	"Shabbat HaChodesh",
  "Shabbos HaGadol"		=>	"Shabbat HaGadol",
  "Shabbos Chazon"		=>	"Shabbat Chazon",
  "Shabbos Nachamu"		=>	"Shabbat Nachamu",
  );


# @events is an array of arrays.  these are the indices into each
# event structure:

our $EVT_IDX_SUBJ = 0;		# title of event
our $EVT_IDX_UNTIMED = 1;		# 0 if all-day, non-zero if timed
our $EVT_IDX_MIN = 2;		# minutes, [0 .. 59]
our $EVT_IDX_HOUR = 3;		# hour of day, [0 .. 23]
our $EVT_IDX_MDAY = 4;		# day of month, [1 .. 31]
our $EVT_IDX_MON = 5;		# month of year, [0 .. 11]
our $EVT_IDX_YEAR = 6;		# year [1 .. 9999]
our $EVT_IDX_DUR = 7;		# duration in minutes
our $EVT_IDX_MEMO = 8;		# memo text
our $EVT_IDX_YOMTOV = 9;		# is the holiday Yom Tov?

my %num2heb =
(
 1	=> "\x{5D0}",
 2	=> "\x{5D1}",
 3	=> "\x{5D2}",
 4	=> "\x{5D3}",
 5	=> "\x{5D4}",
 6	=> "\x{5D5}",
 7	=> "\x{5D6}",
 8	=> "\x{5D7}",
 9	=> "\x{5D8}",
 10	=> "\x{5D9}",
 20	=> "\x{5DB}",
 30	=> "\x{5DC}",
 40	=> "\x{5DE}",
 50	=> "\x{5E0}",
 60	=> "\x{5E1}",
 70	=> "\x{5E2}",
 80	=> "\x{5E4}",
 90	=> "\x{5E6}",
 100	=> "\x{5E7}",
 200	=> "\x{5E8}",
 300	=> "\x{5E9}",
 400	=> "\x{5EA}",
);

my %monthnames =
    (
     "Nisan"	=> "\x{5E0}\x{5B4}\x{5D9}\x{5E1}\x{5B8}\x{5DF}",
     "Iyyar"	=> "\x{5D0}\x{5B4}\x{5D9}\x{5B8}\x{5D9}\x{5E8}",
     "Sivan"	=> "\x{5E1}\x{5B4}\x{5D9}\x{5D5}\x{5B8}\x{5DF}",
     "Tamuz"	=> "\x{5EA}\x{5BC}\x{5B8}\x{5DE}\x{5D5}\x{5BC}\x{5D6}",
     "Av"	=> "\x{5D0}\x{5B8}\x{5D1}",
     "Elul"	=> "\x{5D0}\x{5B1}\x{5DC}\x{5D5}\x{5BC}\x{5DC}",
     "Tishrei"	=> "\x{5EA}\x{5BC}\x{5B4}\x{5E9}\x{5C1}\x{5B0}\x{5E8}\x{5B5}\x{5D9}",
     "Cheshvan"	=> "\x{5D7}\x{5B6}\x{5E9}\x{5C1}\x{5B0}\x{5D5}\x{5B8}\x{5DF}",
     "Kislev"	=> "\x{5DB}\x{5BC}\x{5B4}\x{5E1}\x{5B0}\x{5DC}\x{5B5}\x{5D5}",
     "Tevet"	=> "\x{5D8}\x{5B5}\x{5D1}\x{5B5}\x{5EA}",
     "Sh'vat"	=> "\x{5E9}\x{5C1}\x{5B0}\x{5D1}\x{5B8}\x{5D8}",
     "Adar"	=> "\x{5D0}\x{5B7}\x{5D3}\x{5B8}\x{5E8}",
     "Adar I"	=> "\x{5D0}\x{5B7}\x{5D3}\x{5B8}\x{5E8} \x{5D0}\x{5F3}",
     "Adar II"	=> "\x{5D0}\x{5B7}\x{5D3}\x{5B8}\x{5E8} \x{5D1}\x{5F3}",
     );

my $URCHIN = qq{<script type="text/javascript">
(function(){if(document.getElementsByTagName){var b=document.getElementsByTagName("a");if(b&&b.length){for(var a=0;a<b.length;a++){if(b[a]&&b[a].className=="amzn"){if(b[a].id){b[a].onclick=function(){_gaq.push(["_trackEvent","outbound-amzn",this.id])}}}
if(b[a]&&b[a].className=="outbound"){b[a].onclick=function(){var c=this.href;if(c&&c.indexOf("http://")===0){var d=c.indexOf("/",7);if(d>7){_gaq.push(["_trackEvent","outbound-article",c.substring(7,d)])}}}}
if(b[a]&&b[a].className.indexOf("download")!=-1){if(b[a].id){b[a].onclick=function(){_gaq.push(["_trackEvent","download",this.id])}}}}}}})();
</script>
};

my $ZONE_TAB = "/usr/share/zoneinfo/zone.tab";
my @TIMEZONES;
my $TIMEZONE_LIST_INIT;

sub get_timezones {
    open(ZONE_TAB, $ZONE_TAB) || die "$ZONE_TAB: $!";
    my @zones;
    while(<ZONE_TAB>) {
	chomp;
	next if /^\#/;
	my($country,$latlong,$tz,$comments) = split(/\s+/, $_, 4);
	push(@zones, $tz);
    }
    close(ZONE_TAB);
    @TIMEZONES = sort @zones;
    unshift(@TIMEZONES, "UTC");
    $TIMEZONE_LIST_INIT = 1;
    \@TIMEZONES;
}

########################################################################
# invoke hebcal unix app and create perl array of output
########################################################################

sub parse_date_descr($$)
{
    my($date,$descr) = @_;
    my($dur,$untimed);
    my($subj,$hour,$min);

    if ($descr =~ /^(.+)\s*:\s*(\d+):(\d+)\s*$/)
    {
	($subj,$hour,$min) = ($1,$2,$3);
	$hour += 12 unless $hour == 0;	# timed events are always evening
					# except for midnight

	if ($subj eq 'Candle lighting')
	{
	    $dur = 18;
	}
	else
	{
	    $dur = 1;
	}

	$untimed = 0;
    }
    else
    {
	$hour = $min = -1;
	$dur = 0;
	$untimed = 1;
	$subj = $descr;
	$subj =~ s/Channukah/Chanukah/; # make spelling consistent
	$subj =~ s/Purim Koson/Purim Koton/;
	$subj =~ s/Tu B\'Shvat/Tu BiShvat/;
    }

    my($yomtov) = 0;
    my($subj_copy) = $subj;

    $subj_copy = $ashk2seph{$subj_copy}
	if defined $ashk2seph{$subj_copy};
    $subj_copy =~ s/ \d{4}$//; # fix Rosh Hashana

    $yomtov = 1 if $HebcalConst::YOMTOV{$subj_copy};

    $subj =~ s/\"/''/g;
    $subj =~ s/\s*:\s*$//g;

    my($mon,$mday,$year) = split(/\//, $date);

#    if (($subj eq 'Yom HaZikaron' || $subj eq "Yom HaAtzma'ut") &&
#	($year == 2004)) {
#	$mday++;
#    }

    ($subj,$untimed,$min,$hour,$mday,$mon - 1,$year,$dur,$yomtov);
}

sub format_evt_time {
    my($evt,$suffix) = @_;
    format_hebcal_event_time($evt->[$EVT_IDX_HOUR],
			     $evt->[$EVT_IDX_MIN],
			     $suffix);
}


sub format_hebcal_event_time {
    my($hour,$min,$suffix) = @_;
    $suffix = "pm" unless defined $suffix;
    if ($hour == 0) {
	$suffix =~ s/p/a/;
	$suffix =~ s/P/A/;
    }
    $hour -= 12 if $hour > 12;
    sprintf("%d:%02d%s", $hour, $min, $suffix);
}

sub invoke_hebcal
{
    my($cmd,$memo,$want_sephardic,$month_filter,$no_minor_fasts,$no_special_shabbat) = @_;
    my(@events,$prev);
    local($_);
    local(*HEBCAL);

    my $cmd_smashed;
    if (index($cmd, " -Y") == -1) {
	$cmd_smashed = $cmd;
	$cmd_smashed =~ s/^\S+//;
	$cmd_smashed =~ s/\s+-([A-Za-z])/$1/g;
	$cmd_smashed =~ s/\s+//g;
	$cmd_smashed =~ s/\'//g;
	$cmd_smashed =~ s/\//_/g;
    } else {
	$cmd_smashed = "";
    }

    my $hccache;
    my $login = getlogin() || getpwuid($<) || "UNKNOWN";
    my $hccache_dir = "/tmp/${login}-cache/cmd";

    unless (-d $hccache_dir) {
	system("/bin/mkdir", "-p", $hccache_dir);
    }
    my $hccache_file = "$hccache_dir/$cmd_smashed";

    @events = ();
    if ($cmd_smashed eq "") {
	open(HEBCAL,"$cmd |") || die "Can't exec '$cmd': $!\n";
    } elsif (open(HEBCAL,"<$hccache_file")) {
	# will read data from cachefile, not pipe
    } else {
	open(HEBCAL,"$cmd |") || die "Can't exec '$cmd': $!\n";
	$hccache = open(HCCACHE,">$hccache_file.$$");
    }

    $prev = '';
    while (<HEBCAL>)
    {
	print HCCACHE $_ if $hccache;
	next if $_ eq $prev;
	$prev = $_;
	chop;

	my($date,$descr) = split(/ /, $_, 2);

	# exec hebcal with entire years, but only return events matching
	# the month requested
	if ($month_filter)
	{
	    my($mon,$mday,$year) = split(/\//, $date);
	    next if $month_filter != $mon;
	}

	my($subj,$untimed,$min,$hour,$mday,$mon,$year,$dur,$yomtov) =
	    parse_date_descr($date,$descr);

	# not typically used
	if ($no_special_shabbat || $no_minor_fasts) {
	    my $subj_copy = $subj;
	    $subj_copy = $ashk2seph{$subj_copy}
		if defined $ashk2seph{$subj_copy};
	    if ($no_special_shabbat) {
		next if $subj_copy =~ /^Shabbat /;
	    }
	    if ($no_minor_fasts) {
		next if $subj_copy =~ /^Tzom /;
		next if $subj_copy =~ /^Ta\'anit /;
		next if $subj_copy eq "Asara B'Tevet";
	    }
	}

	# if Candle lighting and Havdalah are on the same day it is
	# a bug in hebcal for unix involving shabbos and chag overlap.
	# suppress inconsistent times until we can get hebcal fixed.
	if ($subj =~ /^Havdalah/ && $#events >= 0 &&
	    $events[$#events]->[$EVT_IDX_MDAY] == $mday &&
	    $events[$#events]->[$EVT_IDX_SUBJ] =~ /^Candle lighting/)
	{
	    pop(@events);
	    next;
	}

	next if $subj eq 'Havdalah (0 min)';

	my $memo2;
	if ($untimed) {
	    $memo2 = (get_holiday_anchor($subj,$want_sephardic,undef))[2];
	}

	push(@events,
	     [$subj,$untimed,$min,$hour,$mday,$mon,$year,$dur,
	      ($untimed ? $memo2 : $memo),$yomtov]);
    }
    close(HEBCAL);
    if ($hccache) {
	close(HCCACHE);
	rename("$hccache_file.$$", $hccache_file);
    }

    @events;
}

sub get_today_yomtov {
    my @events = invoke_hebcal($HEBCAL_BIN, "", 0);
    my($year,$month,$day) = Date::Calc::Today();
    for my $evt (@events) {
	if (event_date_matches($evt,$year,$month,$day) && $evt->[$EVT_IDX_YOMTOV]) {
	    return $evt->[$EVT_IDX_SUBJ];
	}
    }
    undef;
}

sub event_ymd($) {
  my($evt) = @_;
  my $year = $evt->[$EVT_IDX_YEAR];
  my $month = $evt->[$EVT_IDX_MON] + 1;
  my $day = $evt->[$EVT_IDX_MDAY];
  ($year,$month,$day);
}

sub event_dates_equal($$) {
  my($evt1,$evt2) = @_;
  my($year1,$month1,$day1) = event_ymd($evt1);
  my($year2,$month2,$day2) = event_ymd($evt2);
  $year1 == $year2 && $month1 == $month2 && $day1 == $day2;
}

sub event_date_matches($$$$) {
  my($evt,$gy,$gm,$gd) = @_;
  return ($evt->[$EVT_IDX_YEAR] == $gy
	  && $evt->[$EVT_IDX_MON] + 1 == $gm
	  && $evt->[$EVT_IDX_MDAY] == $gd);
}

sub date_format_sql($$$) {
  my($year,$month,$day) = @_;
  sprintf("%04d-%02d-%02d", $year, $month, $day);
}

sub date_format_csv($$$) {
  my($year,$month,$day) = @_;
  sprintf("%02d-%s-%04d", $day, $MoY_short[$month - 1], $year);
}

sub event_to_time
{
    my($evt) = @_;
    # holiday is at 12:00:01 am
    return Time::Local::timelocal(1,0,0,
				  $evt->[$EVT_IDX_MDAY],
				  $evt->[$EVT_IDX_MON],
				  $evt->[$EVT_IDX_YEAR] - 1900,
				  "","","");
}

sub events_to_dict
{
    my($events,$cfg,$q,$friday,$saturday,$tzid) = @_;

    unless ($eval_use_DateTime) {
	eval("use DateTime");
	$eval_use_DateTime = 1;
    }

    my $url = "http://" . $q->virtual_host() .
	self_url($q, {"cfg" => undef,
		      "c" => undef,
		      "nh" => undef,
		      "nx" => undef,
		      "tz" => undef,
		      "dst" => undef,
		      });
    my @items;
    foreach my $evt (@{$events}) {
	my $time = event_to_time($evt);
	next if ($friday && $time < $friday) || ($saturday && $time > $saturday);

	my $subj = $evt->[$EVT_IDX_SUBJ];
	my($year,$mon,$mday) = event_ymd($evt);

	my $min = $evt->[$EVT_IDX_MIN];
	my $hour24 = $evt->[$EVT_IDX_HOUR];

	my %item;
	my $format = (defined $cfg && $cfg =~ /^[ij]$/) ?
	    "%A, %d %b %Y" : "%A, %d %B %Y";
	$item{"date"} = strftime($format, localtime($time));

	if ($evt->[$EVT_IDX_UNTIMED] == 0)
	{
	    my $dt = DateTime->new(
				   year       => $year,
				   month      => $mon,
				   day        => $mday,
				   hour       => $hour24,
				   minute     => $min,
				   second     => 0,
				   time_zone  => $tzid,
				  );

	    my $tzOffset = $dt->offset();
	    my $tz = int($tzOffset / 3600);
	    my $tzMin = abs(int((($tzOffset / 3600) - $tz) * 60));

	    $item{"dc:date"} =
		sprintf("%04d-%02d-%02dT%02d:%02d:%02d%s%02d:%02d",
			$year,$mon,$mday,
			$hour24,$min,0,
			$tz > 0 ? "+" : "-",
			abs($tz), $tzMin);

	    my $dow = $DoW[get_dow($year, $mon, $mday)];
	    $item{"pubDate"} = sprintf("%s, %02d %s %d %02d:%02d:00 %s%02d%02d",
				       $dow, $mday,
				       $MoY_short[$mon - 1],
				       $year, $hour24, $min,
				       $tz > 0 ? "+" : "-",
				       abs($tz), $tzMin);
	}
	else
	{
	    $item{"dc:date"} = sprintf("%04d-%02d-%02d",$year,$mon,$mday);
	    my $dow = $DoW[get_dow($year, $mon, $mday)];
	    $item{"pubDate"} = sprintf("%s, %02d %s %d 00:00:00 +0000",
				       $dow,
				       $mday,
				       $MoY_short[$mon - 1],
				       $year);
	}

	my $anchor = sprintf("%04d%02d%02d_",$year,$mon,$mday) . lc($subj);
	$anchor =~ s/[^\w]/_/g;
	$anchor =~ s/_+/_/g;
	$anchor =~ s/_$//g;
	$item{"about"} = $url . "#" . $anchor;
	$item{"subj"} = $subj;

	if ($subj eq "Candle lighting" || $subj =~ /Havdalah/)
	{
	    $item{"class"} = ($subj eq "Candle lighting") ?
		"candles" : "havdalah";
	    $item{"time"} = format_evt_time($evt, "pm");
	    $item{"link"} = $url . "#" . $anchor;
	}
	elsif ($subj eq "No sunset today.")
	{
	    $item{"class"} = "candles";
	    $item{"link"} = $url . "#top";
	    $item{"time"} = "";
	}
	else
	{
	    if ($subj =~ /^(Parshas|Parashat)\s+/) {
		$item{"class"} = "parashat";
	    } elsif ($subj =~ /^(\d+)\w+ day of the Omer$/) {
		$item{"class"} = "omer";
	    } elsif ($subj =~ /^(\d+)\w+ of ([^,]+), (\d+)$/) {
		$item{"class"} = "hebdate";
	    } else {
		$item{"class"} = "holiday";
	    }

	    my($href,$hebrew) = get_holiday_anchor($subj,0,$q);
	    $item{"link"} = $href if $href;
	    $item{"hebrew"} = $hebrew if $hebrew;
	}

	push(@items, \%item);
    }

    \@items;
}

sub items_to_json {
    my($items,$q,$city_descr,$latitude,$longitude) = @_;

    unless ($eval_use_JSON) {
	eval("use JSON");
	$eval_use_JSON = 1;
    }

    my $cb = $q->param("callback");
    if ($cb && $cb =~ /^[A-Za-z_]\w*$/) {
	out_html(undef, $cb, "(");
    } else {
	$cb = undef;
    }

    my $out = { title => $city_descr,
		link => "http://" . $q->virtual_host() . self_url($q, {"cfg" => undef}),
		date => strftime("%Y-%m-%dT%H:%M:%S", gmtime(time())) . "-00:00",
		items => json_transform_items($items),
	      };

    if (defined $latitude) {
	$out->{latitude} = $latitude;
	$out->{longitude} = $longitude;
    }

    my $json = JSON->new;
    out_html(undef, $json->encode($out));
    out_html(undef, ")\n") if $cb;
}

sub json_transform_items {
    my($items) = @_;
    my @out;
    foreach my $item (@{$items}) {
	my $subj = $item->{"subj"};
	$subj .= ": " . $item->{"time"} if defined $item->{"time"};
	my $out = {
		   title => $subj,
		   category => $item->{"class"},
		   date => $item->{"dc:date"},
		  };
	$out->{link} = $item->{"link"}
	    if $item->{"class"} =~ /^(parashat|holiday)$/;
	$out->{hebrew} = $item->{"hebrew"}
	    if defined $item->{"hebrew"};
	push(@out, $out);
    }
    \@out;
}

sub upcoming_dow
{
    my($searching_dow) = @_;
    my @today = Date::Calc::Today();
    my $current_dow = Date::Calc::Day_of_Week(@today);

    if ($searching_dow == $current_dow)
    {
	return @today;
    }
    elsif ($searching_dow > $current_dow)
    {
	return Date::Calc::Add_Delta_Days(@today,
					  $searching_dow - $current_dow);
    }
    else
    {
	my @prev = Date::Calc::Add_Delta_Days(@today,
				  $searching_dow - $current_dow);
	return Date::Calc::Add_Delta_Days(@prev,+7);
    }
}

sub get_dow($$$)
{
    my($year,$mon,$mday) = @_;

    my $dow = Date::Calc::Day_of_Week($year,$mon,$mday);
    $dow == 7 ? 0 : $dow;
}

sub get_default_hebrew_year {
    my($year,$month,$day) = @_;
    my $hebdate = HebcalGPL::greg2hebrew($year,$month,$day);
    my $hyear = $hebdate->{"yy"};
    $hyear++ if ($hebdate->{"mm"} == $HebcalGPL::AV && $hebdate->{"dd"} >= 15)
	|| $hebdate->{"mm"} == $HebcalGPL::ELUL;
    $hyear;
}

sub hebnum_to_array {
    my($num) = @_;
    my(@result) = ();

    $num = $num % 1000;

    while ($num > 0)
    {
	my($incr) = 100;

	if ($num == 15 || $num == 16)
	{
	    push(@result, 9, $num - 9);
	    last;
	}

	my($i);
	for ($i = 400; $i > $num; $i -= $incr)
	{
	    if ($i == $incr)
	    {
		$incr = int($incr / 10);
	    }
	}

	push(@result, $i);

	$num -= $i;
    }

    @result;
}

sub hebnum_to_string {
    my($num) = @_;

    my(@array) = hebnum_to_array($num);
    my $digits = scalar(@array);
    my($result);

    if ($digits == 1)
    {
	$result = $num2heb{$array[0]} . "\x{5F3}"; # geresh
    }
    else
    {
	$result = '';
	for (my $i = 0; $i < $digits; $i++)
	{
	    $result .= "\x{5F4}" if (($i + 1) == $digits); # gershayim
	    $result .= $num2heb{$array[$i]};
	}
    }

    $result;
}

sub build_hebrew_date($$$)
{
    my($hm,$hd,$hy) = @_;

    my $s = hebnum_to_string($hd) . " \x{5D1}\x{5BC}\x{5B0}" .
	$monthnames{$hm};
    if (defined $hy) {
	$s .= " " . hebnum_to_string($hy);
    }
    $s;
}

sub hebrew_strip_nikkud($) {
    my($str) = @_;

    my $result = "";

    foreach my $c (split(//, $str))
    {
	if (ord($c) == 0x05BE) {
	    $result .= $c;
	} elsif (ord($c) > 0x0590 && ord($c) < 0x05D0) {
	    # skip hebrew punctuation range
	} else {
	    $result .= $c;
	}
    }

    return $result;
}


sub make_anchor($)
{
    my($f) = @_;

    my($anchor) = lc($f);
    $anchor =~ s/\'//g;
    $anchor =~ s/[^\w]/-/g;
    $anchor =~ s/-+/-/g;
    $anchor =~ s/^-//g;
    $anchor =~ s/-$//g;

    return $anchor;
}

sub get_holiday_anchor($$$)
{
    my($subj,$want_sephardic,$q) = @_;
    my($href) = '';
    my($hebrew) = '';
    my $memo = "";

    if ($subj =~ /^(Parshas\s+|Parashat\s+)(.+)$/)
    {
	my($parashat) = $1;
	my($sedra) = $2;

	# Unicode for "parashat"
	$hebrew = "\x{5E4}\x{5E8}\x{5E9}\x{5EA} ";

	$sedra = $ashk2seph{$sedra} if (defined $ashk2seph{$sedra});

	if (defined $HebcalConst::SEDROT{$sedra})
	{
	    my($anchor) = $sedra;
	    $anchor = lc($anchor);
	    $anchor =~ s/[^\w]//g;

	    $href = 'http://' . $q->virtual_host()
		if ($q);
	    $href .= "/sedrot/$anchor";

	    $hebrew .= $HebcalConst::SEDROT{$sedra};
	}
	elsif (($sedra =~ /^([^-]+)-(.+)$/) &&
	       (defined $HebcalConst::SEDROT{$1}
		|| defined $HebcalConst::SEDROT{$ashk2seph{$1}}))
	{
	    my($p1,$p2) = ($1,$2);

	    $p1 = $ashk2seph{$p1} if (defined $ashk2seph{$p1});
	    $p2 = $ashk2seph{$p2} if (defined $ashk2seph{$p2});

	    die "aliyah.xml missing $p2!" unless defined $HebcalConst::SEDROT{$p2};

	    my($anchor) = "$p1-$p2";
	    $anchor = lc($anchor);
	    $anchor =~ s/[^\w]//g;

	    $href = 'http://' . $q->virtual_host()
		if ($q);
	    $href .= "/sedrot/$anchor";

	    $hebrew .= $HebcalConst::SEDROT{$p1};

	    # hypenate hebrew reading
	    # HEBREW PUNCTUATION MAQAF (U+05BE)
	    $hebrew .= "\x{5BE}" . $HebcalConst::SEDROT{$p2};
	}
    }
    elsif ($subj =~ /^(\d+)\w+ day of the Omer$/)
    {
	$hebrew = hebnum_to_string($1) .
	    " \x{5D1}\x{5BC}\x{5B0}\x{5E2}\x{5D5}\x{5B9}\x{5DE}\x{5B6}\x{5E8}";
    }
    elsif ($subj =~ /^(\d+)\w+ of ([^,]+), (\d+)$/)
    {
	my($hm,$hd,$hy) = ($2,$1,$3);

	$hebrew = build_hebrew_date($hm,$hd,$hy);
    }
    elsif ($subj =~ /^Yizkor \(.+\)$/ ||
	   $subj =~ /\'s (Hebrew Anniversary|Hebrew Birthday|Yahrzeit)/)
    {
	# don't generate holiday anchors for yahrzeit calendar
    }
    else
    {
	my($subj_copy) = $subj;

	$subj_copy = $ashk2seph{$subj_copy}
	    if defined $ashk2seph{$subj_copy};

	# fix Rosh Hashana and Havdalah
	my $subj_suffix;
	if ($subj_copy =~ / (\d{4})$/) {
	    $subj_suffix = " $1";
	    $subj_copy =~ s/ \d{4}$//;
	} elsif ($subj_copy =~ /^Havdalah \((\d+) min\)$/) {
	    $subj_copy = "Havdalah";
	    $subj_suffix = " - $1 \x{05D3}\x{05E7}\x{05D5}\x{05EA}";
    	}

	if (defined $HebcalConst::HOLIDAYS{$subj_copy})
	{
	    $hebrew = $HebcalConst::HOLIDAYS{$subj_copy};
	    if ($subj_suffix) {
		$hebrew .= $subj_suffix;
	    }
	}

	if ($subj ne 'Candle lighting' && $subj !~ /^Havdalah/ &&
	    $subj ne 'No sunset today.')
	{
	    $subj_copy =~ s/ \(CH\'\'M\)$//;
	    $subj_copy =~ s/ \(Hoshana Raba\)$//;
	    $subj_copy =~ s/ [IV]+$//;
	    $subj_copy =~ s/: \d Candles?$//;
	    $subj_copy =~ s/: 8th Day$//;
	    $subj_copy =~ s/^Erev //;

	    $href = 'http://' . $q->virtual_host()
		if ($q);
	    $href .= "/holidays/" . make_anchor($subj_copy);
	}

	if (defined $HebcalConst::HOLIDAY_DESCR{$subj_copy}) {
	    $memo = $HebcalConst::HOLIDAY_DESCR{$subj_copy};
	}
    }

    if ($hebrew) {
	$hebrew = hebrew_strip_nikkud($hebrew);
    }

    return (wantarray()) ?
	($href,$hebrew,$memo)
	: $href;
}

sub get_torah_book_id {
    my($book) = @_;
    $book =~ s/\s+.+$//;
    my $bid = 0;
    if ($book =~ /^\d$/) {
	$bid = $book;
    } else {
	$book = lc($book);
	if ($book eq 'genesis') { $bid = 1; } 
	elsif ($book eq 'exodus') { $bid = 2; }
	elsif ($book eq 'leviticus') { $bid = 3; }
	elsif ($book eq 'numbers') { $bid = 4; }
	elsif ($book eq 'deuteronomy') { $bid = 5; }
    }
    return $bid;
}

sub get_mechon_mamre_url {
    my($book,$chapter,$verse) = @_;
    my $bid = get_torah_book_id($book);
    return sprintf("http://www.mechon-mamre.org/p/pt/pt%02d%02d.htm#%s",
		   $bid, $chapter, $verse);
}

sub get_bible_ort_org_url {
    my($book,$chapter,$verse,$parsha_id) = @_;
    my $bid = get_torah_book_id($book);
    return sprintf("http://www.bible.ort.org/books/torahd5.asp?action=displaypage&book=%d&chapter=%d&verse=%d&portion=%d",
		   $bid, $chapter, $verse, $parsha_id);
}


########################################################################
# web page utils
########################################################################

sub script_name($)
{
    my($q) = @_;

    my $script_name;
    if (defined $ENV{"SCRIPT_URL"}) {
	$script_name = $ENV{"SCRIPT_URL"};
    } else {
	$script_name = $q->script_name();
	$script_name =~ s,/\w+\.cgi$,/,;
    }

    $script_name;
}


my $cache = undef;
sub cache_begin {
    my($q,$munge_qs) = @_;

    my $orig_qs = $ENV{'QUERY_STRING'} || $ENV{'REDIRECT_QUERY_STRING'};
    return undef unless $orig_qs;

    # don't bother to cache a jQuery JSONP request (param "_" with timestamp value)
    return undef if $orig_qs =~ /&_=\d/;

    my $script_name = $q->script_name();
    $script_name =~ s/\./_/g;

    my $dir = $CACHE_DIR . $script_name;
    unless (-d $dir) {
	system("/bin/mkdir", "-p", $dir) == 0 or return undef;
    }

    my $qs;
    if ($munge_qs) {
	$qs = get_munged_qs($orig_qs);
    } else {
	my $ext = "html";
	if (defined $q->param("cfg")) {
	    my $cfg = $q->param("cfg");
	    if ($cfg eq "r") {
		$ext = "xml";
	    } elsif ($cfg eq "j") {
		$ext = "js";
	    } elsif ($cfg eq "json") {
		$ext = "json";
	    }
	    # otherwise use .html default
	}
	$qs = "${orig_qs}.${ext}";
    }
    $cache = "$dir/$qs.$$";
    if (!open(CACHE, ">$cache")) {
	$cache = undef;
	return undef;
    }

    if ($^V && $^V ge v5.8.1) {
	binmode(CACHE, ":utf8");
    }

    $cache;
}

sub cache_end {
    if ($cache)
    {
	close(CACHE);
	my $fn = $cache;
	my $newfn = $fn;
	$newfn =~ s/\.\d+$//;	# no pid
	rename($fn, $newfn);
	if ($newfn =~ m,^(.+)/([^/]+)$,) {
	    my $dir = $1;
	    my $qs = $2;
	    my $qs2 = URI::Escape::uri_unescape($qs);
	    if ($qs2 ne $qs) {
		# also symlink URL-decoded version for mod_rewrite internal redirect
		unlink("$dir/$qs2");
		symlink($qs, "$dir/$qs2");
	    }
	}
	$cache = undef;
    }

    1;
}

sub out_html
{
    my($cfg,@args) = @_;

    if (defined $cfg && $cfg eq 'j')
    {
	print STDOUT "document.write(\"";
	print CACHE "document.write(\"" if $cache;
	foreach (@args)
	{
	    s/\"/\\\"/g;
	    s/\n/\\n/g;
	    print STDOUT;
	    print CACHE if $cache;
	}
	print STDOUT "\");\n";
	print CACHE "\");\n" if $cache;
    }
    else
    {
	foreach (@args)
	{
	    print STDOUT;
	    print CACHE if $cache;
	}
    }

    1;
}

sub zipcode_open_db
{
    unless ($eval_use_DBI) {
	eval("use DBI");
	$eval_use_DBI = 1;
    }
    my($file) = $_[0] ? $_[0] : $ZIP_SQLITE_FILE;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$file", "", "")
	or die $DBI::errstr;
    $dbh;
}

sub zipcode_close_db($)
{
    my($dbh) = @_;
    $dbh->disconnect();
}

sub zipcode_get_v2_zip($$)
{
    my($dbh,$zipcode) = @_;

    my $sql = qq{
SELECT CityMixedCase,State,Latitude,Longitude,TimeZone,DayLightSaving
FROM ZIPCodes_Primary
WHERE ZipCode = ?
};

    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute($zipcode) or die $dbh->errstr;

    my($CityMixedCase,$State,$Latitude,$Longitude,$TimeZone,$DayLightSaving) = $sth->fetchrow_array;
    $sth->finish;
    ($CityMixedCase,$State,$Latitude,$Longitude,$TimeZone,$DayLightSaving);
}

sub latlong_to_hebcal {
    my($latitude,$longitude) = @_;

    # remove any prefixed + signs from the strings
    $latitude =~ s/^\+//;
    $longitude =~ s/^\+//;

    # remove any leading zeros
    $latitude =~ s/^(-?)0+/$1/;
    $longitude =~ s/^(-?)0+/$1/;

    my $lat_deg = int($latitude);
    my $long_deg = int($longitude) * -1;

    my $lat_min = abs(sprintf("%.0f", ($latitude - int($latitude)) * 60));
    my $long_min = abs(sprintf("%.0f", ($longitude - int($longitude)) * 60));

    ($lat_deg,$lat_min,$long_deg,$long_min);
}


sub zipcode_get_zip_fields($$)
{
    my($dbh,$zipcode) = @_;

    my($CityMixedCase,$State,$Latitude,$Longitude,$TimeZone,$DayLightSaving) =
	zipcode_get_v2_zip($dbh,$zipcode);

    if (! defined $State) {
	warn "zipcode_get_zip_fields: $zipcode Not Found";
	return undef;
    }

    my $tzid = get_usa_tzid($State,$TimeZone,$DayLightSaving);
    my($lat_deg,$lat_min,$long_deg,$long_min) =
	latlong_to_hebcal($Latitude, $Longitude);
    ($CityMixedCase,$State,$tzid,
     $Latitude,$Longitude,$lat_deg,$lat_min,$long_deg,$long_min);
}

sub html_footer_bootstrap
{
    my($q,$rcsrev,$noclosebody,$xtra_html) = @_;

    my($mtime) = (defined $ENV{'SCRIPT_FILENAME'}) ?
	(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

    my $hhmts = strftime("%d %B %Y", localtime($mtime));
    my $dc_date = strftime("%Y-%m-%dT%H:%M:%S", gmtime($mtime)) . "Z";
    my $last_updated_text = qq{<p><time datetime="$dc_date">$hhmts</time></p>};

    my $str = <<EOHTML;
</div><!-- #content -->

<footer role="contentinfo">
<hr>
<div id="inner-footer" class="clearfix">
<div class="row-fluid">
<div class="span3">
<ul class="nav nav-list">
<li class="nav-header">Products</li>
<li><a href="/holidays/">Jewish Holidays</a></li>
<li><a href="/converter/">Hebrew Date Converter</a></li>
<li><a href="/shabbat/">Shabbat Times</a></li>
<li><a href="/sedrot/">Torah Readings</a></li>
</ul>
</div><!-- .span3 -->
<div class="span3">
<ul class="nav nav-list">
<li class="nav-header">About Us</li>
<li><a href="/home/about">About Hebcal</a></li>
<li><a href="/home/category/news">News</a></li>
<li><a href="/home/about/privacy-policy">Privacy Policy</a></li>
</ul>
</div><!-- .span3 -->
<div class="span3">
<ul class="nav nav-list">
<li class="nav-header">Connect</li>
<li><a href="/home/help">Help</a></li>
<li><a href="/home/about/contact">Contact Us</a></li>
<li><a href="/home/about/donate">Donate</a></li>
<li><a href="/home/developer-apis">Developer APIs</a></li>
</ul>
</div><!-- .span3 -->
<div class="span3">
$last_updated_text
<p><small>Except where otherwise noted, content on
this site is licensed under a
<a rel="license" href="http://creativecommons.org/licenses/by/3.0/deed.en_US">Creative
Commons Attribution 3.0 License</a>.</small></p>
<p><small>Some location data comes from <a href="http://www.geonames.org/">GeoNames</a>,
also under a cc-by licence.</small></p>
</div><!-- .span3 -->
</div><!-- .row-fluid -->
</div><!-- #inner-footer -->
</footer>
</div> <!-- .container -->

<script src="//ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js"></script>
<script src="/i/bootstrap-2.3.1/js/bootstrap.min.js"></script>
EOHTML
;

    $str .= $URCHIN;
    $str .= $xtra_html if $xtra_html;

    if ($noclosebody) {
	return $str;
    } else {
	return $str . "</body></html>\n";
    }
}

sub woe_city
{
    my($id) = @_;
    return $HebcalConst::CITIES_NEW{$id}->[1];
}

sub woe_country_code
{
    my($id) = @_;
    return $HebcalConst::CITIES_NEW{$id}->[0];
}

sub woe_country
{
    my($id) = @_;
    my $country_name = $HebcalConst::COUNTRIES{woe_country_code($id)}->[0];
    $country_name =~ s/,\s+.+$//;
    $country_name;
}

sub sort_city_info
{
    return woe_city($a) . ", " . woe_country($a)
	cmp woe_city($b) . ", " . woe_country($b);
}

sub html_city_select
{
    my($selected_city) = @_;
    my $retval = "<select name=\"city\" class=\"input-xlarge\">\n";
    my %groups;
    while(my($id,$info) = each(%HebcalConst::CITIES_NEW)) {
	my($country,$city,$latitude,$longitude,$tzName,$woeid) = @{$info};
	my $grp = ($country =~ /^US|CA|IL$/)
	    ? $country
	    : $HebcalConst::COUNTRIES{$country}->[1];
	$groups{$grp} = [] unless defined $groups{$grp};
	push(@{$groups{$grp}}, [$id, $country, woe_country($id), $city]);
    }
    foreach my $grp (qw(US CA IL EU NA SA AS OC AF AN)) {
	next unless defined $groups{$grp};
	my $label = ($grp =~ /^US|CA|IL$/)
	    ? $HebcalConst::COUNTRIES{$grp}->[0]
	    : $CONTINENTS{$grp};
	$retval .= "<optgroup label=\"$label\">\n";
	foreach my $info (sort {$a->[3] cmp $b->[3]} @{$groups{$grp}}) {
	    my($id,$cc,$country,$city) = @{$info};
	    my $city_country = $city;
	    if ($cc eq "US") {
		$city_country .= ", USA";
	    } else {
		$city_country .= ", $country";
	    }
	    $retval .= sprintf "<option%s value=\"%s\">%s</option>\n",
		defined $selected_city && $id eq $selected_city ? " selected" : "",
		$id, $city_country;
	}
	$retval .= "</optgroup>\n";
    }
    $retval .= "</select>\n";
    $retval;
}

my $HTML_MENU_ITEMS_V2 =
    [
     [ "/holidays/",	"Holidays",	"Jewish Holidays" ],
     [ "/converter/",	"Date Converter", "Hebrew Date Converter" ],
     [ "/shabbat/",	"Shabbat",	"Shabbat Times" ],
     [ "/sedrot/",	"Torah",	"Torah Readings" ],
     [ "/home/about",	"About",	"About" ],
     [ "/home/help",	"Help",		"Help" ],
    ];

sub html_menu_item_bootstrap {
    my($path,$title,$tooltip,$selected) = @_;
    my $class = undef;
    if ($path eq $selected) {
	$class = "active";
    }
    my $str = qq{<li};
    if ($class) {
	$str .= qq{ class="$class"};
    }
    $str .= qq{><a href="$path" title="$tooltip">$title</a>};
    return $str;
}

sub html_menu_bootstrap {
    my($selected,$menu_items) = @_;
    my $str = qq{<ul class="nav navbar-nav">};
    foreach my $item (@{$menu_items}) {
	my $path = $item->[0];
	my $title = $item->[1];
	my $tooltip = $item->[2];
	if (defined $item->[3]) {
	    $str .= "<li class=\"dropdown\">";
	    $str .= "<a href=\"#\" class=\"dropdown-toggle\" data-toggle=\"dropdown\">$title <b class=\"caret\"></b></a>";
	    $str .= "<ul class=\"dropdown-menu\">";
	    for (my $i = 3; defined $item->[$i]; $i++) {
		$str .= html_menu_item_bootstrap($item->[$i]->[0], $item->[$i]->[1], $item->[$i]->[2], $selected);
		$str .= qq{</li>};
	    }
	    $str .= qq{</ul>};
	} else {
	    $str .= html_menu_item_bootstrap($path, $title, $tooltip, $selected);
	}
	$str .= qq{</li>};
    }
    $str .= qq{</ul>};
    return $str;
}

sub html_header_bootstrap {
    my($title,$base_href,$body_class,$xtra_head,$suppress_site_title,$hebrew_stylesheet) = @_;
    $xtra_head = "" unless $xtra_head;
    my $menu = html_menu_bootstrap($base_href,$HTML_MENU_ITEMS_V2);
    my $title2 = $suppress_site_title ? $title : "$title | Hebcal Jewish Calendar";
    my $xtra_stylesheet = $hebrew_stylesheet
	? "<link rel=\"stylesheet\" type=\"text/css\" href=\"http://fonts.googleapis.com/earlyaccess/alefhebrew.css\">\n"
	: "";
    my $str = <<EOHTML;
<!DOCTYPE html>
<html><head>
<meta charset="UTF-8">
<title>$title2</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="stylesheet" type="text/css" id="bootstrap-css" href="/i/bootstrap-2.3.1/css/bootstrap.min.css" media="all">
<link rel="stylesheet" type="text/css" id="bootstrap-responsive-css" href="/i/bootstrap-2.3.1/css/bootstrap-responsive.min.css" media="all">
$xtra_stylesheet<script type="text/javascript">
var _gaq = _gaq || [];
_gaq.push(['_setAccount', 'UA-967247-1']);
_gaq.push(['_trackPageview']);
(function() {
var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
})();
</script>
<style type="text/css">
.navbar{position:static}
body{
 padding-top:0;
 color:#222222;
}
:lang(he) {
  font-family:'Alef Hebrew','SBL Hebrew',David;
  font-size:125%;
  font-weight:normal;
  direction:rtl;
}
\@media print{
 a[href]:after{content:""}
 .sidebar-nav{display:none}
}
</style>
$xtra_head</head>
<body>

<div class="navbar navbar-fixed-top">
 <div class="navbar-inner">
   <div class="container-fluid nav-container">
   <a class="btn btn-navbar" data-toggle="collapse" data-target=".nav-collapse">
   <span class="icon-bar"></span>
   <span class="icon-bar"></span>
   <span class="icon-bar"></span>
   </a>
   <a class="brand" id="logo" title="Hebcal Jewish Calendar" href="/">Hebcal</a>
   <div class="nav-collapse collapse">
    $menu
    <form class="navbar-search pull-right" role="search" method="get" id="searchform" action="/home/">
    <input name="s" id="s" type="text" class="search-query" placeholder="Search">
    </form>
   </div><!-- .nav-collapse -->
   </div><!-- .container -->
 </div><!-- .navbar-inner -->
</div><!-- .navbar -->

<div class="container">
<div id="content" class="clearfix row-fluid">
EOHTML
;
    return $str;
}

sub html_entify($)
{
    local($_) = @_;

    s/&/&amp;/g;
    s/</&lt;/g;
    s/>/&gt;/g;
    s/"/&quot;/g; #"#
    s/\s+/ /g;

    $_;
}

sub url_escape($)
{
    return URI::Escape::uri_escape_utf8($_[0]);
}

sub http_date($)
{
    my($time) = @_;

    strftime("%a, %d %b %Y %T GMT", gmtime($time));
}

sub gen_cookie($)
{
    my($q) = @_;
    my($retval);

    $retval = 'C=t=' . time;

    if ($q->param('c') && $q->param('c') ne 'off')
    {
	if ($q->param('geo') eq 'zip') {
	    $retval .= '&zip=' . $q->param('zip');
	} elsif ($q->param('geo') eq 'city') {
	    $retval .= '&city=' . URI::Escape::uri_escape_utf8($q->param('city'));
	} elsif ($q->param('geo') eq 'geonameid') {
	    $retval .= '&geonameid=' . $q->param('geonameid');
	} elsif ($q->param('geo') eq 'pos') {
	    $retval .= '&lodeg=' . $q->param('lodeg');
	    $retval .= '&lomin=' . $q->param('lomin');
	    $retval .= '&lodir=' . $q->param('lodir');
	    $retval .= '&ladeg=' . $q->param('ladeg');
	    $retval .= '&lamin=' . $q->param('lamin');
	    $retval .= '&ladir=' . $q->param('ladir');
	    $retval .= '&tzid=' . URI::Escape::uri_escape_utf8($q->param('tzid'))
	        if defined $q->param('tzid') && $q->param('tzid') ne '';
	}
	$retval .= '&m=' . $q->param('m')
	    if defined $q->param('m') && $q->param('m') ne '';
    }

    foreach (@opts)
    {
	next if $_ eq 'c' || $_ eq 'H';
	$retval .= "&$_=" . $q->param($_)
	    if defined $q->param($_) && $q->param($_) ne '';
    }

    foreach (qw(nh nx)) {
	$retval .= "&$_=off"
	    if !defined $q->param($_) || $q->param($_) eq 'off';
    }

    foreach (qw(ss mf)) {
	if (defined $q->param($_)) {
	    $retval .= "&$_=" . $q->param($_);
	} elsif (!defined $q->param($_) || $q->param($_) eq 'off') {
	    $retval .= "&$_=off";
	}
    }

    if (defined $q->param("lg") && $q->param("lg") ne '')
    {
	$retval .= "&lg=" . $q->param("lg");
    }

    $retval;
}

sub get_cookies($)
{
    my($q) = @_;

    my($raw) = $q->raw_cookie();
    my(%cookies) = ();
    if ($raw)
    {
	foreach (split(/[;,\s]/, $raw))
	{
	    my($key,$val) = split(/=/, $_, 2);
	    next unless $key;
	    $val = '' unless defined($val);
	    $cookies{$key} = $val;
	}
    }

    \%cookies;
}

sub process_cookie($$)
{
    my($q,$cookieval) = @_;

    $cookieval =~ s/^C=//;

    if ($cookieval eq 'opt_out') {
	return undef;
    }

    my($c) = new CGI($cookieval);

    if ((! defined $q->param('c')) ||
	($q->param('c') eq 'on') ||
	($q->param('c') eq '1')) {
	if (defined $c->param('zip') && $c->param('zip') =~ /^\d{5}$/ &&
	    (! defined $q->param('geo') || $q->param('geo') eq 'zip')) {
	    $q->param('geo','zip');
	    $q->param('c','on');
	    if (! defined $q->param('zip') || $q->param('zip') =~ /^\s*$/)
	    {
		$q->param('zip',$c->param('zip'));
	    }
	} elsif (defined $c->param('geonameid') && $c->param('geonameid') =~ /^\d+$/ &&
	    (! defined $q->param('geo') || $q->param('geo') eq 'geonameid')) {
	    $q->param('geo','geonameid');
	    $q->param('c','on');
	    if (! defined $q->param('geonameid') || $q->param('geonameid') =~ /^\s*$/) {
		$q->param('geonameid',$c->param('geonameid'));
	    }
	} elsif (defined $c->param('city') && $c->param('city') ne '' &&
		 (! defined $q->param('geo') || $q->param('geo') eq 'city')) {
	    $q->param('city',$c->param('city'))
		unless $q->param('city');
	    $q->param('geo','city');
	    $q->param('c','on');
	    if (defined $CITY_COUNTRY{$q->param('city')} &&
		$CITY_COUNTRY{$q->param('city')} eq 'IL')
	    {
		$q->param('i','on');
		$c->param('i','on');
	    }
	} elsif (defined $c->param('lodeg') &&
		 defined $c->param('lomin') &&
		 defined $c->param('lodir') &&
		 defined $c->param('ladeg') &&
		 defined $c->param('lamin') &&
		 defined $c->param('ladir') &&
		 (! defined $q->param('geo') || $q->param('geo') eq 'pos')) {
	    foreach (qw(lodeg lomin ladeg lamin lodir ladir)) {
		$q->param($_, $c->param($_))
		    unless $q->param($_);
	    }
	    $q->param('geo','pos');
	    $q->param('c','on');
	    $q->param('tzid',$c->param('tzid'))
		if (defined $c->param('tzid') && ! defined $q->param('tzid'));
	}
    }

    $q->param('m',$c->param('m'))
	if (defined $c->param('m') && ! defined $q->param('m'));

    foreach (@opts)
    {
	next if $_ eq 'c';
	$q->param($_,$c->param($_))
	    if (! defined $q->param($_) && defined $c->param($_));
    }

    foreach (qw(nh nx ss mf lg)) {
	$q->param($_, $c->param($_))
	    if (! defined $q->param($_) && defined $c->param($_));
    }

    $c;
}

########################################################################
# EXPORT
########################################################################

sub self_url
{
    my($q,$override,$next_sep) = @_;

    my $url = script_name($q);
    my $sep = "?";
    $next_sep ||= ";";

    foreach my $key ($q->param())
    {
	# delete "utm_source" params unless explicitly specified
	next if $key eq "utm_source" && !exists $override->{"utm_source"};
	# ignore undef entries in the override hash
	next if exists $override->{$key} && !defined $override->{$key};
	my($val) = defined $override->{$key} ?
	    $override->{$key} : $q->param($key);
	$url .= "$sep$key=" . URI::Escape::uri_escape_utf8($val);
	$sep = $next_sep;
    }

    foreach my $key (keys %{$override})
    {
	# ignore undef entries in the override hash
	next unless defined $override->{$key};
	unless (defined $q->param($key))
	{
	    $url .= "$sep$key=" . URI::Escape::uri_escape_utf8($override->{$key});
	    $sep = $next_sep;
	}
    }

    $url;
}

sub get_geo_args {
    my($q,$separator) = @_;
    $separator = '&' unless defined $separator;
    if (defined $q->param('zip') && $q->param('zip') =~ /^\d+$/) {
	return 'zip=' . $q->param('zip');
    } elsif (defined $q->param('city') && $q->param('city') ne '') {
	return 'city=' . URI::Escape::uri_escape_utf8($q->param('city'));
    } elsif (defined $q->param('geonameid') && $q->param('geonameid') =~ /^\d+$/) {
	return 'geonameid=' . $q->param('geonameid');
    } elsif (defined $q->param('geo') && $q->param('geo') eq 'pos') {
	my $sep = '';
	my $retval = '';
	foreach (qw(city-typeahead lodeg lomin ladeg lamin lodir ladir tzid)) {
	    $retval .= "$sep$_=" . URI::Escape::uri_escape_utf8($q->param($_));
	    $sep = $separator;
	}
	return $retval;
    }
    '';
}

sub download_href
{
    my($q,$filename,$ext) = @_;

    my $cgi;
    my $script_name = $q->script_name();
    if ($script_name =~ /(\w+\.cgi)$/)
    {
	$cgi = $1;
	$script_name =~ s,/\w+\.cgi$,/,;
    }

    my $href = $script_name;
    $href .= $cgi if $cgi;
    $href .= "/$filename.$ext?dl=1";
    foreach my $key ($q->param()) {
	my $val = defined $q->param($key) ? $q->param($key) : "";
	$href .= ";$key=" . URI::Escape::uri_escape_utf8($val);
    }

    $href;
}

sub export_http_header($$)
{
    my($q,$mime) = @_;

    my($time) = defined $ENV{'SCRIPT_FILENAME'} ?
	(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

    my $path_info = decode_utf8($q->path_info());
    $path_info =~ s,^.*/,,;

    print $q->header(-type => "$mime; filename=\"$path_info\"",
                     -content_disposition =>
                     "attachment; filename=$path_info",
                     -last_modified => http_date($time));
}

sub get_browser_endl($)
{
    my($ua) = @_;
    my $endl;

    if ($ua && $ua =~ /^Mozilla\/[1-4]/)
    {
	if ($ua =~ /compatible/)
	{
	    $endl = "\015\012";
	}
	else
	{
	    $endl = "\012";	# netscape 4.x and below want unix LF only
	}
    }
    else
    {
	$endl = "\015\012";
    }

    $endl;
}

########################################################################
# export to vCalendar
########################################################################

my %VTIMEZONE =
(
"US/Eastern" =>
"BEGIN:VTIMEZONE
TZID:US/Eastern
BEGIN:STANDARD
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
TZOFFSETTO:-0500
TZOFFSETFROM:-0400
TZNAME:EST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
TZOFFSETTO:-0400
TZOFFSETFROM:-0500
TZNAME:EDT
END:DAYLIGHT
END:VTIMEZONE
",
"US/Central" =>
"BEGIN:VTIMEZONE
TZID:US/Central
BEGIN:STANDARD
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
TZOFFSETTO:-0600
TZOFFSETFROM:-0500
TZNAME:CST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
TZOFFSETTO:-0500
TZOFFSETFROM:-0600
TZNAME:CDT
END:DAYLIGHT
END:VTIMEZONE
",
"US/Mountain" =>
"BEGIN:VTIMEZONE
TZID:US/Mountain
BEGIN:STANDARD
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
TZOFFSETTO:-0700
TZOFFSETFROM:-0600
TZNAME:MST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
TZOFFSETTO:-0600
TZOFFSETFROM:-0700
TZNAME:MDT
END:DAYLIGHT
END:VTIMEZONE
",
"US/Pacific" =>
"BEGIN:VTIMEZONE
TZID:US/Pacific
X-MICROSOFT-CDO-TZID:13
BEGIN:STANDARD
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
TZOFFSETFROM:-0700
TZOFFSETTO:-0800
TZNAME:PST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
TZOFFSETFROM:-0800
TZOFFSETTO:-0700
TZNAME:PDT
END:DAYLIGHT
END:VTIMEZONE
",
"US/Alaska" =>
"BEGIN:VTIMEZONE
TZID:US/Alaska
BEGIN:STANDARD
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
TZOFFSETTO:-0900
TZOFFSETFROM:+0000
TZNAME:AKST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
TZOFFSETTO:-0800
TZOFFSETFROM:-0900
TZNAME:AKDT
END:DAYLIGHT
END:VTIMEZONE
",
"US/Hawaii" =>
"BEGIN:VTIMEZONE
TZID:US/Hawaii
LAST-MODIFIED:20060309T044821Z
BEGIN:DAYLIGHT
DTSTART:19330430T123000
TZOFFSETTO:-0930
TZOFFSETFROM:+0000
TZNAME:HDT
END:DAYLIGHT
BEGIN:STANDARD
DTSTART:19330521T020000
TZOFFSETTO:-1030
TZOFFSETFROM:-0930
TZNAME:HST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19420209T020000
TZOFFSETTO:-0930
TZOFFSETFROM:-1030
TZNAME:HWT
END:DAYLIGHT
BEGIN:DAYLIGHT
DTSTART:19450814T133000
TZOFFSETTO:-0930
TZOFFSETFROM:-0930
TZNAME:HPT
END:DAYLIGHT
BEGIN:STANDARD
DTSTART:19450930T020000
TZOFFSETTO:-1030
TZOFFSETFROM:-0930
TZNAME:HST
END:STANDARD
BEGIN:STANDARD
DTSTART:19470608T020000
TZOFFSETTO:-1000
TZOFFSETFROM:-1030
TZNAME:HST
END:STANDARD
END:VTIMEZONE
",
"US/Aleutian" =>
"BEGIN:VTIMEZONE
TZID:US/Aleutian
BEGIN:STANDARD
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
TZOFFSETTO:-1000
TZOFFSETFROM:-0900
TZNAME:HAST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
TZOFFSETTO:-0900
TZOFFSETFROM:-1000
TZNAME:HADT
END:DAYLIGHT
END:VTIMEZONE
",
"America/Phoenix" =>
"BEGIN:VTIMEZONE
TZID:America/Phoenix
BEGIN:STANDARD
DTSTART:19700101T000000
TZOFFSETTO:-0700
TZOFFSETFROM:-0700
END:STANDARD
END:VTIMEZONE
",
 );

# Zip-Codes.com TimeZone IDs
#
# Code 	Description 
#  4	Atlantic (GMT -04:00) 
#  5	Eastern (GMT -05:00) 
#  6	Central (GMT -06:00) 
#  7	Mountain (GMT -07:00) 
#  8	Pacific (GMT -08:00) 
#  9	Alaska (GMT -09:00) 
# 10	Hawaii-Aleutian Islands (GMT -10:00) 
# 11	American Samoa (GMT -11:00) 
# 13	Marshall Islands (GMT +12:00) 
# 14	Guam (GMT +10:00) 
# 15	Palau (GMT +9:00)
my %ZIPCODES_TZ_MAP = (
'0' => 'UTC',
'4' => 'America/Puerto_Rico',
'5' => 'America/New_York',
'6' => 'America/Chicago',
'7' => 'America/Denver',
'8' => 'America/Los_Angeles',
'9' => 'America/Anchorage',
'10' => 'Pacific/Honolulu',
'11' => 'Pacific/Pago_Pago',
'13' => 'Pacific/Funafuti',
'14' => 'Pacific/Guam',
'15' => 'Pacific/Palau',
);

sub process_args_common_jerusalem {
    my($q,$cconfig) = @_;
    # special case for candles 40 minutes before sunset...
    my $city = "IL-Jerusalem";
    $q->param("city", $city);
    $q->param("geo","city");

    my($latitude,$longitude) = @{$CITY_LATLONG{$city}};
    my $cmd = "./hebcal -C 'Jerusalem'";
    my $city_descr = "Jerusalem, Israel";
    $q->param("i", "on");
    foreach (qw(zip lodeg lomin ladeg lamin lodir ladir tz dst tzid geonameid city-typeahead)) {
	$q->delete($_);
    }
    if (defined $cconfig) {
	$cconfig->{"latitude"} = $latitude;
	$cconfig->{"longitude"} = $longitude;
	$cconfig->{"title"} = $city_descr;
	$cconfig->{"city"} = "Jerusalem";
	$cconfig->{"tzid"} = "Asia/Jerusalem";
	$cconfig->{"geo"} = "city";
    }
    (1,$cmd,$latitude,$longitude,$city_descr);
}

sub process_args_common_zip {
    my($q,$cconfig) = @_;

    if ($q->param('zip') !~ /^\d{5}$/) {
	my $message = "Sorry, <strong>" . $q->param('zip')
	    . "</strong> does not appear to be a 5-digit zip code.";
	return (0,$message,undef);
    }

    my $DB = zipcode_open_db();
    my($city,$state,$tzid,$latitude,$longitude,$lat_deg,$lat_min,$long_deg,$long_min) =
	zipcode_get_zip_fields($DB, $q->param("zip"));
    zipcode_close_db($DB);
    undef($DB);

    unless (defined $state) {
	my $message = "Sorry, can't find\n".  "<strong>" . $q->param('zip') .
	    "</strong> in the zip code database.";
	my $help = "<ul><li>Please try a nearby zip code</li></ul>";
	return (0,$message,$help);
    }

    my $cmd = "./hebcal -L $long_deg,$long_min -l $lat_deg,$lat_min -z '$tzid'";
    my $city_descr = "$city, $state " . $q->param('zip');

    $q->param("geo", "zip");
    foreach (qw(city lodeg lomin ladeg lamin lodir ladir tz dst tzid geonameid city-typeahead)) {
	$q->delete($_);
    }
    if (defined $cconfig) {
	$cconfig->{"latitude"} = $latitude;
	$cconfig->{"longitude"} = $longitude;
	$cconfig->{"title"} = $city_descr;
	$cconfig->{"city"} = $city;
	$cconfig->{"state"} = $state;
	$cconfig->{"zip"} = $q->param("zip");
	$cconfig->{"tzid"} = $tzid;
	$cconfig->{"geo"} = "zip";
    }
    (1,$cmd,$latitude,$longitude,$city_descr);
}

sub process_args_common_geoname {
    my($q,$cconfig) = @_;
    my $dbh = zipcode_open_db($GEONAME_SQLITE_FILE);
    $dbh->{sqlite_unicode} = 1;
    my $sql = qq{
SELECT g.name, g.asciiname, c.country, a.name, g.latitude, g.longitude, g.timezone
FROM geoname g
LEFT JOIN country c on g.country = c.iso
LEFT JOIN admin1 a on g.country||'.'||g.admin1 = a.key
WHERE g.geonameid = ?
};
    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute($q->param('geonameid')) or die $dbh->errstr;
    my($name,$asciiname,$country,$admin1,$latitude,$longitude,$tzid) = $sth->fetchrow_array;
    $sth->finish;
    zipcode_close_db($dbh);
    undef($dbh);

    my($lat_deg,$lat_min,$long_deg,$long_min) =
	latlong_to_hebcal($latitude, $longitude);
    my $cmd = "./hebcal -L $long_deg,$long_min -l $lat_deg,$lat_min -z '$tzid'";
    my $city_descr = "$name, $admin1, $country";
    if ($country eq "Israel") {
	$q->param('i','on');
    }
    foreach (qw(zip city lodeg lomin ladeg lamin lodir ladir tz dst tzid city-typeahead)) {
	$q->delete($_);
    }
    if (defined $cconfig) {
	$cconfig->{"latitude"} = $latitude;
	$cconfig->{"longitude"} = $longitude;
	$cconfig->{"title"} = $city_descr;
	$cconfig->{"city"} = $name;
	$cconfig->{"tzid"} = $tzid;
	$cconfig->{"geo"} = "geoname";
    }
    (1,$cmd,$latitude,$longitude,$city_descr);
}

sub process_args_common_geopos {
    my($q,$cconfig) = @_;

    my %maxval = ("ladeg" =>  90, "lamin" => 60,
		  "lodeg" => 180, "lomin" => 60);
    foreach my $key (qw(lodeg lomin ladeg lamin)) {
	my $value = $q->param($key);
	my $message;
	if ($value !~ /^\d+$/) {
	    $message = "Sorry, all latitude/longitude\narguments must be numeric.";
	}
	if ($value > $maxval{$key}) {
	    my $keyname = (substr($key, 1, 1) eq "a") ? "latitude" : "longitude";
	    $keyname .= (substr($key, 2, 1) eq "d") ? " degrees" : " minutes";
	    $message = "Sorry, $keyname <strong>$value</strong> out of valid range 0-$maxval{$key}";
	}
	return (0, $message, undef) if $message;
    }

    my($long_deg,$long_min,$lat_deg,$lat_min) =
	($q->param("lodeg"),$q->param("lomin"),
	 $q->param("ladeg"),$q->param("lamin"));
    
    $q->param("lodir","w") unless ($q->param("lodir") eq "e");
    $q->param("ladir","n") unless ($q->param("ladir") eq "s");

    $q->param("geo","pos");

    # Geographic Position
    my $city_descr = sprintf("%d\x{b0}%d\x{2032}%s, %d\x{b0}%d\x{2032}%s",
			     $lat_deg, $lat_min, uc($q->param("ladir")),
			     $long_deg, $long_min, uc($q->param("lodir")));

    my $latitude = $lat_deg + ($lat_min / 60.0);
    my $longitude = $long_deg + ($long_min / 60.0);
    $latitude *= -1 if $q->param("ladir") eq "s";
    $longitude *= -1 if $q->param("lodir") eq "w";

    # don't multiply minutes by -1 since hebcal does it internally
    $long_deg *= -1  if ($q->param("lodir") eq "e");
    $lat_deg  *= -1  if ($q->param("ladir") eq "s");

    my $cmd = "./hebcal -L $long_deg,$long_min -l $lat_deg,$lat_min";

    # special-case common old-style URLs
    if (! defined $q->param("tzid")
	&& defined $q->param("tz")
	&& defined $q->param("dst")) {
	my $tz = $q->param("tz");
	my $dst = $q->param("dst");
	if ($tz eq "0" && $dst eq "none") { 
	    $q->param("tzid", "UTC");
	} elsif ($tz eq "2" && $dst eq "israel") { 
	    $q->param("tzid", "Asia/Jerusalem");
	} elsif ($tz eq "0" && $dst eq "eu") { 
	    $q->param("tzid", "Europe/London");
	} elsif ($tz eq "1" && $dst eq "eu") { 
	    $q->param("tzid", "Europe/Paris");
	} elsif ($tz eq "2" && $dst eq "eu") { 
	    $q->param("tzid", "Europe/Athens");
	} elsif ($dst eq "usa" && defined $ZIPCODES_TZ_MAP{int($tz * -1)}) {
	    $q->param("tzid", $ZIPCODES_TZ_MAP{int($tz * -1)});
	}
    }

    if (! defined $q->param("tzid")) {
	return (0, "Please select a Time zone", undef);
    }

    my $tzid = $q->param("tzid");
    $cmd .= " -z '$tzid'";
    $city_descr .= ", $tzid";

    foreach (qw(city zip tz dst geonameid)) {
	$q->delete($_);
    }
    if (defined $cconfig) {
	$cconfig->{"latitude"} = $latitude;
	$cconfig->{"longitude"} = $longitude;
	$cconfig->{"lat_deg"} = $lat_deg;
	$cconfig->{"lat_min"} = $lat_min;
	$cconfig->{"long_deg"} = $long_deg;
	$cconfig->{"long_min"} = $long_min;
	if (defined $q->param("city-typeahead") && $q->param("city-typeahead") !~ /^\s*$/) {
	    $cconfig->{"title_pos"} = $city_descr;
	    my $city_typeahead = $q->param("city-typeahead");
	    $city_typeahead =~ s/^\s+//; # trim leading and trailing whitespace
	    $city_typeahead =~ s/\s+$//;
	    $city_descr = $city_typeahead; # save full string for return value
	    $city_typeahead =~ s/,.+//;
	    $cconfig->{"city"} = $city_typeahead; # short name for title tag
	}
	$cconfig->{"title"} = $city_descr;
	$cconfig->{"tzid"} = $tzid;
	$cconfig->{"geo"} = "pos";
    }
    (1,$cmd,$latitude,$longitude,$city_descr);
}

sub process_args_common_city {
    my($q,$cconfig) = @_;
    my $city = validate_city($q->param("city"));
    if (! defined $city) {
	if (defined $q->param("cfg") && $q->param("cfg") =~ /^(json|xml|r|e|e2)$/) {
	    my $city2 = $q->param("city") || "";
	    return (0, "Unknown city '$city2'", undef);
	} else {
	    $city = "US-New York-NY";
	}
    }

    $q->param("city", $city);
    $q->param("geo","city");

    my($latitude,$longitude) = @{$CITY_LATLONG{$city}};
    my($lat_deg,$lat_min,$long_deg,$long_min) =
	latlong_to_hebcal($latitude, $longitude);
    my $tzid = $CITY_TZID{$city};

    my $cmd = "./hebcal -L $long_deg,$long_min -l $lat_deg,$lat_min -z '$tzid'";

    my $country = woe_country($city);
    $country = "USA" if $country eq "United States of America";
    $country = "UK" if $country eq "United Kingdom";
    my $city_descr = woe_city($city) . ", $country";

    if ($CITY_COUNTRY{$city} eq 'IL') {
	$q->param('i','on');
    }
    foreach (qw(zip lodeg lomin ladeg lamin lodir ladir tz dst tzid city-typeahead geonameid)) {
	$q->delete($_);
    }
    if (defined $cconfig) {
	$cconfig->{"latitude"} = $latitude;
	$cconfig->{"longitude"} = $longitude;
	$cconfig->{"title"} = $city_descr;
	$cconfig->{"city"} = woe_city($city);
	$cconfig->{"tzid"} = $tzid;
	$cconfig->{"geo"} = "city";
    }
    (1,$cmd,$latitude,$longitude,$city_descr);
}

sub process_args_common_none {
    my($q,$cconfig) = @_;
    $q->param("geo","none");
    $q->param("c","off");
    foreach (qw(m zip city lodeg lomin ladeg lamin lodir ladir tz dst tzid city-typeahead geonameid)) {
	$q->delete($_);
    }
    if (defined $cconfig) {
	$cconfig->{"geo"} = "none";
    }
    my $cmd = "./hebcal";
    (1,$cmd,undef,undef,undef);
}

sub process_args_common {
    my($q,$handle_cookie,$default_to_nyc,$cconfig) = @_;

    if ($handle_cookie) {
	# default setttings needed for cookie
	foreach (qw(c nh nx)) {
	    $q->param($_, "on");
	}

	my $cookies = get_cookies($q);
	if (defined $cookies->{'C'}) {
	    process_cookie($q,$cookies->{'C'});
	}
    }

    my @status;
    if (defined $q->param("city") &&
	($q->param("city") eq "Jerusalem" || $q->param("city") eq "IL-Jerusalem")) {
	@status = process_args_common_jerusalem($q, $cconfig);
    } elsif (defined $q->param('zip') && $q->param('zip') ne '') {
	@status = process_args_common_zip($q, $cconfig);
    } elsif (defined $q->param('geonameid') && $q->param('geonameid') =~ /^\d+$/) {
	if ($q->param('geonameid') == 281184) {
	    @status = process_args_common_jerusalem($q, $cconfig);
	} else {
	    @status = process_args_common_geoname($q, $cconfig);
	}
    } elsif (defined $q->param("lodeg") && defined $q->param("lomin") &&
	     defined $q->param("ladeg") && defined $q->param("lamin") &&
	     defined $q->param("lodir") && defined $q->param("ladir") &&
	     $q->param("lodeg") ne '' && $q->param("lomin") ne '' &&
	     $q->param("ladeg") ne '' && $q->param("lamin") ne '') {
	@status = process_args_common_geopos($q, $cconfig);
    } elsif ($default_to_nyc ||
	     (defined $q->param("city") && $q->param("city") ne "")) {
	@status = process_args_common_city($q, $cconfig);
    } else {
	@status = process_args_common_none($q, $cconfig);
    }

    return @status unless $status[0];
    my($cmd,$latitude,$longitude,$city_descr) = @status[1..4];

    $cmd .= " -m " . $q->param('m')
	if (defined $q->param('m') && $q->param('m') =~ /^\d+$/);

    foreach (qw(a i)) {
	$cmd .= ' -' . $_
	    if defined $q->param($_) && $q->param($_) =~ /^on|1$/;
    }

    return (1,$cmd,$latitude,$longitude,$city_descr);
}


sub validate_city {
    my($city) = @_;
    unless (defined $city) {
	return undef;
    }
    if (defined($CITIES_OLD{$city})) {
	return $CITIES_OLD{$city};
    }
    if (defined($CITY_TZID{$city})) {
	return $city;
    }
    return undef;
}


sub get_usa_tzid {
    my($state,$tz,$dst) = @_;
    if (defined $state && $state eq 'AK' && $tz == 10) {
	return 'America/Adak';
    } elsif (defined $state && $state eq 'AZ' && $tz == 7) {
	if ($dst eq 'Y') {
	    return 'America/Denver';
	} else {
	    return 'America/Phoenix';
	}
    } else {
	return $ZIPCODES_TZ_MAP{$tz};
    }
}


sub get_munged_qs
{
    my($args) = @_;

    my $qs;
    if ($args) {
	$qs = $args;
    } elsif ($ENV{"REQUEST_URI"} && $ENV{"REQUEST_URI"} =~ /\?(.+)$/) {
	$qs = $1;
    } else {
	$qs = "bogus";
    }

    # first translate all ampersands and semicolons into commas
    $qs =~ s/&amp;/,/g;
    $qs =~ s/&/,/g;
    $qs =~ s/;/,/g;

    # now delete selected parameters
    $qs =~ s/,?(tag|utm_source|utm_campaign|set|vis|subscribe|dl)=[^,]+//g;
    $qs =~ s/,?\.(from|cgifields|s)=[^,]+//g;
    $qs =~ s/^,+//g;
    $qs =~ s/\./_/g;
    $qs =~ s/\//-/g;
    $qs =~ s/\%20/+/g;
    $qs =~ s/[\<\>\s\"\'\`\?\*\$\|\[\]\{\}\\\~]//g; # unsafe chars

    return $qs;
}

sub get_vcalendar_cache_fn
{
    my($args) = @_;

    my $qs = get_munged_qs($args);
    my $digest = Digest::MD5::md5_hex($qs);
    my $dir = substr($digest, 0, 2);
    my $fn = substr($digest, 2) . ".ics";

    return "/export/$dir/$fn";
}


sub torah_calendar_memo {
    my($dbh,$sth,$gy,$gm,$gd) = @_;
    my $date_sql = sprintf("%04d-%02d-%02d", $gy, $gm, $gd);
    my $rv = $sth->execute($date_sql) or die $dbh->errstr;
    my $torah_reading;
    my $haftarah_reading;
    my $special_maftir;
    while(my($aliyah_num,$aliyah_reading) = $sth->fetchrow_array) {
	if ($aliyah_num eq "T") {
	    $torah_reading = $aliyah_reading;
	} elsif ($aliyah_num eq "M" && $aliyah_reading =~ / \| /) {
	    $special_maftir = $aliyah_reading;
	} elsif ($aliyah_num eq "H") {
	    $haftarah_reading = $aliyah_reading;
	}
    }
    $sth->finish;
    my $memo;
    if ($torah_reading) {
	$memo = "Torah: $torah_reading";
	if ($special_maftir) {
	    $memo .= "\\nMaftir: ";
	    $memo .= $special_maftir;
	}
	if ($haftarah_reading) {
	    $memo .= "\\nHaftarah: ";
	    $memo .= $haftarah_reading;
	}
    }
    return $memo;
}

sub vcalendar_write_contents
{
    my($q,$events,$title,$cconfig) = @_;

    my $is_icalendar = ($q->path_info() =~ /\.ics$/) ? 1 : 0;

    if ($is_icalendar) {
	$cache = $ENV{"DOCUMENT_ROOT"} . get_vcalendar_cache_fn() . ".$$";
	my $dir = $cache;
	$dir =~ s,/[^/]+$,,;	# dirname
	unless (-d $dir) {
	    system("/bin/mkdir", "-p", $dir);
	}
	if (open(CACHE, ">$cache")) {
	    if ($^V && $^V ge v5.8.1) {
		binmode(CACHE, ":utf8");
	    }
	} else {
	    $cache = undef;
	}
	export_http_header($q, 'text/calendar; charset=UTF-8');
    } else {
	export_http_header($q, 'text/x-vCalendar');
    }

    my $endl = get_browser_endl($q->user_agent());

    my $tzid;
    if ($is_icalendar && defined $cconfig && defined $cconfig->{"tzid"}) {
	$tzid = $cconfig->{"tzid"};
    }

    my @gmtime_now = gmtime(time());
    my $dtstamp = strftime("%Y%m%dT%H%M%SZ", @gmtime_now);
    my $utm_campaign = strftime("ical-%Y", @gmtime_now);

    out_html(undef, qq{BEGIN:VCALENDAR$endl});

    if ($is_icalendar) {
	if (defined $cconfig && defined $cconfig->{"city"}) {
	    $title = $cconfig->{"city"} . " " . $title;
	}

	$title =~ s/,/\\,/g;

	out_html(undef, 
	qq{VERSION:2.0$endl},
	qq{PRODID:-//hebcal.com/NONSGML Hebcal Calendar v4.13//EN$endl},
	qq{CALSCALE:GREGORIAN$endl},
	qq{METHOD:PUBLISH$endl},
	qq{X-LOTUS-CHARSET:UTF-8$endl},
	qq{X-PUBLISHED-TTL:PT7D$endl},
	qq{X-WR-CALNAME:Hebcal $title$endl});

	# include an iCal description
	if (defined $q->param("v"))
	{
	    my $desc;
	    if ($q->param("v") eq "yahrzeit") {
		$desc = "Yahrzeits + Anniversaries from www.hebcal.com";
	    } else {
		$desc = "Jewish Holidays from www.hebcal.com";
	    }
	    out_html(undef, qq{X-WR-CALDESC:$desc$endl});
	}
    } else {
	out_html(undef, qq{VERSION:1.0$endl},
		 qq{METHOD:PUBLISH$endl});
    }

    if ($tzid) {
	out_html(undef, qq{X-WR-TIMEZONE;VALUE=TEXT:$tzid$endl});
	my $vtimezone_ics = $ENV{"DOCUMENT_ROOT"} . "/zoneinfo/" . $tzid . ".ics";
	if (defined $VTIMEZONE{$tzid}) {
	    my $vt = $VTIMEZONE{$tzid};
	    $vt =~ s/\n/$endl/g;
	    out_html(undef, $vt);
	} elsif (open(VTZ,$vtimezone_ics)) {
	    my $in_vtz = 0;
	    while(<VTZ>) {
		$in_vtz = 1 if /^BEGIN:VTIMEZONE/;
		out_html(undef, $_) if $in_vtz;
		$in_vtz = 0 if /^END:VTIMEZONE/;
	    }
	    close(VTZ);
	}
    }

    unless ($eval_use_DBI) {
	eval("use DBI");
	$eval_use_DBI = 1;
    }

    # don't raise error if we can't open DB
    my $dbh = DBI->connect("dbi:SQLite:dbname=$LUACH_SQLITE_FILE", "", "");
    my $sth;
    if (defined $dbh) {
      $sth = $dbh->prepare("SELECT num,reading FROM leyning WHERE dt = ?");
      if (! defined $sth) {
	$dbh = undef;
      }
    }

    foreach my $evt (@{$events}) {
	out_html(undef, qq{BEGIN:VEVENT$endl});
	out_html(undef, qq{DTSTAMP:$dtstamp$endl});

	if ($is_icalendar) {
	    out_html(undef, qq{CATEGORIES:Holiday$endl});
#	    out_html(undef, qq{STATUS:CONFIRMED$endl});
	} else {
	    out_html(undef, qq{CATEGORIES:HOLIDAY$endl});
	}

	my $subj = $evt->[$EVT_IDX_SUBJ];

	my($href,$hebrew,$dummy_memo) = get_holiday_anchor($subj,0,$q);

	$subj =~ s/,/\\,/g;

	if ($is_icalendar) {
	    $subj = translate_subject($q,$subj,$hebrew);
	}

	out_html(undef, qq{CLASS:PUBLIC$endl}, qq{SUMMARY:$subj$endl});

	my $memo = "";
	if ($evt->[$EVT_IDX_UNTIMED] == 0
	    && defined $cconfig
	    && defined $cconfig->{"city"})
	{
	    out_html(undef, qq{LOCATION:}, $cconfig->{"city"}, $endl);
	}
	elsif ($evt->[$EVT_IDX_MEMO])
 	{
	    $memo = $evt->[$EVT_IDX_MEMO];
	}
	elsif (defined $dbh && $subj =~ /^(Parshas|Parashat)\s+/)
	{
	    my($year,$mon,$mday) = event_ymd($evt);
	    $memo = torah_calendar_memo($dbh, $sth,
					$year, $mon, $mday);
	}

	if ($href) {
	  if ($href =~ m,/(sedrot|holidays)/.+,) {
	    $href .= "?utm_source=ical&utm_campaign=$utm_campaign";
	  }
	  out_html(undef, qq{URL:}, $href, $endl) if $is_icalendar;
	  $memo .= "\\n\\n" if $memo;
	  $memo .= $href;
	}

	if ($memo) {
	  $memo =~ s/,/\\,/g;
	  $memo =~ s/;/\\;/g;
	  out_html(undef, qq{DESCRIPTION:}, $memo, $endl);
	}

	my($year,$mon,$mday) = event_ymd($evt);
	my $date = sprintf("%04d%02d%02d",
			   $year, $mon, $mday);
	my $end_date = $date;

	if ($evt->[$EVT_IDX_UNTIMED] == 0)
	{
	    my $hour = $evt->[$EVT_IDX_HOUR];
	    my $min = $evt->[$EVT_IDX_MIN];

	    $hour += 12 if $hour < 12;
	    $date .= sprintf("T%02d%02d00", $hour, $min);

	    $min += $evt->[$EVT_IDX_DUR];
	    if ($min >= 60)
	    {
		$hour++;
		$min -= 60;
	    }

	    $end_date .= sprintf("T%02d%02d00", $hour, $min);
	}
	else
	{
	    my($year,$mon,$mday) = event_ymd($evt);
	    my($gy,$gm,$gd) = Date::Calc::Add_Delta_Days($year, $mon, $mday, 1);
	    $end_date = sprintf("%04d%02d%02d", $gy, $gm, $gd);

	    # for vCalendar Palm Desktop and Outlook 2000 seem to
	    # want midnight to midnight for all-day events.
	    # Midnight to 23:59:59 doesn't seem to work as expected.
	    if (!$is_icalendar)
	    {
		$date .= "T000000";
		$end_date .= "T000000";
	    }
	}

	out_html(undef, qq{DTSTART});
	if ($is_icalendar) {
	    if ($evt->[$EVT_IDX_UNTIMED]) {
		out_html(undef, ";VALUE=DATE");
	    } elsif ($tzid) {
		out_html(undef, ";TZID=$tzid");
	    }
	}
	out_html(undef, qq{:$date$endl});

	if ($is_icalendar && $evt->[$EVT_IDX_UNTIMED])
	{
	    # avoid using DTEND since Apple iCal and Lotus Notes
	    # seem to interpret all-day events differently
	    out_html(undef, qq{DURATION:P1D$endl});
	}
	else
	{
	    out_html(undef, qq{DTEND});
	    out_html(undef, ";TZID=$tzid") if $tzid;
	    out_html(undef, qq{:$end_date$endl});
        }
	
	if ($is_icalendar) {
	    if ($evt->[$EVT_IDX_UNTIMED] == 0 ||
		$evt->[$EVT_IDX_YOMTOV] == 1) {
		out_html(undef, "TRANSP:OPAQUE$endl"); # show as busy
		out_html(undef, "X-MICROSOFT-CDO-BUSYSTATUS:OOF$endl");
	    } else {
		out_html(undef, "TRANSP:TRANSPARENT$endl"); # show as free
		out_html(undef, "X-MICROSOFT-CDO-BUSYSTATUS:FREE$endl");
	    }

	    my $date_copy = $date;
	    $date_copy =~ s/T\d+$//;

	    my $subj_utf8 = encode_utf8($evt->[$EVT_IDX_SUBJ]);
	    my $digest = Digest::MD5::md5_hex($subj_utf8);
	    my $uid = "hebcal-$date_copy-$digest";

	    if ($evt->[$EVT_IDX_UNTIMED] == 0
		&& defined $cconfig) {
		my $loc;
		if (defined $cconfig->{"zip"}) {
		    $loc = $cconfig->{"zip"};
		} elsif (defined $cconfig->{"city"}) {
		    $loc = lc($cconfig->{"city"});
		    $loc =~ s/[^\w]/-/g;
		    $loc =~ s/-+/-/g;
		    $loc =~ s/-$//g;
		} elsif (defined $cconfig->{"long_deg"}
			 && defined $cconfig->{"long_min"}
			 && defined $cconfig->{"lat_deg"}
			 && defined $cconfig->{"lat_min"}) {
		    $loc = join("-", "pos",
				$cconfig->{"long_deg"},
				$cconfig->{"long_min"},
				$cconfig->{"lat_deg"},
				$cconfig->{"lat_min"});
		}

		if ($loc) {
		    $uid .= "-" . $loc;
		}
	    }

	    out_html(undef, qq{UID:$uid$endl});

	    my $alarm;
	    if ($evt->[$EVT_IDX_SUBJ] =~ /^(\d+)\w+ day of the Omer$/) {
		$alarm = "3H";	# 9pm Omer alarm evening before
	    }
	    elsif ($evt->[$EVT_IDX_SUBJ] =~ /^Yizkor \(.+\)$/ ||
		   $evt->[$EVT_IDX_SUBJ] =~
		   /\'s (Hebrew Anniversary|Hebrew Birthday|Yahrzeit)/) {
		$alarm = "12H";	# noon the day before
	    }
	    elsif ($evt->[$EVT_IDX_SUBJ] eq 'Candle lighting') {
		$alarm = "10M";	# ten minutes
	    }

	    if (defined $alarm) {
		out_html(undef, "BEGIN:VALARM${endl}",
			 "X-WR-ALARMUID:${uid}-alarm${endl}",
			 "ACTION:AUDIO${endl}",
			 "TRIGGER:-PT${alarm}${endl}",
			 "END:VALARM${endl}");
	    }
	}

	out_html(undef, qq{END:VEVENT$endl});
    }

    out_html(undef, qq{END:VCALENDAR$endl});

    if (defined $dbh) {
      undef $sth;
      $dbh->disconnect();
    }

    cache_end();
    1;
}

sub translate_subject
{
    my($q,$subj,$hebrew) = @_;

    my $lang = $q->param("lg") || "s";
    if ($lang eq "s" || $lang eq "a" || !$hebrew) {
	return $subj;
    } elsif ($lang eq "h") {
	return $hebrew;
    } elsif ($lang eq "ah" || $lang eq "sh") {
	return "$subj / $hebrew";
    } else {
	die "unknown lang \"$lang\" for $subj";
    }
}

########################################################################
# export to Outlook CSV
########################################################################

sub csv_write_contents($$$)
{
    my($q,$events,$euro) = @_;

    export_http_header($q, 'text/x-csv');
    my $endl = get_browser_endl($q->user_agent());

    print STDOUT
	qq{"Subject","Start Date","Start Time","End Date",},
	qq{"End Time","All day event","Description","Show time as",},
	qq{"Location"$endl};

    foreach my $evt (@{$events}) {
	my $subj = $evt->[$EVT_IDX_SUBJ];
	my $memo = $evt->[$EVT_IDX_MEMO];

	my $date;
	my($year,$mon,$mday) = event_ymd($evt);
	if ($euro) {
	    $date = sprintf("\"%d/%d/%04d\"",
			    $mday, $mon, $year);
	} else {
	    $date = sprintf("\"%d/%d/%04d\"",
			    $mon, $mday, $year);
	}

	my($start_time) = '';
	my($end_time) = '';
	my($end_date) = '';
	my($all_day) = '"true"';

	if ($evt->[$EVT_IDX_UNTIMED] == 0)
	{
	    my $hour = $evt->[$EVT_IDX_HOUR];
	    my $min = $evt->[$EVT_IDX_MIN];

	    $start_time = '"' . format_hebcal_event_time($hour, $min, " PM") . '"';

	    $min += $evt->[$EVT_IDX_DUR];

	    if ($min >= 60)
	    {
		$hour++;
		$min -= 60;
	    }

	    $end_time = '"' . format_hebcal_event_time($hour, $min, " PM") . '"';
	    $end_date = $date;
	    $all_day = '"false"';
	}

	$subj =~ s/,//g;
	$memo =~ s/,/;/g;

	$subj =~ s/\"/''/g;
	$memo =~ s/\"/''/g;

	my $loc = 'Jewish Holidays';
	if ($memo =~ /^in (.+)\s*$/)
	{
	    $memo = '';
	    $loc = $1;
	}

	print STDOUT
	    qq{"$subj",$date,$start_time,$end_date,$end_time,},
	    qq{$all_day,"$memo",};

	if ($evt->[$EVT_IDX_UNTIMED] == 0 ||
	    $evt->[$EVT_IDX_YOMTOV] == 1)
	{
	    print STDOUT qq{"4"};
	}
	else
	{
	    print STDOUT qq{"3"};
	}

	print STDOUT qq{,"$loc"$endl};
    }

    1;
}

########################################################################
# for managing email shabbat list
########################################################################

sub sendmail_v2
{
    my($return_path,$headers,$body,$verbose) = @_;

    eval("use Email::Valid");
    eval("use Net::SMTP");
    
    if (! Email::Valid->address($return_path))
    {
	warn "Hebcal.pm: Return-Path $return_path is invalid"
	    if $verbose;
	return 0;
    }

    my($from) = $headers->{'From'};
    if (!$from || ! Email::Valid->address($from))
    {
	warn "Hebcal.pm: From $from is invalid"
	    if $verbose;
	return 0;
    }

    my(%recipients);
    foreach my $hdr ('To', 'Cc', 'Bcc')
    {
	if (defined $headers->{$hdr})
	{
	    foreach my $addr (split(/\s*,\s*/, $headers->{$hdr}))
	    {
		next unless $addr;
		next unless Email::Valid->address($addr);
		$recipients{Email::Valid->address($addr)} = 1;
	    }
	}
    }

    if (! keys %recipients)
    {
	warn "Hebcal.pm: no recipients!"
	    if $verbose;
	return 0;
    }

    unless ($CONFIG_INI) {
	$CONFIG_INI = Config::Tiny->read($CONFIG_INI_PATH)
	    or die "$CONFIG_INI_PATH: $!";
    }

    my $sendmail_host = $CONFIG_INI->{_}->{"hebcal.email.adhoc.host"};
    my $sendmail_user = $CONFIG_INI->{_}->{"hebcal.email.adhoc.user"};
    my $sendmail_pass = $CONFIG_INI->{_}->{"hebcal.email.adhoc.password"};

    my $smtp = Net::SMTP->new($sendmail_host, Timeout => 20);
    unless ($smtp) {
        return 0;
    }

    $smtp->auth($sendmail_user, $sendmail_pass);

    my $message = '';
    while (my($key,$val) = each %{$headers})
    {
	next if lc($key) eq 'bcc';
	while (chomp($val)) {}
	$message .= "$key: $val\n";
    }

    if (!$HOSTNAME) {
	$HOSTNAME = `/bin/hostname -f`;
	chomp($HOSTNAME);
    }

    if (! defined $headers->{'X-Sender'})
    {
	my($login) = getlogin() || getpwuid($<) || "UNKNOWN";
	$message .= "X-Sender: $login\@$HOSTNAME\n";
    }

    if (! defined $headers->{'X-Mailer'})
    {
	$message .= "X-Mailer: hebcal mail v4.13\n";
    }

    if (! defined $headers->{'Message-ID'})
    {
	$message .= "Message-ID: <HEBCAL." . time() . ".$$\@$HOSTNAME>\n";
    }

    $message .= "\n" . $body;

    my @recip = keys %recipients;

    $smtp->hello($HOSTNAME);
    unless ($smtp->mail($return_path)) {
        warn "smtp mail() failure for @recip\n"
	    if $verbose;
        return 0;
    }
    foreach (@recip) {
	next unless $_;
        unless($smtp->to($_)) {
            warn "smtp to() failure for $_\n"
		if $verbose;
            return 0;
        }
    }
    unless($smtp->data()) {
        warn "smtp data() failure for @recip\n"
	    if $verbose;
        return 0;
    }
    unless($smtp->datasend($message)) {
        warn "smtp datasend() failure for @recip\n"
	    if $verbose;
        return 0;
    }
    unless($smtp->dataend()) {
        warn "smtp dataend() failure for @recip\n"
	    if $verbose;
        return 0;
    }
    unless($smtp->quit) {
        warn "smtp quit failure for @recip\n"
	    if $verbose;
        return 0;
    }

    1;
}

# avoid warnings
if ($^W && 0)
{
    my $unused;
    $unused = $DBI::errstr;
}

1;
