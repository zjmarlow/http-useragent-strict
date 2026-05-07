unit class HTTP::Strict::Header::Field;

has Str:D $.name is required;
has Str:D @.values;

method new ( Str:D :$name, :@values ) {
	self.bless:
			:$name,
			values => Array[ Str:D ].new: |@values;
}

method Str ( --> Str:D ) { join ': ', $!name, @!values.join: ', ' }
