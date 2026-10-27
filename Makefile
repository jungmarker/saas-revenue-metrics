.PHONY: setup data build report all clean

setup:            ## create venv and install dbt + the Ledgerly generator
	python3 -m venv .venv && .venv/bin/pip install -r requirements.txt

data:             ## generate the synthetic company (raw exports) into ./data
	.venv/bin/ledgerly-generate --seed 42 --out data

build:            ## run all dbt models and tests
	.venv/bin/dbt build --profiles-dir .

report:           ## render report/index.html from the marts
	.venv/bin/python report/build_report.py

all: data build report

clean:
	rm -rf target warehouse.duckdb data
