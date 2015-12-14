package Honeydew::CheckGmail;

# ABSTRACT: Get and save new emails from Gmail
use strict;
use warnings;
use feature qw/say/;
use Carp qw/croak/;
use Try::Tiny;
use Honeydew::Config;
use Moo;
use Net::IMAP::Client;
use Class::Date qw(now);

=for markdown [![Build Status](https://travis-ci.org/honeydew-sc/Honeydew-CheckGmail.svg?branch=master)](https://travis-ci.org/honeydew-sc/Honeydew-CheckGmail)

=head1 SYNOPSIS

    my $gmail = Honeydew::CheckGmail->new;
    my $message = $gmail->get_message(subject => 'Password Reset');
    my $local_file = $gmail->write_message(subject => 'Password Reset');

=head1 DESCRIPTION

Honeydew::CheckGmail is a convenience wrapper that takes care of
finding the newest email and saving it to a file such that we can view
it locally. With no arguments, the constructor will look up
credentials for a Gmail account in the config attribute.

=cut

=attr user

Specify the short part of the Gmail account login - for example, if
the email is C<something@gmail.com>, we just want C<something>.

=cut

has user => (
    is => 'lazy',
    default => sub {
        my ($self) = @_;
        return $self->config->{gmail}->{username};
    }
);

=attr password

Specify the password for the gmail account

=cut

has password => (
    is => 'lazy',
    default => sub {
        my ($self) = @_;
        return $self->config->{gmail}->{password};
    }
);

=attr config

Specify a config instance. If not provided, L</user> and L</password>
will be looked up in this hash like such:

    my $config = {
        gmail => { user => 'user', password => 'password' }
    };
    my $gmail = Honeydew::CheckGmail->new(config => $config);

That would do the same thing as

    my $gmail = Honeydew::CheckGmail->new(
        user => 'user',
        password => 'password'
    );

=cut

has config => (
    is => 'lazy',
    default => sub {
        return Honeydew::Config->instance;
    }
);

=attr emaildir

Specify what directory L</save_email> should write files to. Do not
provide the trailing slash.

=cut

has emaildir => (
    is => 'lazy',
    default => sub {
        my ($self) = @_;
        return $self->config->{honeydew}->{emailsdir};
    }
);

=attr msg_delay

Specify how recently an email must have arrived to be considered
new. Defaults to C<120> seconds - that is, if an email's internal date
is less than two minutes old, we'll accept it as the new message that
you are waiting for.

    my $gmail = Honeydew::CheckGmail->new(
        msg_delay => 300 # a five minute old message is fine
    );

=cut

has msg_delay => (
    is => 'lazy',
    default => 120
);

has _imap => (
    is => 'lazy',
    default => sub {
        my ($self) = @_;
        my $imap = Net::IMAP::Client->new(
            server => 'imap.gmail.com',
            user   => $self->user,
            pass   => $self->password,
            ssl    => 1,
            port   => 993
        );
        $imap->login;
        $imap->select('INBOX');

        return $imap;
    }
);

=method get_email(%search)

Search for the most recent email with a hash of search criteria. For
example, to search for an email with subject C<foo> from C<sender>,
you could do

    $gmail->get_email(subject => 'foo', from => 'sender');

We'll return a hashref with the message id and the body of the email:

    {
        id => $message_id,
        body => $html_rfc822_body
    }

If no messages are found, this will croak.

=cut

sub get_email {
    my ($self, %search) = @_;

    my $msg_ids = $self->_imap->search(\%search);
    if ($msg_ids && scalar @$msg_ids) {
        my $newest_msg_id = (reverse @{ $msg_ids })[0];

        # uh, get_rfc822_body returns a reference to a scalar for the
        # body, so we need to dereference it...
        my $body_ref = $self->_imap->get_rfc822_body($newest_msg_id);
        my $body = $$body_ref;

        return {
            id => $newest_msg_id,
            body => $body
        };
    }
    else {
        croak 'No messages were found for this search criteria';
    }
}

=method save_email($message)

Write the body of an email to a local directory for subsequent viewing
in a browser. Get your email message either with L</get_email> or
L</get_new_email>, and then pass the result of either of those
function calls to this method. As argument, we expect a hashref with
key C<body>, which we will write to a file.

    my $message = { body => 'some html' };
    my $file = $gmail->save_email($message);
    `cat $file`; # "some html"

=cut

sub save_email {
    my ($self, $message) = @_;
    die 'Please provide a hashref with key "body"'
      unless exists $message->{body};

    my $filename = $self->emaildir . '/' . time . '.html';
    open (my $fh, '>', $filename);
    print $fh $message->{body};
    close ($fh);

    return $filename;
}

sub is_message_new {
    my ($self, $message) = @_;

    my $summary = $self->_imap->get_summaries($message->{id})->[0];
    my $new_msg_cutoff = $self->_new_msg_cutoff;

    return $summary->internaldate gt $new_msg_cutoff;
}

sub _new_msg_cutoff {
    my ($self) = @_;

    my $now = now->to_tz('+0000');

    # the Class::Date module can do math like "$time - 60s" to
    # subtract a minute; appending an 's' turns msg_delay into
    # seconds.
    my $delay = $self->msg_delay . 's';
    my $new_msg_cutoff = $now - $delay;

    return $new_msg_cutoff->strftime('%d-%b-%G %H:%M:%S %z');
}

1;
