package t::Mock::Hackney;

use JSON::MaybeXS;
use Web::Simple;
use LWP::Protocol::PSGI;

has json => (
    is => 'lazy',
    default => sub {
        JSON->new->pretty->allow_blessed->convert_blessed;
    },
);

sub output {
    my ($self, $response) = @_;
    my $json = $self->json->encode($response);
    return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
}

sub dispatch_request {
    my $self = shift;

    sub (GET + ?*) {
        my ($self, $query) = @_;
        my $response = {
            data => {
                address => [
                    {
                        locality => 'HACKNEY',
                        line1 => '12 SAINT STREET',
                        line2 => 'DALSTON',
                        line3 => 'HACKNEY',
                        uprn => '100000111',
                        latitude => '51',
                        longitude => '1',
                    },
                    {
                        locality => 'ELSEWHERE',
                        line1 => '1 ROAD ROAD',
                        line2 => '',
                        line3 => '',
                        uprn => '100000222',
                        latitude => '52',
                        longitude => '2',
                    },
                    {
                        locality => 'HACKNEY',
                        line1 => '24 HIGH STREET',
                        line2 => 'HACKNEY',
                        line3 => '',
                        uprn => '100000333',
                        latitude => '53',
                        longitude => '3',
                    },
                ],
                page_count => 1,
                total_count => 4,
            },
            statusCode => 200,
            error => undef,
        };
        return $self->output($response);
    },

}

__PACKAGE__->run_if_script;
