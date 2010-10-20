<?php
require "../pear/Hebcal/common.inc";
header("Content-Type: text/html; charset=UTF-8");
$VER = '$Revision$';
$matches = array();
if (preg_match('/(\d+)/', $VER, $matches)) {
    $VER = $matches[1];
}
$xtra_head = <<<EOD
<style type="text/css">
#hebcal-ical tr td {
  padding: 8px;
  vertical-align: middle;
}
</style>
EOD;
echo html_header_new("Jewish Calendar downloads for Apple iCal", $xtra_head);
?>
<div id="container" class="single-attachment">
<div id="content" role="main">
<div class="page type-page hentry">
<h1 class="entry-title">Jewish Calendar downloads for Apple iCal</h1>
<div class="entry-content">

<h2>Quick Start</h2>

<p>Jewish holidays for 2007-2016 are available to <a
href="http://www.apple.com/support/ical/">Apple iCal</a> or to
any desktop program that supports iCalendar files. These holidays are
for Jews living in the Diaspora (anywhere outside of modern Israel).</p>

<?php
function cal_row($path,$title,$subtitle) {
    $webcal = "webcal://" . $_SERVER["HTTP_HOST"] . $path;
    $webcal_esc = urlencode($webcal);
    $http_esc = urlencode("http://" . $_SERVER["HTTP_HOST"] . $path);
?>
<tr>
<td><a title="Subscribe to <?php echo $title ?> in iCal"
href="<?php echo $webcal ?>"><img
src="/i/ical-64x64.png" width="64" height="64"
alt="Subscribe to <?php echo $title ?> in iCal"
border="0"></a></td>
<td align="center"><a
title="Add <?php echo $title ?> to Windows Live Calendar"
href="http://calendar.live.com/calendar/calendar.aspx?rru=addsubscription&url=<?php echo $webcal_esc ?>&name=<?php echo urlencode($title) ?>"><img
src="/i/wlive-150x20.png"
width="150" height="20" border="0"
alt="Add <?php echo $title ?> to Windows Live Caledar"></a>
</td>
<td align="center"><a
title="Add <?php echo $title ?> to Google Calendar"
href="http://www.google.com/calendar/render?cid=<?php echo $http_esc ?>"><img
src="http://www.google.com/calendar/images/ext/gc_button6.gif"
width="114" height="36" border="0"
alt="Add <?php echo $title ?> to Google Calendar"></a>
</td>
<td><b><big><?php echo $title ?></big></b>
<br><?php echo $subtitle ?></td>
</tr>
<?php
}
?>
<table id="hebcal-ical" cellpadding="5">
<?php
cal_row("/ical/jewish-holidays.ics", "Jewish Holidays",
	"Major holidays such as Rosh Hashana, Yom Kippur, Passover, Hanukkah");
cal_row("/ical/jewish-holidays-all.ics", "Jewish Holidays (all)",
	"Also includes Rosh Chodesh, minor fasts, and special Shabbatot");
cal_row("/ical/hdate-en.ics", "Hebrew calendar dates (English transliteration)",
	"Displays the Hebrew date (such as <b>18th of Tevet, 5770</b>) every day of the week");
cal_row("/ical/hdate-he.ics", "Hebrew calendar dates (Hebrew)",
	"Displays the Hebrew date (such as <b>י״ח בטבת תש״ע</b>) every day of the week");
?>
</table>

<h2>Customizing your iCal feed</h2>

<p>To get a customized iCal feed with candle lighting times for Shabbat
and holidays, Torah readings, etc, follow these instructions:</p>

<ol>
<li>Go to <a
    href="http://www.hebcal.com/hebcal/">http://www.hebcal.com/hebcal/</a>
<li>Fill out the form with your preferences and click the "Get
    Calendar" button
<li>Click on the "Export calendar to Outlook, Apple iCal, Google, Palm,
    etc." link
<li>Click on the "subscribe" link in the "Apple iCal (and other
    iCalendar-enabled applications)" section
<li><a href="http://www.apple.com/support/ical/">Apple iCal</a>
    will start up
<li>Click <b>Subscribe</b> in the "Subscribe to:" dialog box
<li>Click <b>OK</b> in the next dialog box
</ol>

</div><!-- .entry-content -->
</div><!-- #post-## -->
</div><!-- #content -->
</div><!-- #container -->
<?php echo html_footer_new(); ?>
