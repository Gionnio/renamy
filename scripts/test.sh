#!/bin/bash
# Compiles the pure logic in Renamy/Core together with Tests/ and runs the tests.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
swiftc -O Renamy/Core/*.swift Tests/*.swift -o build/tests/renamy-tests
build/tests/renamy-tests
