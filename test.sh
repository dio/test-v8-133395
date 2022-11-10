#!/usr/bin/env bash

set -e

# Clone the repo.
rm -fr proxy-wasm-cpp-host
git clone https://github.com/proxy-wasm/proxy-wasm-cpp-host.git

# Set working directory.
cd proxy-wasm-cpp-host

# Build test data.
bazel build --verbose_failures --test_output=errors --config=clang -c opt $(bazel query 'kind(was.*_rust_binary, //test/test_data/...)') $(bazel query 'kind(_optimized_wasm_cc_binary, //test/test_data/...)')

# Clean up test data.
for i in $(find bazel-bin/test/test_data/ -mindepth 1 -maxdepth 1 -type d); do \
  rm -rf $i; \
done

# Copy test data.
cp -fr bazel-bin/test/test_data/* test/test_data/

# Mangle build rules to use existing test data.
sed 's/\.wasm//g' test/BUILD > test/BUILD.tmp && mv test/BUILD.tmp test/BUILD
echo "package(default_visibility = [\"//visibility:public\"])" > test/test_data/BUILD
for i in $(cd test/test_data && ls -1 *.wasm | sed 's/\.wasm$//g'); do \
  echo "filegroup(name = \"$i\", srcs = [\"$i.wasm\"])" >> test/test_data/BUILD; \
done

# Run the TestVm.WasmMemoryLimit 100 times. Set "-Wno-deprecated-declarations" since:
# external/v8/src/base/platform/platform-darwin.cc:56:22: error: 'getsectdatafromheader_64' is
# deprecated: first deprecated in macOS 13.0 [-Werror,-Wdeprecated-declarations].
bazel test \
  --config=clang \
  --cxxopt=-Wno-deprecated-declarations \
  --host_cxxopt=-Wno-deprecated-declarations \
  --verbose_failures \
  --test_output=errors \
  --define engine=v8 \
  --test_arg=--gtest_filter=TestVm.WasmMemoryLimit \
  --test_arg=--gtest_repeat=100 \
  --runs_per_test=100 \
  //test:runtime_test
