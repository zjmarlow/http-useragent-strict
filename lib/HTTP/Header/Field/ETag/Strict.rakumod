use HTTP::Header::Field::Strict;

unit class HTTP::Header::Field::ETag::Strict is HTTP::Header::Field::Strict;

has Bool:D $.weak is required;

method new ( $value, Bool :$weak ) {
	self.bless:
			name => 'ETag',
			:$weak,
			values => $value
}

method Str ( --> Str:D ) {
	join ': ', $.name, join '"', $!weak ?? 'W/' !! '', @.values.Str, '';
}
