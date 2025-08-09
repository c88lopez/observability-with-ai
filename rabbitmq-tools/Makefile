# Simple Makefile for rabbitmq-tool
# Usage: make [build|run-producer|run-consumer|clean]

BINARY := rabbitmq-tool
PKG := .
GO := go
LDFLAGS := -s -w

.PHONY: all build clean run-producer run-consumer help

all: build

build:
	@echo "Building $(BINARY)..."
	@$(GO) build -ldflags "$(LDFLAGS)" -o $(BINARY) $(PKG)
	@echo "Done: ./$(BINARY)"

run-producer: build
	./$(BINARY) --mode=produce --queue=test_load_queue --count=1000 --batch=200

run-consumer: build
	./$(BINARY) --mode=consume --queue=test_load_queue --count=1000

clean:
	@echo "Cleaning..."
	@rm -f $(BINARY)

help:
	@echo "Targets:"
	@echo "  build         Build the rabbitmq tool binary"
	@echo "  run-producer  Build then run a sample producer (1k msgs)"
	@echo "  run-consumer  Build then run a sample consumer (1k msgs)"
	@echo "  clean         Remove built binary"
	@echo "Environment vars: RABBITMQ_URL, RANDOM_SEED"
