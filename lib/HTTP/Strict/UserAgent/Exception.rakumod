module HTTP::Strict::UserAgent::Exception {
	use HTTP::Strict::Message;

	class X::HTTP::Strict is Exception {
		has $.rc;
		has HTTP::Strict::Message $.response;
	}

	class X::HTTP::Strict::Internal is Exception {
		has $.rc;
		has $.reason;

		method message {
			"Internal Error: '$.reason'";
		}
	}

	class X::HTTP::Strict::Response is X::HTTP::Strict {
		has $.message;
		method message {
			$!message //= "Response error: '$.rc'";
		}
	}

	class X::HTTP::Strict::Server is X::HTTP::Strict {
		method message {
			"Server error: '$.rc'";
		}
	}

	class X::HTTP::Strict::Header is X::HTTP::Strict::Server {
	}

	class X::HTTP::Strict::ContentLength is X::HTTP::Strict::Response {
	}

	class X::HTTP::Strict::NoResponse is X::HTTP::Strict::Response {
		has $.message = "missing or incomplete response line";
		has $.got;
	}
}
