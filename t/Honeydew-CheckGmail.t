use strict;
use warnings;
use Honeydew::CheckGmail;
use Test::Spec;
use File::Temp qw/tempdir/;

describe 'CheckGmail' => sub {
    my ($gmail, $mockimap);
    before each => sub {
        $mockimap = mock_imap(mock());
        $gmail = Honeydew::CheckGmail->new(
            _imap => $mockimap,
            _emaildir => tempdir(CLEANUP => 1)
        );

        # $gmail = Honeydew::CheckGmail->new(
        #     _user => 'sharecareqa',
        #     _password => '***REMOVED***'
        # );
    };

    it 'should get emails from the inbox' => sub {
        my $message = $gmail->get_email(subject => 'Welcome to Sharecare');
        is_deeply($message, { id => '2', body => 'body' });
    };

    xit 'should write a message to the email dir' => sub {
        $gmail->save_email;
    };

};

sub mock_imap {
    my ($mockimap) = @_;

    $mockimap->expects('search')
      ->returns(['1', '2']);

    $mockimap->expects('get_rfc822_body')
      ->with('2')
      ->returns('body');

    return $mockimap;
}

runtests;
