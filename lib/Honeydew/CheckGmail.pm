package Honeydew::CheckGmail;

# ABSTRACT:
use strict;
use warnings;
use feature qw/say/;
use Carp qw/croak/;
use Honeydew::Config;
use Moo;
use Net::IMAP::Client;

=for markdown [![Build Status](https://travis-ci.org/honeydew-sc/Honeydew-CheckGmail.svg?branch=master)](https://travis-ci.org/honeydew-sc/Honeydew-CheckGmail)

=head1 SYNOPSIS

    my $gmail = Honeydew::CheckGmail->new;
    my $message = $gmail->get_message(subject => 'Password Reset');
    my $local_file = $gmail->write_message(subject => 'Password Reset');

=head1 DESCRIPTION

=cut

has user => (
    is => 'lazy',
    default => sub {
        my ($self) = @_;
        return $self->config->{gmail}->{username};
    }
);

has password => (
    is => 'lazy',
    default => sub {
        my ($self) = @_;
        return $self->config->{gmail}->{password};
    }
);

has config => (
    is => 'lazy',
    default => sub {
        return Honeydew::Config->instance;
    }
);

has emaildir => (
    is => 'lazy',
    default => sub {
        my ($self) = @_;
        return $self->config->{honeydew}->{emailsdir};
    }
);

has _imap => (
    is => 'lazy',
    default => sub {
        my ($self) = @_;
        my $imap = Net::IMAP::Client->new(
            server => 'imap.gmail.com',
            user   => $self->_user,
            pass   => $self->_password,
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
    if (scalar @$msg_ids) {
        my $newest_msg_id = (reverse @{ $msg_ids })[0];
        my $body = $self->_imap->get_rfc822_body($newest_msg_id);

        return {
            id => $newest_msg_id,
            body => $body
        };
    }
    else {
        croak 'No messages were found for this search criteria';
    }
}

=method save_email(%search)

Write the body of an email to a local directory for subsequent viewing
in a browser. Specify the search criteria the same way as in
C<get_email>:

    $gmail->save_email(subject => 'foo', from => 'sender');

If an email is found, its HTML body will be written to a file in the
L</emaildir>; that file path will be returned to you. As with
C<get_email>, if no email is found, this will croak.

=cut

sub save_email {
    my ($self, %search) = @_;

    my $message = $self->get_message(%search);

}

1;
