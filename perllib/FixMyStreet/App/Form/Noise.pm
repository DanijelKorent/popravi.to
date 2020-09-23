package FixMyStreet::App::Form::Noise;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Wizard';

use utf8;

has c => ( is => 'ro' );
has addresses => ( is => 'rw');

has default_page_type => ( is => 'ro', isa => 'Str', default => 'Noise' );

before _process_page_array => sub {
    my ($self, $pages) = @_;
	foreach my $page (@$pages) {
		$page->{type} = $self->default_page_type
			unless $page->{type};
	}
};

# Add some functions to the form to pass through to the current page
has '+current_page' => (
    handles => {
        intro_template => 'intro',
        title => 'title',
        template => 'template',
        requires_sign_in => 'requires_sign_in',
    }
);

has_page intro => (
    fields => ['start'],
    title => 'Report unwelcome noise',
    intro => 'start.html',
    next => 'existing_issue',
);

has_page existing_issue => (
    fields => ['existing', 'continue'],
    title => 'About the noise',
    next => sub { $_[0]->{existing} ? 'report_pick' : 'about_you' },
);

has_field existing => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Is this a new issue or have you reported this before?',
    options => [
        { value => '0', label => 'New issue' },
        { value => '1', label => 'I have reported this before', hint => 'You can log a new occurrence against your existing report' },
    ]
);

has_page report_pick => (
    fields => ['report', 'continue'],
    requires_sign_in => 1,
    template => 'noise/existing.html',
    title => 'About the noise',
    next => 'kind',
    update_field_list => sub {
        my $form = shift;
        my $c = $form->c;
        return unless $c->user_exists;
        my @problems = $c->user->problems->search({ category => 'Noise report' })->all;
        @problems = map {
            { value => $_->id, label => $_->id, report => $_ }
        } @problems;
        return { report => { options => \@problems } };
    }
);

has_field report => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Attach a previous report to link your issues',
);

has_page about_you => (
    fields => ['name', 'email', 'phone', 'continue'],
    title => 'About you',
    next => 'best_time',
    update_field_list => sub {
        my $form = shift;
        my $c = $form->c;
        return unless $c->user_exists;
        my $user = $c->user;
        return {
            name => { default => $user->name },
            email => { default => $user->email, disabled => 1 },
            phone => { default => $user->phone },
        };
    },
);

with 'FixMyStreet::App::Form::Noise::AboutYou';

has_page best_time => (
    fields => ['best_time', 'best_method', 'continue'],
    title => 'Contacting you',
    intro => 'best_time.html',
    next => 'postcode',
);

has_field best_time => (
    type => 'Select',
    multiple => 1,
    widget => 'CheckboxGroup',
    required => 1,
    label => 'When is the best time to contact you?',
    tags => { hint => 'Tick all that apply' },
    options => [
        { label => 'Weekdays', value => 'day' },
        { label => 'Weekends', value => 'weekend' },
        { label => 'Evenings', value => 'evening' },
    ],
);

has_field best_method => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'What is the best method for contacting you?',
    options => [
        { label => 'Email', value => 'email' },
        { label => 'Phone' , value => 'phone' },
    ],
);

has_page postcode => (
    fields => ['postcode', 'find_address'],
    title => 'What is your address?',
    intro => 'postcode.html',
    next => 'address',
);

has_field postcode => (
    required => 1,
    type => 'Postcode',
    validate_method => \&check_postcode,
    tags => { autofocus => 1 },
);

has_page address => (
    fields => ['address', 'continue'],
    title => 'What is your address?',
    next => sub { $_[0]->{address} eq 'missing' ? 'address_missing' : 'kind' },
    update_field_list => sub {
        my $form = shift;
        my $options;
        if ($form->previous_form) {
            $options = $form->previous_form->addresses;
        } else {
            my $saved_data = $form->saved_data;
            $options = $form->c->cobrand->addresses_for_postcode($saved_data->{postcode});
            push @$options, { value => 'missing', label => 'I can’t find my address' };
        }
        return { address => { options => $options } };
    },
);

has_field address => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Select an address',
    tags => { last_differs => 1, small => 1 },
);

has_page address_missing => (
    fields => ['address_manual', 'continue'],
    title => 'What is your address?',
    next => 'kind',
);

has_field address_manual => (
    required => 1,
    type => 'Text',
    widget => 'Textarea',
    label => 'Your address',
);

has_page kind => (
    fields => ['kind', 'kind_other', 'continue'],
    title => 'About the noise',
    next => sub { $_[0]->{existing} ? 'when' : 'where' },
    update_field_list => sub {
        my $form = shift;
        my $saved_data = $form->saved_data;
        if ($saved_data->{report} && !$saved_data->{kind}) {
            my $report = FixMyStreet::DB->resultset('Problem')->find($saved_data->{report}) or return;
            my $kind = $report->get_extra_metadata('kind');
            return { kind => { default => $kind } };
        }
    },
);

has_field kind => (
    label => 'What kind of noise is it?',
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    tags => { last_differs => 1, small => 1 },
    options => [
        { label => 'Aircraft', value => 'aircraft', data_hide => '#form-kind_other-row' },
        { label => 'Banging', value => 'banging', data_hide => '#form-kind_other-row'  },
        { label => 'Car alarm', value => 'car', data_hide => '#form-kind_other-row'  },
        { label => 'DIY', value => 'diy', data_hide => '#form-kind_other-row'  },
        { label => 'Dog barking', value => 'dog', data_hide => '#form-kind_other-row' },
        { label => 'House / intruder alarm', value => 'alarm', data_hide => '#form-kind_other-row' },
        { label => 'Music', value => 'music', data_hide => '#form-kind_other-row' },
        { label => 'Noise on the road', value => 'road', data_hide => '#form-kind_other-row' },
        { label => 'Shouting', value => 'shouting', data_hide => '#form-kind_other-row' },
        { label => 'TV', value => 'tv', data_hide => '#form-kind_other-row' },
        { label => 'Other', value => 'other', data_show => '#form-kind_other-row' },
    ],
);

has_field kind_other => (
    type => 'Text',
    label => 'Other'
);

has_page where => (
    fields => ['where', 'estates', 'address_known', 'continue'],
    title => 'Where is the noise coming from?',
    next => sub { $_[0]->{address_known} ? 'source_known_postcode' : $_[0]->{latitude} ? 'map': 'address_unknown' },
);

has_field where => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Where is the noise coming from?',
    options => [
        { label => 'A shop, bar, nightclub, or other business (including construction)', value => 'business', data_hide => '#form-estates-row' },
        { label => 'A house, flat, apartment, or other residence', value => 'residence', data_show => '#form-estates-row' },
    ],
);

has_field estates => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Is the residence a Hackney Estates property?',
    tags => { hint => 'Optional' },
    options => [
        { label => 'Yes', value => 'yes' },
        { label => 'No', value => 'no' },
        { label => 'Don’t know', value => 'unknown' },
    ]
);

has_field address_known => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Do you know the address of the source of the noise, and is it in Hackney?',
    options => [
        { label => 'Yes', value => 1 },
        { label => 'No', value => 0 },
    ],
);

has_page source_known_postcode => (
    fields => ['source_postcode', 'find_address'],
    title => 'The source of the noise',
    next => 'source_known_address',
);

sub check_postcode {
    my $self = shift;
    return if $self->has_errors; # Called even if already failed
    my $data = $self->form->c->cobrand->addresses_for_postcode($self->value);
    if (!@$data) {
        $self->add_error('Sorry, we did not find any results for that postcode');
    }
    push @$data, { value => 'missing', label => 'I can’t find my address' };
    $self->form->addresses($data);
}

has_field source_postcode => (
    required => 1,
    type => 'Postcode',
    validate_method => \&check_postcode,
    tags => { autofocus => 1 },
);

has_page source_known_address => (
    fields => ['source_address', 'continue'],
    title => 'The source of the noise',
    next => sub { $_[0]->{source_address} eq 'missing' ? 'address_unknown' : 'when' },
    update_field_list => sub {
        my $form = shift;
        my $options;
        if ($form->previous_form) {
            $options = $form->previous_form->addresses;
        } else {
            my $saved_data = $form->saved_data;
            $options = $form->c->cobrand->addresses_for_postcode($saved_data->{source_postcode});
            push @$options, { value => 'missing', label => 'I can’t find my address' };
        }
        return { source_address => { options => $options } };
    },
    post_process => sub {
        my $form = shift;
        my $saved_data = $form->saved_data;
        my $uprn = $saved_data->{source_address};
        return unless $uprn;
        foreach ($form->field('source_address')->options) {
            if ($uprn eq $_->{value}) {
                $saved_data->{latitude} = $_->{latitude};
                $saved_data->{longitude} = $_->{longitude};
            }
        }
    },
);

has_field source_address => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Select an address',
    tags => { last_differs => 1, small => 1 },
);

has_page address_unknown => (
    fields => ['pc', 'continue'],
    title => 'The source of the noise',
    next => 'map',
);

has_field pc => (
    required => 1,
    type => 'Text',
    label => 'Postcode, or street name and area, to see map',
    validate_method => sub {
        my $self = shift;
        my $c = $self->form->c;
        return if $self->has_errors; # Called even if already failed
        my $ret = $c->forward('/location/determine_location_from_pc', [ $self->value ]);
        if (!$ret) {
            if ( $c->stash->{possible_location_matches} ) {
                $self->add_error('Multiple matches - deal somehow');
            } else {
                $self->add_error($c->stash->{location_error});
            }
        }
        my $saved_data = $self->form->saved_data;
        $saved_data->{latitude} = $c->stash->{latitude};
        $saved_data->{longitude} = $c->stash->{longitude};
    },
);

has_page map => (
    fields => ['latitude', 'longitude', 'radius', 'continue'],
    title => 'The source of the noise',
    template => 'noise/map.html',
    next => 'when',
    update_field_list => sub {
        my $form = shift;
        my $c = $form->c;
        if ($c->forward('/report/new/determine_location_from_tile_click')) {
            $c->forward('/around/check_location_is_acceptable', []);
            # We do not want to process the form if they have clicked the map
            $c->stash->{override_no_process} = 1;

            my $saved_data = $form->saved_data;
            $saved_data->{latitude} = $c->stash->{latitude};
            $saved_data->{longitude} = $c->stash->{longitude};
            return {};
        }
    },
    post_process => sub {
        my $form = shift;
        my $c = $form->c;
        my $latitude = $form->fif->{latitude};
        my $longitude = $form->fif->{longitude};
        $c->stash->{page} = 'new';
        FixMyStreet::Map::display_map(
            $c,
            latitude => $latitude,
            longitude => $longitude,
            clickable => 1,
            pins => [ {
                latitude => $latitude,
                longitude => $longitude,
                draggable => 1,
                colour => $c->cobrand->pin_new_report_colour,
            } ],
        );
    },
);

has_field latitude => ( type => 'Hidden', required => 1 );
has_field longitude => ( type => 'Hidden', required => 1 );
has_field radius => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Area size',
    tags => { hint => 'Adjust the area size to indicate roughly where you believe the noise source to be' },
    tags => { small => 1 },
    options => [
        { label => 'Small (100ft / 30m)', value => 'small' },
        { label => 'Medium (200yd / 180m)', value => 'medium' },
        { label => 'Large (half a mile / 800m)', value => 'large' },
    ],
);

has_page when => (
    fields => ['happening_now', 'happening_days', 'happening_time', 'continue'],
    title => 'When does the noise happen?',
    next => 'more_details',
);

has_field happening_now => (
    type => 'Select', widget => 'RadioGroup',
    label => 'Is the noise happening now?',
    options => [
        { label => 'Yes', value => 1 },
        { label => 'No', value => 0 },
    ],
);

has_field happening_days => (
    tags => { hint => 'Tick all that apply' },
    label => 'What days does the noise happen?',
    type => 'Select',
    multiple => 1,
    widget => 'CheckboxGroup',
    options => [
        { value => 'monday', label => 'Monday' },
        { value => 'tuesday', label => 'Tuesday' },
        { value => 'wednesday', label => 'Wednesday' },
        { value => 'thursday', label => 'Thursday' },
        { value => 'friday', label => 'Friday' },
        { value => 'saturday', label => 'Saturday' },
        { value => 'sunday', label => 'Sunday' },
    ],
);

has_field happening_time => (
    tags => { hint => 'Tick all that apply' },
    label => 'What time does the noise happen?',
    type => 'Select',
    multiple => 1,
    widget => 'CheckboxGroup',
    options => [
        { value => 'morning', label => 'Morning (6am – noon)' },
        { value => 'daytime', label => 'Daytime (noon – 6pm)' },
        { value => 'evening', label => 'Evening (6pm – 11pm)' },
        { value => 'night', label => 'Night time (11pm – 6am)' },
    ],
);

has_page more_details => (
    fields => ['more_details', 'continue'],
    title => 'More details',
    next => 'summary',
);

has_field more_details => (
    label => 'Finally add any other details to help describe the nature of the problem',
    type => 'Text',
    widget => 'Textarea',
);

has_page summary => (
    fields => ['submit'],
    title => 'Review',
    template => 'noise/summary.html',
    finished => sub {
        my $form = shift;
        my $c = $form->c;
        my $success = $c->forward('process_noise_report', [ $form ]);
        if (!$success) {
            $form->add_form_error('Something went wrong, please try again');
            foreach (keys %{$c->stash->{field_errors}}) {
                $form->add_form_error("$_: " . $c->stash->{field_errors}{$_});
            }
        }
        return $success;
    },
    next => 'done',
);

has_page done => (
    title => 'Submit',
    template => 'noise/confirmation.html',
);

has_field start => ( type => 'Submit', value => 'Start', element_attr => { class => 'govuk-button' } );
has_field find_address => ( type => 'Submit', value => 'Find address', element_attr => { class => 'govuk-button' } );
has_field continue => ( type => 'Submit', value => 'Continue', element_attr => { class => 'govuk-button' } );
has_field submit => ( type => 'Submit', value => 'Submit', element_attr => { class => 'govuk-button' } );

sub validate {
    my $self = shift;
    $self->add_form_error('Please specify at least one of phone or email')
        unless $self->field('phone')->is_inactive || $self->field('phone')->value || $self->field('email')->value;
}

1;
