module HTTP::UserAgent::Exception {
	use HTTP::Message::Strict;

	class X::HTTP::Strict is Exception {
		has $.rc;
		has HTTP::Message::Strict $.response;
	}

	class X::HTTP::Internal::Strict is Exception {
		has $.rc;
		has $.reason;

		method message {
			"Internal Error: '$.reason'";
		}
	}

	class X::HTTP::Response::Strict is X::HTTP::Strict {
		has $.message;
		method message {
			$!message //= "Response error: '$.rc'";
		}
	}

	class X::HTTP::Server::Strict is X::HTTP::Strict {
		method message {
			"Server error: '$.rc'";
		}
	}

	class X::HTTP::Header::Strict is X::HTTP::Server::Strict {
	}

	class X::HTTP::ContentLength::Strict is X::HTTP::Response::Strict {
	}

	class X::HTTP::NoResponse::Strict is X::HTTP::Response::Strict {
		has $.message = "missing or incomplete response line";
		has $.got;
	}
}
