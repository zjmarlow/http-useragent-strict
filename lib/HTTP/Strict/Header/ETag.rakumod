use HTTP::Strict::Header::Field;

unit class HTTP::Strict::Header::ETag is HTTP::Strict::Header::Field;

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
