REBAR = ./rebar

.PHONY: deps test doc

all: deps compile

clean:
	$(REBAR) clean

compile:
	$(REBAR) compile

compile-fast:
	$(REBAR) compile skip_deps=true

console:
	erl -pa deps/*/ebin/ -pa ebin/ -sname flyway

deps:
	$(REBAR) get-deps

ensure-database-exists:
	@if [ `psql -l -U flyway | grep flyway_migrations  | wc -l` -eq 0 ]; then \
		createdb -U flyway flyway_migrations; \
	fi
	@psql -U flyway -d flyway_migrations < priv/schema.sql

distclean: clean
	$(REBAR) delete-deps

test: ensure-database-exists
	$(REBAR) skip_deps=true ct

dialyzer: compile
	@dialyzer -Wno_undefined_callbacks
