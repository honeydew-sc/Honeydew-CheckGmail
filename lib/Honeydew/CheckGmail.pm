package Honeydew::CheckGmail;

# ABSTRACT:
use strict;
use warnings;
use feature qw/say/;
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

has _emaildir => (
    is => 'lazy',
    default => sub {
        my ($self) = @_;
        return $self->config->{honeydew}->{emaildir};
    }
);


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
        die 'No messages were found for this search criteria';
    }
}

sub save_email {
    my ($self, %search) = @_;

    my $message = $self->get_message(%search);

}

1;
