<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html lang="en">
<head><title>Hebcal 1-Click Shabbat by Email</title>
<base href="http://www.hebcal.com/email/" target="_top">
<link type="text/css" rel="stylesheet" href="/style.css">
<link type="text/css" media="print" rel="stylesheet" href="/print.css">
<link href="mailto:webmaster@hebcal.com" rev="made">
</head><body><table width="100%"
class="navbar"><tr><td><small><strong><a
href="/">hebcal.com</a></strong>
<tt>-&gt;</tt>
<a href="/shabbat/">1-Click Shabbat</a>
<tt>-&gt;</tt>
Email</small></td><td align="right"><small><a
href="/help/">Help</a> -
<a href="/search/">Search</a></small>
</td></tr></table><h1>1-Click Shabbat by Email</h1>
<?
require_once('smtp.inc');
require_once('zips.inc');

global $HTTP_GET_VARS;
$param = array();
foreach($HTTP_GET_VARS as $key => $value) {
    $param[$key] = $value;
}

if ($param[$key])
{
    $email = $param["em"];
    if (!$email)
    {
	form($param,
	     "Please enter your email address.");
    }

    $to_addr = email_address_valid($email);
    if ($to_addr == false) {
	form($param,
	     "Sorry, <b>" . htmlspecialchars($email) . "</b> does\n" .
	     "not appear to be a valid email address.");
    }

    // email is OK, write canonicalized version
    $email = $to_addr;
    
    $param['em'] = strtolower($email);
}
else
{
    form($param);
}

if ($param['submit_modify']) {
    subscribe($param);
}
elseif ($param['submit_unsubscribe']) {
    unsubscribe($param);
}
else {
    form($param);
}
my_footer();

function my_footer() {
?>
<hr noshade size="1"><font size="-2" face="Arial">
<a name="copyright">Copyright &copy; 2001
Michael J. Radwin. All rights reserved.</a>
<a target="_top" href="http://www.hebcal.com/privacy/">Privacy Policy</a> -
<a target="_top" href="http://www.hebcal.com/help/">Help</a> -
<a target="_top" href="http://www.hebcal.com/contact/">Contact</a>
<br>This website uses <a href="http://sourceforge.net/projects/hebcal/">hebcal
3.2 for UNIX</a>, Copyright &copy; 1994 Danny Sadinoff. All rights reserved.
</font></body></html>
<?php
    exit();
}

function form($param, $message = '', $help = '') {
    if ($message != '') {
	$message = '<hr noshade size="1"><p><font' . "\n" .
	    'color="#ff0000">' .  $message . '</font></p>' . $help . 
	    '<hr noshade size="1">';
    }

    echo $message;
    echo "<p>Subscribe to email weekly Shabbat candle lighting times.\n",
	"Email is sent out every week on Thursday morning.</p>\n";

    if (!$param['dst']) {
	$param['dst'] = 'usa';
    }
    if (!$param['tz']) {
	$param['tz'] = 'auto';
    }
    if (!$param['m']) {
	$param['m'] = 72;
    }

?>
<form name="f1" id="f1" action="/email2/" method="get">

<label for="em">E-mail address:
<input type="text" name="em" size="30"
value="<?php echo htmlspecialchars($param['em']) ?>" id="em">
</label>
&nbsp;&nbsp;<font size="-2" face="Arial"><a href="/privacy/#email">Email
Privacy Policy</a></font>

<br><label for="zip">Zip code:
<input type="text" name="zip" size="5" maxlength="5" id="zip"
value="<?php echo htmlspecialchars($param['zip']) ?>"></label>

&nbsp;&nbsp;&nbsp;&nbsp;<label for="tz">Time zone:
<select name="tz" id="tz">
<option <?php if ($param['tz'] == 'auto') { echo 'selected '; } ?>
value="auto">- Attempt to auto-detect -</option>
<option <?php if ($param['tz'] == '-5') { echo 'selected '; } ?>
value="-5">GMT -05:00 (U.S. Eastern)</option>
<option <?php if ($param['tz'] == '-6') { echo 'selected '; } ?>
value="-6">GMT -06:00 (U.S. Central)</option>
<option <?php if ($param['tz'] == '-7') { echo 'selected '; } ?>
value="-7">GMT -07:00 (U.S. Mountain)</option>
<option <?php if ($param['tz'] == '-8') { echo 'selected '; } ?>
value="-8">GMT -08:00 (U.S. Pacific)</option>
<option <?php if ($param['tz'] == '-9') { echo 'selected '; } ?>
value="-9">GMT -09:00 (U.S. Alaskan)</option>
<option <?php if ($param['tz'] == '-10') { echo 'selected '; } ?>
value="-10">GMT -10:00 (U.S. Hawaii)</option>
</select>
</label>

<br>Daylight Saving Time:
<label for="dst_usa">
<input type="radio" name="dst" <?php
	if ($param['dst'] == 'usa') { echo 'checked '; } ?>
value="usa" id="dst_usa">
USA (except AZ, HI, and IN)
</label>
<label for="dst_none">
<input type="radio" name="dst" <?php 
	if ($param['dst'] == 'none') { echo 'checked '; } ?>
value="none" id="dst_none">
none
</label>

<br><label for="m1">Havdalah minutes past sundown:
<input type="text" name="m" value="<?php
  echo htmlspecialchars($param['m']) ?>" size="3" maxlength="3" id="m1">
</label>

<br><label for="upd">
<input type="checkbox" name="upd" value="on" <?php
  if ($param['upd'] == 'on') { echo 'checked'; } ?> id="upd">
Contact me occasionally about changes to the hebcal.com website.
</label>

<input type="hidden" name="v" value="1">
<input type="hidden" name="geo" value="zip">
<br>
<input type="submit" name="submit_modify" value="Subscribe">
<input type="submit" name="submit_unsubscribe" value="Unsubscribe">
</form>
<?php
    my_footer();
}

function subscribe($param) {
    global $HTTP_SERVER_VARS;

    if (!$param['zip'])
    {
	form($param,
	     "Please enter your zip code for candle lighting times.");
    }

    $recipients = $param['em'];
    if (preg_match('/\@hebcal.com$/', $recipients))
    {
	form($param,
	     "Sorry, can't use a <b>hebcal.com</b> email address.");
    }

    if (!$param['dst']) {
	$param['dst'] = 'usa';
    }
    if (!$param['tz']) {
	$param['tz'] = 'auto';
    }
    $param['geo'] = 'zip';

    if (!preg_match('/^\d{5}$/', $param['zip']))
    {
	form($param,
	     "Sorry, <b>" . $param['zip'] . "</b> does\n" .
	     "not appear to be a 5-digit zip code.");
    }

    $val = get_zip_info($param['zip']);
    if (!$val)
    {
	form($param,
	     "Sorry, can't find\n".  "<b>" . $param['zip'] .
	     "</b> in the zip code database.\n",
	     "<ul><li>Please try a nearby zip code</li></ul>");
    }

    list($city,$state) = explode("\0", substr($val,6), 2);

    if (($state == 'HI' || $state == 'AZ') && $param['dst'] == 'usa')
    {
	$param['dst'] = 'none';
    }

    $city = ucwords(strtolower($city));
    $city_descr = "$city, $state " . $param['zip'];

    // handle timezone == "auto"
    $tz = guess_timezone($param['tz'], $param['zip'], $state);
    if (!$tz)
    {
	form($param,
	     "Sorry, can't auto-detect\n" .
	     "timezone for <b>" . $city_descr . "</b>\n".
	     "(state <b>" . $state . "</b> spans multiple time zones).",
	     "<ul><li>Please select your time zone below.</li></ul>");
    }

    global $tz_names;
    $param['tz'] = $tz;
    $tz_descr = "Time zone: " . $tz_names[$tz];

    $dst_descr = "Daylight Saving Time: " . $param['dst'];


    $rand = pack("V", rand());
    if ($HTTP_SERVER_VARS["REMOTE_ADDR"]) {
	list($p1,$p2,$p3,$p4) = explode('.', $HTTP_SERVER_VARS["REMOTE_ADDR"]);
	$rand .= pack("CCCC", $p1, $p2, $p3, $p4);
    }
    $rand .= pack("V", time());

    $encoded = rtrim(base64_encode($rand));
    $encoded = str_replace('+', '.', $encoded);
    $encoded = str_replace('/', '_', $encoded);
    $encoded = str_replace('=', '-', $encoded);

    $from_name = "Hebcal Subscription Notification";
    $from_addr = "shabbat-subscribe+$encoded@hebcal.com";
    $return_path = "shabbat-bounce@hebcal.com";
    $subject = "Please confirm your request to subscribe to hebcal";

    $headers = array('From' => "\"$from_name\" <$from_addr>",
		     'To' => $recipients,
		     'Reply-To' => $from_addr,
		     'MIME-Version' => '1.0',
		     'Content-Type' => 'text/plain',
		     'X-Sender' => "webmaster@$SERVER_NAME",
		     'Subject' => $subject);

    $body = <<<EOD
Hello,

We have received your request to receive weekly Shabbat
candle lighting time information from hebcal.com for
$city_descr.

Please confirm your request by replying to this message.

If you did not request (or do not want) weekly Shabbat
candle lighting time information, please accept our
apologies and ignore this message.

Regards,
hebcal.com
EOD;

    $title = "success!";
    $err = smtp_send($return_path, $recipients, $headers, $body);
    if ($err !== true)
    {
	$title = $err;
    }
?>

<h1><?php echo $title ?></h1>

foobar

<?php
}
