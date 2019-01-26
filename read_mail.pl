#!/usr/bin/perl
use strict;
use warnings;

use Net::IMAP::Simple;
use Email::Simple;

my $imap = Net::IMAP::Simple->new('mail.csh.rit.edu', use_ssl => 1)
    or die "Unable to connect\n";

$imap->login($ENV{'USER'}, $ENV{'MAIL_PASS'})
    or die "Error: " . $imap->errstr . "\n";

my $nm = $imap->select('INBOX');

for (my $i = 1; $i <= $nm; $i++) {
    if ($imap->seen($i)) {
        print '*';
    }
    else {
        print ' ';
    }

    my $es = Email::Simple->new(join '', @{$imap->top($i)});
    printf("[%03d] %s\n", $i, $es->header('Subject'));

}
