use strict;
use warnings;
use Honeydew::CheckGmail;
use Test::Spec;
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

    it 'should get emails from the inbox' => sub {
        $mockimap->expects('search')
          ->returns(['1', '2']);

        $mockimap->expects('get_rfc822_body')
          ->with('2')
          ->returns(\'body');

        my $message = $gmail->get_email(subject => 'Welcome to Sharecare');
        is_deeply($message, { id => '2', body => 'body' });
    };

    it 'should write the message to the email dir' => sub {
        my $file = $gmail->save_email({body => 'body'});
        ok(-e $file);

        open (my $fh, '<', $file);
        my (@file) = <$fh>;
        close ($fh);

        is_deeply(\@file, [ 'body']);
    };

    it 'should reject an old message' => sub {
        my $summary = mock();
        $summary->expects('internaldate')
          ->returns('10-Dec-2015 14:34:44 +0000');

        $mockimap->expects('get_summaries')
          ->with('1')
          ->returns([ $summary ]);

        my $is_new = $gmail->_is_message_new({ id => '1' });
        ok(! $is_new);
    };

    it 'should accept a new message' => sub {
        my $now = now->to_tz('+0000')->strftime('%d-%b-%G %H:%M:%S %z');
        my $summary = mock();
        $summary->expects('internaldate')
          ->returns($now);

        $mockimap->expects('get_summaries')
          ->with('1')
          ->returns([ $summary ]);

        my $is_new = $gmail->_is_message_new({ id => '1' });
        ok($is_new);
    };
};

runtests;
