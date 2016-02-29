# NAME

Honeydew::CheckGmail - Get and save new emails from Gmail

[![Build Status](https://travis-ci.org/honeydew-sc/Honeydew-CheckGmail.svg?branch=master)](https://travis-ci.org/honeydew-sc/Honeydew-CheckGmail)

# VERSION

version 0.02

# SYNOPSIS

    my $gmail = Honeydew::CheckGmail->new;
    my $message = $gmail->get_message(subject => 'Password Reset');
    my $local_file = $gmail->write_message(subject => 'Password Reset');

# DESCRIPTION

Honeydew::CheckGmail is a convenience wrapper that takes care of
finding the newest email and saving it to a file such that we can view
it locally. With no arguments, the constructor will look up
credentials for a Gmail account in the config attribute.

# ATTRIBUTES

## user

Specify the short part of the Gmail account login - for example, if
the email is `something@gmail.com`, we just want `something`.

## password

Specify the password for the gmail account

## config

Specify a config instance. If not provided, ["user"](#user) and ["password"](#password)
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

## emaildir

Specify what directory ["save\_email"](#save_email) should write files to. Do not
provide the trailing slash.

## msg\_delay

Specify how recently an email must have arrived to be considered
new. Defaults to `120` seconds - that is, if an email's internal date
is less than two minutes old, we'll accept it as the new message that
you are waiting for.

    my $gmail = Honeydew::CheckGmail->new(
        msg_delay => 300 # a five minute old message is fine
    );

# METHODS

## get\_email(%search)

Search the inbox with the provided criteria for the most recent
message. For example, to search for an email with subject `foo` from
`sender`, you could do

    $gmail->get_email(subject => 'foo', from => 'sender');

We'll return a hashref with the message id and the body of the email:

    {
        id => $message_id,
        body => $html_rfc822_body
    }

This hashref can be passed to ["save\_email"](#save_email) to write to a file if
desired.

N.B.: A message will only be returned to you if and only if the most
recent message is unread. If the most recent message is already seen,
this will croak. If no messages are found to match your criteria, this
will croak.

## save\_email($message)

Write the body of an email to a local directory for subsequent viewing
in a browser. Get your email message either with ["get\_email"](#get_email), and
then pass the result of either of those function calls to this
method. As argument, we expect a hashref with key `body`, which we
will write to a file.

    my $message = { body => 'some html' };
    my $file = $gmail->save_email($message);
    `cat $file`; # "some html"

# BUGS

Please report any bugs or feature requests on the bugtracker website
https://github.com/honeydew-sc/Honeydew-CheckGmail/issues

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

# AUTHOR

Daniel Gempesaw <gempesaw@gmail.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Daniel Gempesaw.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
