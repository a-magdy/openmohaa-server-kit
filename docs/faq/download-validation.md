# Download Validation (SHA256)

Use `scripts/validate-pk3.sh` to verify a downloaded map file matches the expected SHA256 checksum.

## Usage

```bash
./scripts/validate-pk3.sh <pk3_url> <expected_sha256>
```

## Typical workflow

1. Compute checksum from the canonical server file:

```bash
sha256sum /var/www/mohaa/mp_snipervalley.pk3
```

2. Validate the downloadable URL against that checksum:

```bash
./scripts/validate-pk3.sh https://yourdomain.com/mohaa/mp_snipervalley.pk3 d2f3...abcd
```

3. Interpret result:

- ✅ match: file integrity confirmed
- ❌ mismatch: corrupted/wrong file or interrupted transfer

## Common issues

- Checksum mismatch: re-download and re-verify
- Missing SHA tool: install coreutils (Linux) or use `shasum` on macOS
- URL failures: verify URL path and web host status
