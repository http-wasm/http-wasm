# Ex install like so, matching versions with .github/workflows/commit.yaml
# cargo install --git https://github.com/WebAssembly/wasi-tools --locked wit-abi --tag wit-abi-0.5.0
.PHONY: abi
abi:
	@wit-abi .
