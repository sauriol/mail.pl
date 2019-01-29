#!/usr/bin/perl
use strict;
use warnings;

use Net::SMTP;
use Net::IMAP::Simple;
use Email::Simple;
use Curses::UI;

package Mail;

# imap_login
#
#  Params:
#     $user   - the username to use when logging in
#     $pass   - the password to use when logging in
#     $server - the server to log in to
#
#  Returns:
#     $imap   - a logged in imap object
#
#  Error:
#     If the object creation or login fail, an error will be thrown.
#
#  Performs the creation and login to the given IMAP server. Returns an IMAP
#  object that can be used to get the mail in a user's inbox.
sub imap_login {
    my ($user, $pass, $server) = @_;

    my $imap = Net::IMAP::Simple->new($server, use_ssl => 1)
        or die "Error: unable to connect to $server\n";
    $imap->login($user, $pass) or die "Error: " . $imap->errstr . "\n";

    return $imap;
}

# get_emails
#
#  Params:
#     $start  - the start index
#     $end    - the end index
#     $num    - the number of messages in the inbox
#     $imap   - the imap object returned by imap_login
#
#  Returns:
#     @emails - an array of the raw email returned by $imap->top($ind)
#
#  Error:
#     If the range is invalid or an email can not be returned, an error will
#     be thrown.
#
#  Retrieves the emails from an inbox in a given range
sub get_emails {
    my ($start, $end, $num, $imap) = @_;

    if ($start > $end ||
        $start <= 0 ||
        $end > $num) {
        die "Error: invalid range\n";
    }

    my @emails;

    for (my $i = $start; $i <= $end; $start++) {
        push @emails, $imap->top($i);
    }

    return @emails;
}

# The exit dialog displayed when trying to exit the application
sub exit_dialog {
    my $exit = $Mail::cui->dialog(
        -message  => 'Quit?',
        -title    => 'Exit',
        -buttons  => ['yes', 'no'],
    );

    exit(0) if $exit;
}


sub show_message {
    my ($imap, $notebook, $id) = @_;

    my $email = Email::Simple->new(join '', @{$imap->get($id)});

    my $text =  'From: ' . $email->header('From') . "\n"
                . 'To: ' . $email->header('To') . "\n"
                . 'Subject: ' . $email->header('Subject') . "\n"
                . $email->body;

    my $display = $notebook->add_page($email->header('Subject'));

    my $textview = $display->add(
        'textview', 'TextViewer',
        -text        => $text,
    );

    $textview->focus();

                #    my $message = $win->add(
                #        'message', 'Dialog::Basic',
                #        -title       => $email->header('Subject'),
                #        -message     => $text,
                #        -buttons     => ['ok'],
                #        -vscrollbar  => 1
                #    );

                #    my $message = $Mail::cui->dialog(
                #        -message     => $text,
                #        -title       => $email->header('Subject'),
                #        -buttons     => ['ok'],
                #        -vscrollbar  => 1,
                #    );

                #    $message->focus();
}


# Build out the screen, list of messages on left, message window on right?
#  - Consider using Curses::UI
#  - Size dependent?
#     - Smaller window -> just messages
#  - Is there a good/easy way to dynamically resize the window?
#  ___________________________
# | message | user info here? |
# | message |-----------------|
# | message |                 |
# | message |                 |
# | message |                 |
# | message |   email here    |
# | message |                 |
# | message |                 |
# | message |_________________|
# |   keybindings here??      |
# -----------------------------

# if MAIL_PASS and MAIL_USER aren't defined, give the user a chance to login and
# if the login doesn't go through, ask for creds again

# Login to IMAP and get the messages, maybe display "Loading" or something?

# Load the messages onto the screen

# Loop for input, getchar should work okay
#  w for write? hjkl for moving around the screen?

my $imap = imap_login($ENV{'MAIL_USER'}, $ENV{'MAIL_PASS'}, 'mail.csh.rit.edu');

$Mail::cui = new Curses::UI(-color_support => 1);

my @menu = ({
        -label    => 'File',
        -submenu  => [{
                -label  => 'Exit',
                -value  => \&exit_dialog
        }]
});

my $menu = $Mail::cui->add(
    'menu', 'Menubar',
    -menu   => \@menu,
);

my $win = $Mail::cui->add(
    'win', 'Window',
    -border => 1,
    -y      => 1,
);



my $notebook = $win->add(undef, 'Notebook');
my $inbox = $notebook->add_page('Inbox');

my $nm = $imap->select('INBOX');

$Mail::cui->progress(
    -message   => 'Loading inbox...',
    -max       => $nm
);

my %emails;
my %subjects;
for (my $i = 1; $i <= $nm; $i++) {
    my $es = Email::Simple->new(join '', @{$imap->top($i)});
    $emails{$i} = $es;
    $subjects{$i} = $es->header('Subject');
    $Mail::cui->setprogress($i);
}

my $maillist = $inbox->add(
    'maillist', 'Listbox',
    -values    => [1..$nm],
    -labels    => \%subjects,
    -selected  => 0,
);




$Mail::cui->set_binding(sub {$menu->focus()}, "\cX");
$Mail::cui->set_binding(\&exit_dialog, "\cQ");
$Mail::cui->set_binding(sub {$notebook->delete_page($notebook->active_page())}, "\cW");
$Mail::cui->set_binding(sub {
        show_message($imap, $notebook, $maillist->id());

}, "\cN");

#$container->focus();
#$inbox->focus();
$notebook->focus();
$Mail::cui->mainloop();
