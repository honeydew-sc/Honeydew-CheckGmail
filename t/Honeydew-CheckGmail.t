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
            emaildir => tempdir(CLEANUP => 1)
        );
    };

    describe 'unread retrieval' => sub {
        my ($unseen_msg_id);
        before each => sub {
            $unseen_msg_id = '2';
            $mockimap->expects('search')
              ->returns(['1', $unseen_msg_id]);
        };

        it 'should get emails from the inbox' => sub {
            $mockimap->expects('get_summaries')
              ->with_deep($unseen_msg_id)
              ->returns([{
                  flags => [ ],
                  uid => $unseen_msg_id
              }]);

            $mockimap->expects('get_rfc822_body')
              ->with($unseen_msg_id)
              ->returns(\'body');

            my $message = $gmail->get_email(subject => 'Welcome to Sharecare');
            is_deeply($message, { id => $unseen_msg_id, body => 'body' });
        };

        it 'should throw when the most recent email is seen' => sub {
            $mockimap->expects('get_summaries')
              ->with_deep($unseen_msg_id)
              ->returns([{flags => [ '\Seen' ], uid => $unseen_msg_id}, ]);

            $mockimap->expects('get_rfc822_body')->never;

            like(exception { $gmail->get_email(subject => 'Welcome to Sharecare') },
                 qr/already SEEN/);
        };

    };

    it 'should throw when no messages are found' => sub {
        $mockimap->expects('search')->returns(undef);

        like(exception { $gmail->get_email(subject => 'no results') },
             qr/no messages/i);
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

runtests;
