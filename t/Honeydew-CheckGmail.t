use strict;
use warnings;
use Honeydew::CheckGmail;
use Test::Spec;
use Test::Fatal;
use Class::Date qw/now/;
use File::Temp qw/tempdir/;

describe 'CheckGmail' => sub {
    my ($gmail, $mockimap);
    before each => sub {
        $mockimap = mock();
        $gmail = Honeydew::CheckGmail->new(
            _imap => $mockimap,
            _emaildir => tempdir(CLEANUP => 1)
        );
    };

    describe 'unread retrieval' => sub {
        before each => sub {
            $mockimap->expects('search')
              ->returns(['1', '2']);
        };

        it 'should get emails from the inbox' => sub {
            $mockimap->expects('get_summaries')
              ->with_deep(['2', '1'])
              ->returns([{
                  flags => [  ],
                  uid => '1'
              }, {
                  flags => [ '\Seen' ],
                  uid => '2'
              }]);

            $mockimap->expects('get_rfc822_body')
              ->with('1')
              ->returns(\'body');

            my $message = $gmail->get_email(subject => 'Welcome to Sharecare');
            is_deeply($message, { id => '1', body => 'body' });
        };

        it 'should throw when all emails are seen' => sub {
            $mockimap->expects('get_summaries')
              ->with_deep(['2', '1'])
              ->returns([{flags => [ '\Seen' ], uid => '1'}, ]);

            $mockimap->expects('get_rfc822_body')->never;

            ok(exception { $gmail->get_email(subject => 'Welcome to Sharecare') });
        };

        it 'should return the newest unread message' => sub {
            $mockimap->expects('get_summaries')
              ->with_deep(['2', '1'])
              ->returns([{
                  flags => [ ],
                  uid => '1'
              }, {
                  flags => [],
                  uid => '2'
              }]);

            $mockimap->expects('get_rfc822_body')
              ->with('2')
              ->returns(\'body');

            my $message = $gmail->get_email(subject => 'Welcome to Sharecare');
            is_deeply($message, { id => '2', body => 'body' });

        };

    };


    it 'should write the message to the email dir' => sub {
        my $file = $gmail->save_email({body => 'body'});
        ok(-e $file);

        open (my $fh, '<', $file);
        my (@file) = <$fh>;
        close ($fh);

        is_deeply(\@file, [ 'body']);
    };

    describe 'message recency' => sub {
        my ($now, $summary);
        before each => sub {
            $now = now->to_tz('+0000');
            $summary = mock();
        };

        it 'should reject a very old message' => sub {
            my $summary = mock();
            mock_message_internaldate('10-Dec-2015 14:34:44 +0000', $summary, $mockimap);

            my $is_new = $gmail->is_message_new({ id => '1' });
            ok(! $is_new);
        };

        it 'should reject a message just past the msg_delay' => sub {
            my $too_old = $now - '121s';
            mock_message_internaldate($too_old->strftime('%d-%b-%G %H:%M:%S %z'), $summary, $mockimap);

            my $is_new = $gmail->is_message_new({ id => '1' });
            ok(! $is_new);
        };

        it 'should accept a new message' => sub {
            my $now = now->to_tz('+0000')->strftime('%d-%b-%G %H:%M:%S %z');
            mock_message_internaldate($now, $summary, $mockimap);

            my $is_new = $gmail->is_message_new({ id => '1' });
            ok($is_new);
        };

        it 'should accept a new message just under the msg_delay' => sub {
            my $now = now->to_tz('+0000');
            my $almost_two_minutes_old = $now - '119s';
            my $still_new = $almost_two_minutes_old->strftime('%d-%b-%G %H:%M:%S %z');

            mock_message_internaldate($still_new, $summary, $mockimap);

            my $is_new = $gmail->is_message_new({ id => '1' });
            ok($is_new);
        };

        sub mock_message_internaldate {
            my ($return_date, $summary, $mockimap) = @_;

            $summary->expects('internaldate')
              ->returns($return_date);

            $mockimap->expects('get_summaries')
              ->with('1')
              ->returns([ $summary ]);
        }

    };
};

runtests;
