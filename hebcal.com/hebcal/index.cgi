#!/usr/local/bin/perl -w

########################################################################
# Hebcal Interactive Jewish Calendar is a web site that lets you
# generate a list of Jewish holidays for any year. Candle lighting times
# are calculated from your latitude and longitude (which can be
# determined by your zip code or closest city).
#
# Copyright (c) 1999  Michael John Radwin.  All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
########################################################################

require 'cgi-lib.pl';
require 'timelocal.pl';
require 'ctime.pl';

$dbmfile = 'zips.db';
$dbmfile =~ s/\.db$//;

&CgiDie("Script Error: No Database", "\nThe database is unreadable.\n" .
	"Please <a href=\"mailto:michael\@radwin.org" .
	"\">e-mail Michael</a> to tell him that hebcal is broken.")
    unless -r "${dbmfile}.db";

$cgipath = '/hebcal/';
$rcsrev = '$Revision$'; #'
$rcsrev =~ s/\s*\$//g;

@DoW = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');

%valid_cities =
    (
     'Atlanta', 1,
     'Austin', 1,
     'Berlin', 1,
     'Baltimore', 1,
     'Bogota', 1,
     'Boston', 1,
     'Buenos Aires', 1,
     'Buffalo', 1,
     'Chicago', 1,
     'Cincinnati', 1,
     'Cleveland', 1,
     'Dallas', 1,
     'Denver', 1,
     'Detroit', 1,
     'Gibraltar', 1,
     'Hawaii', 1,
     'Houston', 1,
     'Jerusalem', 1,
     'Johannesburg', 1,
     'London', 1,
     'Los Angeles', 1,
     'Miami', 1,
     'Mexico City', 1,
     'New York', 1,
     'Omaha', 1,
     'Philadelphia', 1,
     'Phoenix', 1,
     'Pittsburgh', 1,
     'Saint Louis', 1,
     'San Francisco', 1,
     'Seattle', 1,
     'Toronto', 1,
     'Vancouver', 1,
     'Washington DC', 1,
     );

@MoY_abbrev = ('',
	       'jan','feb','mar','apr','may','jun',
	       'jul','aug','sep','oct','nov','dec');
@MoY = 
    ('',
     'January','Februrary','March','April','May','June',
     'July','August','September','October','November','December');

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
    localtime(time);
$year += 1900;

$html_header = "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\"
\t\"http://www.w3.org/TR/REC-html40/loose.dtd\">
<html><head>
<title>Hebcal Interactive Jewish Calendar</title>
<meta http-equiv=\"PICS-Label\" content='(PICS-1.1 \"http://www.rsac.org/ratingsv01.html\" l gen true by \"michael\@radwin.org\" on \"1998.03.10T11:49-0800\" r (n 0 s 0 v 0 l 0))'>
<meta name=\"description\" content=\"Generates a list of Jewish holidays and candle lighting times customized to your zip code, city, or latitude/longitude.\">
<meta name=\"keywords\" content=\"hebcal, Jewish calendar, Hebrew calendar, candle lighting, Shabbat, Havdalah, sedrot, Sadinoff\">
<link rev=\"made\" href=\"mailto:michael\@radwin.org\">
<meta name=\"DC.Title\" content=\"Hebcal Interactive Jewish Calendar\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#title\">
<meta name=\"DC.Creator.PersonalName\" content=\"Radwin, Michael\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#creator\">
<meta name=\"DC.Creator.PersonalName.Address\" content=\"michael@radwin.org\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#creator\">
<meta name=\"DC.Subject\" content=\"Jewish calendar\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#subject\">
<meta name=\"DC.Subject\" content=\"Hebrew calendar\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#subject\">
<meta name=\"DC.Subject\" content=\"hebcal\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#subject\">
<meta name=\"DC.Subject\" content=\"candle lighting\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#subject\">
<meta name=\"DC.Type\" content=\"Text.Form\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#type\">
<meta name=\"DC.Identifier\" content=\"http://www.radwin.org/hebcal/\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#identifier\">
<meta name=\"DC.Language\" scheme=\"ISO639-1\" content=\"en\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#language\">
<meta name=\"DC.Date.X-MetadataLastModified\" scheme=\"ISO8601\" content=\"1999-08-07\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#date\">
</head>
<body>";

$ENV{'TZ'} = 'PST8PDT';  # so ctime displays the time zone
$hhmts = "<!-- hhmts start -->
Last modified: Sat Sep 18 18:12:27 PDT 1999
<!-- hhmts end -->";

$hhmts =~ s/<!--.*-->//g;
$hhmts =~ s/\n//g;
$hhmts =~ s/Last modified: /Software last updated: /g;
$hhmts = 'This page generated: ' . &ctime(time) . '<br>' . $hhmts;

$html_footer = "<hr noshade size=\"1\">
<small>$hhmts ($rcsrev)
<p>Copyright &copy; $year Michael John Radwin. All rights
reserved.<br><a href=\"/michael/projects/hebcal/\">About this
service</a>.</small>
</body></html>
";

&ReadParse();

while (($key,$val) = each(%in))
{
    $val =~ s/[^\w\s-]//g;
    $in{$key} = $val;
}

$year = $in{'year'}
    if (defined $in{'year'} && $in{'year'} =~ /^\d+$/ && $in{'year'} > 0);

# timezone opt
for ($i = -12; $i < 13; $i++)
{
    $tz{$i} = '';
}
if (defined $in{'tz'})
{
    $tz{$in{'tz'}} = ' selected';
}
elsif (defined $in{'geo'} && $in{'geo'} eq 'pos')
{
    $tz{'0'} = ' selected';
}

# month opt
for ($i = 0; $i < 13; $i++)
{
    $month{$i} = '';
}
if (defined $in{'month'} && $in{'month'} ne '')
{
    $month{$in{'month'}} = ' selected';
}
else
{
#    $month{$mon + 1} = ' selected';
    $month{'0'} = ' selected';
}

# boolean options
@opts = ('c','x','o','s','i','h','a','d','usa','israel','none');
%opts = ();

foreach (@opts)
{
    $opts{$_}     = (defined $in{$_} && ($in{$_} eq 'on' || $in{$_} eq '1')) ?
	1 : 0;
}

if (defined $in{'dst'})
{
    $opts{'usa'}    = ($in{'dst'} eq 'usa') ? 1 : 0;
    $opts{'israel'} = ($in{'dst'} eq 'israel') ? 1 : 0;
    $opts{'none'}   = ($in{'dst'} eq 'none') ? 1 : 0;
}
elsif (defined $in{'geo'} && $in{'geo'} eq 'pos')
{
    $opts{'none'}   = 1;
}
else
{
    $opts{'usa'}    = 1;
}

foreach (@opts)
{
    $opts_chk{$_} = $opts{$_} ? ' checked' : '';
}

$havdalah = 72;
$havdalah = $in{'m'} if (defined $in{'m'} && $in{'m'} =~ /^\d+$/);

if (! defined $in{'zip'} &&
    ! defined $in{'city'} &&
    ! defined $in{'v'} &&
    (! defined $in{'lodeg'} ||
     ! defined $in{'lomin'} ||
     ! defined $in{'lodir'} ||
     ! defined $in{'ladeg'} ||
     ! defined $in{'lamin'} ||
     ! defined $in{'ladir'}))
{
    $in{'zip'} = '';
    &form('');
}
    
$cmd  = "/home/users/mradwin/bin/hebcal";

if (defined $in{'city'} && $in{'city'} !~ /^\s*$/)
{
    &form("<p><em><font color=\"#ff0000\">Sorry, invalid city\n" .
	  $in{'city'} . ".</font></em></p>")
	unless defined($valid_cities{$in{'city'}});

    $cmd .= " -C '$in{'city'}'";

    $city_descr = "Closest City: $in{'city'}";
    $lat_descr  = '';
    $long_descr = '';
    $dst_tz_descr = '';

    delete $in{'tz'};
    delete $in{'dst'};
}
elsif (defined $in{'lodeg'} && defined $in{'lomin'} && defined $in{'lodir'} &&
       defined $in{'ladeg'} && defined $in{'lamin'} && defined $in{'ladir'})
{
    &form("<p><em><font color=\"#ff0000\">Sorry, all latitude/longitude\n" .
	  "arguments must be numeric.</font></em></p>")
	if (($in{'lodeg'} !~ /^\s*\d*\s*$/) ||
	    ($in{'lomin'} !~ /^\s*\d*\s*$/) ||
	    ($in{'ladeg'} !~ /^\s*\d*\s*$/) ||
	    ($in{'lamin'} !~ /^\s*\d*\s*$/));

    ($long_deg) = ($in{'lodeg'} =~ /^\s*(\d+)\s*$/);
    ($long_min) = ($in{'lomin'} =~ /^\s*(\d+)\s*$/);
    ($lat_deg)  = ($in{'ladeg'} =~ /^\s*(\d+)\s*$/);
    ($lat_min)  = ($in{'lamin'} =~ /^\s*(\d+)\s*$/);

    $long_deg   = 0 unless defined $long_deg;
    $long_min   = 0 unless defined $long_min;
    $lat_deg    = 0 unless defined $lat_deg;
    $lat_min    = 0 unless defined $lat_min;

    $in{'lodir'} = 'w' unless ($in{'lodir'} eq 'e');
    $in{'ladir'} = 'n' unless ($in{'ladir'} eq 's');

    $in{'lodeg'} = $long_deg;
    $in{'lomin'} = $long_min;
    $in{'ladeg'} = $lat_deg;
    $in{'lamin'} = $lat_min;

    &form("<p><em><font color=\"#ff0000\">Sorry, longitude degrees\n" .
	  "<b>$in{'lodeg'}</b> out of valid range 0-180.</font></em></p>")
	if ($in{'lodeg'} > 180);

    &form("<p><em><font color=\"#ff0000\">Sorry, latitude degrees\n" .
	  "<b>$in{'ladeg'}</b> out of valid range 0-90.</font></em></p>")
	if ($in{'ladeg'} > 90);

    &form("<p><em><font color=\"#ff0000\">Sorry, longitude minutes\n" .
	  "<b>$in{'lomin'}</b> out of valid range 0-60.</font></em></p>")
	if ($in{'lomin'} > 60);

    &form("<p><em><font color=\"#ff0000\">Sorry, latitude minutes\n" .
	  "<b>$in{'lamin'}</b> out of valid range 0-60.</font></em></p>")
	if ($in{'lamin'} > 60);

    $city_descr = "Geographic Position";
    $lat_descr  = "${lat_deg}d${lat_min}' \U$in{'ladir'}\E latitude";
    $long_descr = "${long_deg}d${long_min}' \U$in{'lodir'}\E longitude";
    $dst_tz_descr =
"Daylight Savings Time: $in{'dst'}</small>\n<dd><small>Time Zone: GMT $in{'tz'}:00";

    # don't multiply minutes by -1 since hebcal does it internally
    $long_deg *= -1  if ($in{'lodir'} eq 'e');
    $lat_deg  *= -1  if ($in{'ladir'} eq 's');

    $cmd .= " -L $long_deg,$long_min -l $lat_deg,$lat_min";
}
elsif (defined $in{'zip'})
{
    $in{'dst'} = 'usa' unless defined $in{'dst'};

    &form("<p><em><font color=\"#ff0000\">Please specify a 5-digit\n" .
	  "zip code.</font></em></p>")
	if $in{'zip'} =~ /^\s*$/;

    &form("<p><em><font color=\"#ff0000\">Sorry, <b>" .
	  $in{'zip'} . "</b> does\n" .
	  "not appear to be a 5-digit zip code.</font></em></p>")
	unless $in{'zip'} =~ /^\d\d\d\d\d$/;

    dbmopen(%DB,$dbmfile, 0400) ||
	&CgiDie("Script Error: Database Unavailable",
		"\nThe database is unavailable right now.\n" .
		"Please <a href=\"${cgipath}?" .
		$ENV{'QUERY_STRING'} . "\">try again</a>.");

    $val = $DB{$in{'zip'}};
    dbmclose(%DB);

    &form("<p><em><font color=\"#ff0000\">Sorry, can't find\n".
	  "<b>" . $in{'zip'} . 
	  "</b> in the zip code database.</font></em><br>\n" .
          "Please try a nearby zip code or select candle lighting times by\n" .
          "<a href=\"${cgipath}?c=on&amp;geo=city\">city</a> or\n" .
          "<a href=\"${cgipath}?c=on&amp;geo=pos\">latitude/longitude</a></p>")
	unless defined $val;

    ($long_deg,$long_min,$lat_deg,$lat_min) = unpack('ncnc', $val);
    ($city,$state) = split(/\0/, substr($val,6));

    @city = split(/([- ])/, $city);
    $city = '';
    foreach (@city)
    {
	$_ = "\L$_\E";
	$_ = "\u$_";
	$city .= $_;
    }
    undef(@city);

    $city_descr = "$city, $state &nbsp;$in{'zip'}";
    $lat_descr  = "${lat_deg}d${lat_min}' N latitude";
    $long_descr = "${long_deg}d${long_min}' W longitude";
    $dst_tz_descr =
"Daylight Savings Time: $in{'dst'}</small>\n<dd><small>Time Zone: GMT $in{'tz'}:00";

    $cmd .= " -L $long_deg,$long_min -l $lat_deg,$lat_min";
}

foreach (@opts)
{
    $cmd .= ' -' . $_ if $opts{$_} && length($_) == 1;
}

$cmd .= " -m $in{'m'}" if (defined $in{'m'} && $in{'m'} =~ /^\d+$/);

if (defined $in{'tz'} && $in{'tz'} ne '')
{
    $cmd .= " -z $in{'tz'}";
}

if (defined $in{'dst'} && $in{'dst'} ne '')
{
    $cmd .= " -Z $in{'dst'}";
}

if (defined $in{'month'} && $in{'month'} ne '')
{
    $cmd .= " $in{'month'}";
}

$cmd .= " $year";


&results_page() unless defined $ENV{'PATH_INFO'};

open(HEBCAL,"$cmd |") ||
    &CgiDie("Script Error: can't run hebcal",
	    "\nCommand was \"$cmd\".\n" .
	    "Please <a href=\"mailto:michael\@radwin.org" .
	    "\">e-mail Michael</a> to tell him that hebcal is broken.");

$endl = "\012";			# default Netscape and others
if (defined $ENV{'HTTP_USER_AGENT'} && $ENV{'HTTP_USER_AGENT'} !~ /^\s*$/)
{
    $endl = "\015\012"
	if $ENV{'HTTP_USER_AGENT'} =~ /Microsoft Internet Explorer/;
    $endl = "\015\012" if $ENV{'HTTP_USER_AGENT'} =~ /MSP?IM?E/;
}

local($time) = defined $ENV{'SCRIPT_FILENAME'} ?
    (stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

print STDOUT "Last-Modified: ", &http_date($time), "\015\012";
print STDOUT "Expires: Fri, 31 Dec 2010 23:00:00 GMT\015\012";
if ($endl eq "\012")
{
    print STDOUT "Content-Type: text/x-csv\015\012\015\012";
}
else
{
    print STDOUT "Content-Type: text/plain\015\012\015\012";
}

print STDOUT "\"Subject\",\"Start Date\",\"Start Time\",\"End Date\",\"End Time\",\"All day event\",\"Description\"$endl";

$prev = '';
local($loc) = defined $in{'city'} ? "in $in{'city'}" :
    defined $in{'zip'} ? "in $in{'zip'}" : '';
while(<HEBCAL>)
{
    next if $_ eq $prev;
    $prev = $_;
    chop;
    ($date,$descr) = split(/ /, $_, 2);

    ($subj,$date,$start_time,$end_date,$end_time,$all_day)
	= &parse_date_descr($date,$descr);

    print STDOUT "\"$subj\",\"$date\",$start_time,$end_date,$end_time,$all_day,";
    print STDOUT "\"", ($start_time eq '' ? '' : $loc), "\"$endl";
}
close(HEBCAL);
close(STDOUT);

exit(0);


sub form
{
    local($message) = @_;
    local($time) = defined $ENV{'SCRIPT_FILENAME'} ?
	(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;
    local($key,$val);

    print STDOUT "Last-Modified: ", &http_date($time), "\015\012";
    print STDOUT "Content-Type: text/html\015\012\015\012";

    print STDOUT "$html_header
<div class=\"navbar\"><small><a href=\"/\">radwin.org</a> <tt>-&gt;</tt>
hebcal</small></div><h1>Hebcal Interactive Jewish Calendar</h1>
<p>Use the form below to generate a list of Jewish holidays. Candle
lighting times are calculated from your latitude and longitude (which
can be determined by your zip code or closest city).</p>
";

print STDOUT "<hr noshade size=\"1\">
$message
<form action=\"$cgipath\">
<label for=\"year\">Year: <input name=\"year\"
id=\"year\" value=\"$year\" size=\"4\" maxlength=\"4\"></label>
<input type=\"hidden\" name=\"v\" value=\"1\">
&nbsp;&nbsp;&nbsp;
<label for=\"month\">Month:
<select name=\"month\" id=\"month\">
<option value=\"\"$month{'0'}>- entire year -
";
    for ($i = 1; $i < 13; $i++)
    {
	print STDOUT "<option value=\"$i\"$month{$i}>$MoY[$i]\n";
    }
    print STDOUT "</select></label>
<br>
<small>
Use all digits to specify a year. You probably aren't
interested in 93, but rather 1993.
</small>
<br><br>
";

    if ($opts{'c'} == 0)
    {
	print STDOUT
"(Candle lighting times are off.  Turn them on for:
<a href=\"${cgipath}?c=on\">zip code</a>,
<a href=\"${cgipath}?c=on&geo=city\">closest city</a>, or
<a href=\"${cgipath}?c=on&geo=pos\">latitude/longitude</a>.)
<br><br>
";
    }
    else
    {
	print STDOUT 
"<input type=\"hidden\" name=\"c\" value=\"on\">
Include candle lighting times for ";
	if (defined $in{'geo'})
	{
	    print STDOUT "zip code:\n"
		if ($in{'geo'} eq 'zip');
	    print STDOUT "closest city:\n"
		if ($in{'geo'} eq 'city');
	    print STDOUT "latitude/longitude:\n"
		if ($in{'geo'} eq 'pos');
	}
	else
	{
	    print STDOUT "zip code:\n";
	}
	print STDOUT
"<br><small>(or <a href=\"${cgipath}\">turn them off</a>, or select by";
	if (defined $in{'geo'} && $in{'geo'} eq 'city')
	{
	    print STDOUT " <a\nhref=\"${cgipath}?c=on\">zip code</a> or";
	    print STDOUT " <a\nhref=\"${cgipath}?c=on&amp;geo=pos\">latitude/longitude</a>";
	}
	elsif (defined $in{'geo'} && $in{'geo'} eq 'pos')
	{
	    print STDOUT " <a\nhref=\"${cgipath}?c=on\">zip code</a> or";
	    print STDOUT " <a\nhref=\"${cgipath}?c=on&amp;geo=city\">closest city</a>"
	}
	else
	{
	    print STDOUT " <a
href=\"${cgipath}?c=on&amp;geo=city\">closest city</a> or <a
href=\"${cgipath}?c=on&amp;geo=pos\">latitude/longitude</a>";
	}
	print STDOUT ")</small>
<br>
<blockquote>";

    if (defined $in{'geo'} && $in{'geo'} eq 'city')
    {
	print STDOUT "
<input type=\"hidden\" name=\"geo\" value=\"city\">
<label for=\"city\">Closest City:
";

	print STDOUT "<select name=\"city\" id=\"city\">\n";
	foreach (sort keys %valid_cities)
	{
	    print STDOUT '<option';
	    print STDOUT ' selected' if 'Jerusalem' eq $_;
	    print STDOUT ">$_\n";
	}
	print STDOUT "</select>\n";

	print STDOUT "</label><br>\n";
    }
    elsif (defined $in{'geo'} && $in{'geo'} eq 'pos')
    {
	print STDOUT "
<input type=\"hidden\" name=\"geo\" value=\"pos\">
<label for=\"ladeg\"><input name=\"ladeg\" id=\"ladeg\" value=\"$in{'ladeg'}\"
size=\"3\" maxlength=\"2\">&nbsp;deg</label>&nbsp;&nbsp;<label
for=\"lamin\"><input name=\"lamin\" id=\"lamin\" value=\"$in{'lamin'}\"
size=\"2\" maxlength=\"2\">&nbsp;min</label>&nbsp;<select
name=\"ladir\">";
print STDOUT "<option\nvalue=\"n\"",
	($in{'ladir'} eq 'n' ? ' selected' : ''), ">North Latitude";
print STDOUT "<option\nvalue=\"s\"",
	($in{'ladir'} eq 's' ? ' selected' : ''), ">South Latitude";

print STDOUT "</select><br>
<label for=\"lodeg\"><input name=\"lodeg\" id=\"lodeg\" value=\"$in{'lodeg'}\"
size=\"3\" maxlength=\"3\">&nbsp;deg</label>&nbsp;&nbsp;<label
for=\"lomin\"><input name=\"lomin\" id=\"lomin\" value=\"$in{'lomin'}\"
size=\"2\" maxlength=\"2\">&nbsp;min</label>&nbsp;<select
name=\"lodir\">";

print STDOUT "<option\nvalue=\"w\"",
	($in{'lodir'} eq 'w' ? ' selected' : ''), ">West Longitude";
print STDOUT "<option\nvalue=\"e\"",
	($in{'lodir'} eq 'e' ? ' selected' : ''), ">East Longitude";
print STDOUT "</select><br>
";
    }
    else
    {
	print STDOUT "
<input type=\"hidden\" name=\"geo\" value=\"zip\">
<label for=\"zip\">Zip code: <input name=\"zip\"
id=\"zip\" value=\"$in{'zip'}\" size=\"5\" maxlength=\"5\"></label><br>
";
    }

    if (!defined $in{'geo'} || $in{'geo'} ne 'city')
    {
	print STDOUT "<label for=\"tz\">Time Zone:
<select name=\"tz\" id=\"tz\">
<option value=\"-5\"$tz{'-5'}>GMT -05:00 (Eastern)
<option value=\"-6\"$tz{'-6'}>GMT -06:00 (Central)
<option value=\"-7\"$tz{'-7'}>GMT -07:00 (Mountain)
<option value=\"-8\"$tz{'-8'}>GMT -08:00 (Pacific)
<option value=\"-9\"$tz{'-9'}>GMT -09:00 (Alaskan)
<option value=\"-10\"$tz{'-10'}>GMT -10:00 (Hawaii)
";

    print STDOUT
"<option value=\"-11\"$tz{'-11'}>GMT -11:00
<option value=\"-12\"$tz{'-12'}>GMT -12:00
<option value=\"12\"$tz{'12'}>GMT +12:00
<option value=\"11\"$tz{'11'}>GMT +11:00
<option value=\"10\"$tz{'10'}>GMT +10:00
<option value=\"9\"$tz{'9'}>GMT +09:00
<option value=\"8\"$tz{'8'}>GMT +08:00
<option value=\"7\"$tz{'7'}>GMT +07:00
<option value=\"6\"$tz{'6'}>GMT +06:00
<option value=\"5\"$tz{'5'}>GMT +05:00
<option value=\"4\"$tz{'4'}>GMT +04:00
<option value=\"3\"$tz{'3'}>GMT +03:00
<option value=\"2\"$tz{'2'}>GMT +02:00
<option value=\"1\"$tz{'1'}>GMT +01:00
<option value=\"0\"$tz{'0'}>Greenwich Mean Time
<option value=\"-1\"$tz{'-1'}>GMT -01:00
<option value=\"-2\"$tz{'-2'}>GMT -02:00
<option value=\"-3\"$tz{'-3'}>GMT -03:00
<option value=\"-4\"$tz{'-4'}>GMT -04:00
"
    if (defined $in{'geo'} && $in{'geo'} eq 'pos');

    print STDOUT
"</select></label><br>
Daylight Savings Time:
<label for=\"usa\">
<input type=\"radio\" name=\"dst\" id=\"usa\" value=\"usa\"$opts_chk{'usa'}>
USA</label>
<label for=\"israel\">
<input type=\"radio\" name=\"dst\" id=\"israel\" value=\"israel\"$opts_chk{'israel'}>
Israel</label>
<label for=\"none\">
<input type=\"radio\" name=\"dst\" id=\"none\" value=\"none\"$opts_chk{'none'}>
none</label><br>
";
    }

print STDOUT "<label for=\"m\">Havdalah minutes past sundown: <input
name=\"m\" id=\"m\" value=\"$havdalah\" size=\"3\"
maxlength=\"3\"></label><br>
</blockquote>
";
}
print STDOUT
"<small>
<label for=\"a\"><input type=\"checkbox\" name=\"a\" id=\"a\"$opts_chk{'a'}>
Use ashkenazis hebrew</label><br>
<label for=\"x\"><input type=\"checkbox\" name=\"x\" id=\"x\"$opts_chk{'x'}>
Suppress Rosh Chodesh</label><br>
<label for=\"h\"><input type=\"checkbox\" name=\"h\" id=\"h\"$opts_chk{'h'}>
Suppress all default holidays</label><br>
<label for=\"o\"><input type=\"checkbox\" name=\"o\" id=\"o\"$opts_chk{'o'}>
Add days of the Omer</label><br>
<label for=\"s\"><input type=\"checkbox\" name=\"s\" id=\"s\"$opts_chk{'s'}>
Add weekly sedrot on Saturday</label>
(<label for=\"i\"><input type=\"checkbox\" name=\"i\" id=\"i\"$opts_chk{'i'}>
Use Israeli sedra scheme</label>)<br>
<label for=\"d\"><input type=\"checkbox\" name=\"d\" id=\"d\"$opts_chk{'d'}>
Print hebrew date for the entire date range</label></small><br>
<br><input type=\"submit\" value=\"Get Calendar\">
</form>
$html_footer";

    close(STDOUT);
    exit(0);

    1;
}



sub results_page
{
    local($date) = $year;
    local($filename) = 'hebcal_' . $year;
    local($ycal) = (defined($in{'y'}) && $in{'y'} eq '1') ? 1 : 0;
    local($prev_url,$next_url,$prev_title,$next_title);

    if ($in{'month'} =~ /^\d+$/)
    {
	$filename .= '_' . $MoY_abbrev[$in{'month'}];
	$date = $MoY[$in{'month'}] . ' ' . $date;
    }

    if ($opts{'c'} == 1)
    {
	$filename .= '_';
	if (defined $in{'zip'})
	{
	    $filename .= $in{'zip'};
	}
	elsif (defined $in{'city'})
	{
	    $tmp = "\L$in{'city'}\E";
	    $tmp =~ s/ /_/g;
	    $filename .= $tmp;
	}
    }

    $filename .= '.csv';

    local($time) = defined $ENV{'SCRIPT_FILENAME'} ?
	(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

    # next and prev urls
    if ($in{'month'} =~ /^\d+$/)
    {
	local($pm,$nm,$py,$ny);

	if ($in{'month'} == 1)
	{
	    $pm = 12;
	    $nm = 2;
	    $py = $year - 1;
	    $ny = $year;
	}
	elsif ($in{'month'} == 12)
	{
	    $pm = 11;
	    $nm = 1;
	    $py = $year;
	    $ny = $year + 1;
	}
	else
	{
	    $pm = $in{'month'} - 1;
	    $nm = $in{'month'} + 1;
	    $ny = $py = $year;
	}

	$prev_url = "$cgipath?year=" . $py . "&amp;month=" . $pm;
	while (($key,$val) = each(%in))
	{
	    $prev_url .= "&amp;$key=" . &url_escape($val)
		unless $key eq 'year' || $key eq 'month';
	}
	$prev_title = $MoY[$pm] . " " . $py;

	$next_url = "$cgipath?year=" . $ny . "&amp;month=" . $nm;
	while (($key,$val) = each(%in))
	{
	    $next_url .= "&amp;$key=" . &url_escape($val)
		unless $key eq 'year' || $key eq 'month';
	}
	$next_title = $MoY[$nm] . " " . $ny;
    }
    else
    {
	$prev_url = "$cgipath?year=" . ($year - 1);
	while (($key,$val) = each(%in))
	{
	    $prev_url .= "&amp;$key=" . &url_escape($val)
		unless $key eq 'year';
	}
	$prev_title = ($year - 1);

	$next_url = "$cgipath?year=" . ($year + 1);
	while (($key,$val) = each(%in))
	{
	    $next_url .= "&amp;$key=" . &url_escape($val)
		unless $key eq 'year';
	}
	$next_title = ($year + 1);
    }

    print STDOUT "Last-Modified: ", &http_date($time), "\015\012";
    print STDOUT "Expires: Fri, 31 Dec 2010 23:00:00 GMT\015\012";
    print STDOUT "Content-Type: text/html\015\012\015\012";

    print STDOUT "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\"
\t\"http://www.w3.org/TR/REC-html40/loose.dtd\">
<html><head>
<title>Hebcal: Jewish Calendar $date</title>
<meta http-equiv=\"PICS-Label\" content='(PICS-1.1 \"http://www.rsac.org/ratingsv01.html\" l gen true by \"michael\@radwin.org\" on \"1998.03.10T11:49-0800\" r (n 0 s 0 v 0 l 0))'>
<meta name=\"robots\" content=\"noindex\">
<link rel=\"start\" href=\"$cgipath\" title=\"Hebcal Interactive Jewish Calendar\">
<link rel=\"prev\" href=\"$prev_url\" title=\"$prev_title\">
<link rel=\"next\" href=\"$next_url\" title=\"$next_title\">
</head>
<body>
<div class=\"navbar\"><small><a href=\"/\">radwin.org</a> <tt>-&gt;</tt>
<a href=\"$cgipath\">hebcal</a> <tt>-&gt;</tt>
$date</small></div><h1>Jewish Calendar $date</h1>
";

    if ($opts{'c'} == 1)
    {
	print STDOUT "<dl>\n<dt>", $city_descr, "\n";
	print STDOUT "<dd><small>", $lat_descr, "</small>\n" if $lat_descr ne '';
	print STDOUT "<dd><small>", $long_descr, "</small>\n" if $long_descr ne '';
	print STDOUT "<dd><small>", $dst_tz_descr, "</small>\n" if $dst_tz_descr ne '';
	print STDOUT "</dl>\n";
    }

    print STDOUT "Go to:\n";
    print STDOUT "<a href=\"$prev_url\">", $prev_title, "</a> |\n";
    print STDOUT "<a href=\"$next_url\">", $next_title, "</a><br>\n";

    if ($ycal == 0)
    {
	print STDOUT "<a href=\"$cgipath?y=1";
	while (($key,$val) = each(%in))
	{
	    print STDOUT "&amp;$key=", &url_escape($val);
	}
	print STDOUT "\">Show Yahoo! Calendar links</a>\n";
    }

    print STDOUT "<div><form action=\"${cgipath}index.html/$filename\">\n";
    while (($key,$val) = each(%in))
    {
	print STDOUT "<input type=\"hidden\" name=\"$key\" value=\"", 
	   $val, "\">\n";
    }
    print STDOUT
"<input type=\"submit\" value=\"Download as an Outlook CSV file\">
</form></div>
";

    print STDOUT
"<p><small>Use the \"add\" links below to add a holiday to your personal
<a href=\"http://calendar.yahoo.com/\">Yahoo! Calendar</a>, a free
web-based calendar that can synchronize with Palm Pilot, Outlook, etc.
These links will pop up a new browser window so you can keep this window
open.</small></p>
" if $ycal;

    $cmd_pretty = $cmd;
    $cmd_pretty =~ s,.*/,,; # basename
    print STDOUT "<!-- $cmd_pretty -->\n";
    print STDOUT "<pre>\n";
    open(HEBCAL,"$cmd |") ||
	&CgiDie("Script Error: can't run hebcal",
		"\nCommand was \"$cmd\".\n" .
		"Please <a href=\"mailto:michael\@radwin.org" .
		"\">e-mail Michael</a> to tell him that hebcal is broken.");

    $prev = '';
    while(<HEBCAL>)
    {
	next if $_ eq $prev;
	$prev = $_;
	chop;
	($date,$descr) = split(/ /, $_, 2);
	($subj,$date,$start_time,$end_date,$end_time,$all_day,
	 $hr,$min,$month,$day,$year) =
	     &parse_date_descr($date,$descr);

	if ($ycal)
	{
	    $ST  = sprintf("%04d%02d%02d", $year, $month, $day);
	    if ($hr >= 0 && $min >= 0)
	    {
	        local($loc) = defined $in{'city'} ? $in{'city'} :
	                      defined $in{'zip'} ? $in{'zip'} : '';
		$hr += 12 if $hr < 12 && $hr > 0;
		$ST .= sprintf("T%02d%02d00", $hr, $min);
		$ST .= "&amp;DESC=" . &url_escape("in $loc");
	    }

	    print STDOUT
		"<a target=\"_calendar\" href=\"http://calendar.yahoo.com/";
	    print STDOUT "?v=60&amp;TYPE=16&amp;ST=$ST&amp;TITLE=",
		&url_escape($subj), "&amp;VIEW=d\">add</a> ";
	}

	$descr =~ s/&/&amp;/g;
	$descr =~ s/</&lt;/g;
	$descr =~ s/>/&gt;/g;

	$dow = ($year > 1969 && $year < 2038) ? 
	    $DoW[&get_dow($year - 1900, $month - 1, $day)] . ' ' :
		'';
	printf STDOUT "%s%04d-%02d-%02d  %s\n",
	$dow, $year, $month, $day, $descr;
    }
    close(HEBCAL);

    print STDOUT "</pre>", $html_footer;

    close(STDOUT);
    exit(0);

    1;
}

sub get_dow
{
    local($year,$mon,$mday) = @_;
    local($sec,$min,$hour,$wday,$yday,$isdst);
    local($time);

    $wday = $yday = $isdst = '';
    $sec = $min = $hour = 0;
    $time = &timelocal($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);

    (localtime($time))[6];
}

sub parse_date_descr
{
    local($date,$descr) = @_;

    ($month,$day,$year) = split(/\//, $date);
    if ($descr =~ /^(.+)\s*:\s*(\d+):(\d+)\s*$/)
    {
	($subj,$hr,$min) = ($1,$2,$3);
	$start_time = sprintf("\"%d:%02d PM\"", $hr, $min);
#	$min += 15;
#	if ($min >= 60)
#	{
#	    $hr++;
#	    $min -= 60;
#	}
#	$end_time = sprintf("\"%d:%02d PM\"", $hr, $min);
#	$end_date = $date;
	$end_time = $end_date = '';
	$all_day = '"false"';
    }
    else
    {
	$hr = $min = -1;
	$start_time = $end_time = $end_date = '';
	$all_day = '"true"';
	$subj = $descr;
    }
    
    $subj =~ s/\"/''/g;
    $subj =~ s/\s*:\s*$//g;

    ($subj,$date,$start_time,$end_date,$end_time,$all_day,
     $hr,$min,$month,$day,$year);
}

sub url_escape
{
    local($_) = @_;
    local($res) = '';

    foreach (split(//))
    {
	if (/ /)
	{
	    $res .= '+';
	}
	elsif (/[^a-zA-Z0-9_.-]/)
	{
	    $res .= sprintf("%%%02X", ord($_));
	}
	else
	{
	    $res .= $_;
	}
    }

    $res;
}

sub http_date
{
    local($time) = @_;
    local(@MoY);
    local($sec,$min,$hour,$mday,$mon,$year,$wday) =
	gmtime($time);

    @MoY = ('Jan','Feb','Mar','Apr','May','Jun',
	    'Jul','Aug','Sep','Oct','Nov','Dec');
    $year += 1900;

    sprintf("%s, %02d %s %4d %02d:%02d:%02d GMT",
	    $DoW[$wday],$mday,$MoY[$mon],$year,$hour,$min,$sec);
}

if ($^W && 0)
{
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime(time);
}

1;
