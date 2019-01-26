#!/usr/bin/perl
use strict;
use warnings;

use Net::SMTP;

sub usage {
    my ($msg) = @_;
    if ($msg) {
        warn $msg . "\n";
    }
    die "Usage: $0 <recipient>\n";
}

sub date {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    my @week = qw(Sun Mon Tues Weds Thurs Fri Sat);
    my @month = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    $year += 1900;

    my $date = sprintf "%s, %02d %s %d %02d:%02d:%02d",
        $week[$wday], $mday, $month[$mon], $year, $hour, $min, $sec;

    return $date;
}

usage('MAIL_PASS must be defined') if not(defined $ENV{'MAIL_PASS'});

if ($#ARGV != 0) {
    usage('Error: wrong arguments');
}

my $user = $ENV{'MAIL_USER'} || $ENV{'USER'};
my $sender = "$user\@csh.rit.edu";
my $name = $ENV{'MAIL_NAME'} if (defined $ENV{'MAIL_NAME'});
my $recipient = shift or die "Unable to get recipient\n";
my $date = date();

print "Subject: ";
my $subject = <STDIN>;

my $contents;
while (<STDIN>) {
    $contents .= $_;
}

my $smtp = Net::SMTP->new('mail.csh.rit.edu', SSL => 1)
    or die "Could not connect to server\n";

$smtp->auth($ENV{'MAIL_USER'}, $ENV{'MAIL_PASS'});

$smtp->mail($sender);
$smtp->to($recipient);

$smtp->data;
$smtp->datasend("From: $name $sender\n");
$smtp->datasend("To: $recipient\n");
$smtp->datasend("Date: $date\n");
$smtp->datasend("Subject: $subject\n");
$smtp->datasend($contents);

print $smtp->message . "\n";
