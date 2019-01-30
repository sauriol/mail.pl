#!/usr/bin/perl
use strict;
use warnings;

use Net::SMTP;
use Net::IMAP::Simple;
use Email::Simple;
use Curses::UI;


# Global window
my $cui = new Curses::UI();



sub imap_login {
    my ($user, $pass, $server) = @_;

    my $imap = Net::IMAP::Simple->new($server, use_ssl => 1)
        or $cui->error("Could not connect to $server") and exit(1);
    $imap->login($user, $pass)
        or $cui->error("Could not login as $user") and exit(1);

    warn 'Login successful...';

    return $imap;
}


sub get_info {
    my $infowin = $cui->add(
        'infowindow', 'Window',
        -centered => 1,
        -border   => 1,
        -ipad     => 2,
        -height   => 11,
        -width    => 60,
        -title    => 'Enter account information'
    );

    $infowin->add(
        'userlabel', 'Label',
        -x              => 0,
        -y              => 0,
        -width          => 13,
        -textalignment  => 'right',
        -text           => 'Username : ',
    );

    my $userentry = $infowin->add(
        'userentry', 'TextEntry',
        -x        => 14,
        -y        => 0,
        -text     => $ENV{'USER'},
    );

    $infowin->add(
        'passlabel', 'Label',
        -x              => 0,
        -y              => 2,
        -width          => 13,
        -textalignment  => 'right',
        -text           => 'Password : ',
    );

    my $passentry = $infowin->add(
        'passentry', 'TextEntry',
        -x        => 14,
        -y        => 2,
        -password => '*',
        -text     => '',
    )->focus();

    my $imap;

    my $buttons = $infowin->add(
        'buttons', 'Buttonbox',
        -x        => 14,
        -y        => 4,
        -buttons  => [
            {
                -label     => '< Login >',
                -onpress   => sub {
                    my $user = $userentry->get();
                    my $pass = $passentry->get();

                    $imap = imap_login($user, $pass, 'mail.csh.rit.edu');

                    $infowin->loose_focus;

                },
            },
            {
                -label     => '< Quit >',
                -onpress   => sub { exit },
            }
        ]
    );

    $infowin->modalfocus();
    $cui->delete('infowindow');

    warn 'Exiting infowindow...';

    return $imap;
}


sub open_inbox {
    my ($imap) = @_;

    my ($inbox, $notebook) = build_window();

    my $nm = $imap->select('INBOX');
    $cui->progress(
        -message  => 'Loading inbox...',
        -max      => $nm,
    );

    my %subjects;
    for (my $i = 1; $i <= $nm; $i++) {
        my $es = Email::Simple->new(join '', @{$imap->top($i)});
        $subjects{$i} = $es->header('Subject');
        $cui->setprogress($i);
    }

    warn 'Inbox loaded...';

    my $maillist = $inbox->add(
        'mailist', 'Listbox',
        -values      => [1..$nm],
        -labels      => \%subjects,
        -selected    => 1,
        -vscrollbar  => 1,
    );

    $inbox->focus();

    return ($notebook, $maillist);
}


sub build_window {
    my @menu = (
        {
            -label   => 'File',
            -submenu => [
                {
                    -label => 'Exit',
                    -value => \&exit_dialog,
                }
            ]
        }
    );

    my $menu = $cui->add(
        'menu', 'Menubar',
        -menu  => \@menu,
    );

    my $win = $cui->add(
        'win', 'Window',
        -border   => 1,
        -y        => 1,
    );

    my $notebook = $win->add('notebook', 'Notebook');

    my $inbox = $notebook->add_page('Inbox');

    warn 'Window built...';

    return ($inbox, $notebook);
}

sub exit_dialog {
    my $exit = $cui->dialog(
        -message  => 'Quit?',
        -title    => 'Exit',
        -buttons  => ['yes', 'no'],
    );

    exit(0) if $exit;
}


sub show_message {
    my ($imap, $notebook, $id) = @_;

    warn "Opening message $id...";

    my $email = Email::Simple->new(join '', @{$imap->get($id)});

    my $text =  'From: ' . $email->header('From') . "\n" .
                'To: ' . $email->header('To') . "\n" .
                'Subject' . $email->header('Subject') . "\n" .
                $email->body;

    my $display = $notebook->add_page($email->header('Subject'));

    my $textview = $display->add(
        'mailview', 'TextViewer',
        -text     => $text,
    );

    $textview->focus();
}







### Main ###

my $imap = get_info();
my ($notebook, $maillist) = open_inbox($imap);


### Set up bindings ###
$cui->set_binding(sub {$cui->getobj('menu')->focus()}, "\cX");
$cui->set_binding(\&exit_dialog, "\cQ");
$cui->set_binding(sub {$notebook->delete_page($notebook->active_page)}, "\cW");
$cui->set_binding(sub {show_message($imap, $notebook, $maillist->id())}, "\cN");



$cui->mainloop();
