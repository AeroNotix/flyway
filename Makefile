.PHONY: deps test doc

all: deps compile

compile:
	rebar compile

compile-fast:
	rebar compile skip_deps=true

console:
	erl -pa deps/*/ebin/ -pa ebin/ -sname flyway

deps:
	rebar get-deps

clean:
	rebar clean

distclean: clean
	rebar delete-deps

test:
	rebar skip_deps=true ct

dialyzer: compile
	@dialyzer -Wno_undefined_callbacks
