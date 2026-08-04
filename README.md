# my_binary

Non-confidential deployment artifacts for CloudTest SharePoint VM debugging.
See `cloudtest-sharepoint-vm-test-authoring-guide.md` §10 for the workflow.

## Contents

| File | Purpose |
| --- | --- |
| `UsageLoggingHandoff.cs.gz.enc.b64` | Encrypted validated source for the UsageLoggingHandoff suite (current) |
| `UsageLoggingHandoff.cs.enc.b64` | Older encrypted source (superseded — see below) |
| `UsageLoggingHandoff.scn` / `usage_logging.scn` | Generated Motif scenario |
| `MS.Internal.Test.Automation.Office.Osg.Wss.Tests.dll` | Prebuilt test DLL |
| `WssTestsDllPortable_LocalSearch_20260804.zip` | Password-protected portable build tree |
| `tools/7zip/` | Portable 7-Zip for VM-side extraction |

Passwords are **not** stored in this repository (guide §10). Obtain them through
the approved secure channel.

## UsageLoggingHandoff source artifacts

`UsageLoggingHandoff.cs.gz.enc.b64` is the current, VM-validated source.

| Property | Value |
| --- | --- |
| Plaintext SHA256 | `7844CFFAF5120CDFEF93DEA7CD39F3F3F423BE4F72656E41893E9D040C2125D5` |
| Plaintext size | 96,858 bytes (1,762 lines, CRLF) |
| Build marker | `20260804-fresh-read` |

Verified on the CloudTest VM: builds with `BUILD_EXIT=0`, and the
`ststest/UsageLogging` scenario completes **13/13 cases with 0 errors** and a
teardown that restores the farm to its pre-run baseline.

`UsageLoggingHandoff.cs.enc.b64` (marker `20260804-full-automation`) is the
**superseded** version. Do not build from it — it aborts mid-run and leaves
stray `LOGS_Auto_*` directories on the VM.

### Container formats

Both files are base64 text. The magic prefix tells you which format:

```text
ULH1 -> base64( "ULH1" || iv(16) || AES-256-CBC(plaintext)       || HMAC-SHA256(preceding) )
ULHZ -> base64( "ULHZ" || iv(16) || AES-256-CBC(gzip(plaintext)) || HMAC-SHA256(preceding) )
```

- AES key  = SHA-256(password)
- HMAC key = SHA-256("hmac:" + password)

Always verify the HMAC before decrypting. For `ULHZ`, gunzip after decrypting.
Confirm the plaintext SHA256 matches the table above before building.

`ULHZ` exists because the workstation that publishes these artifacts has all
archiver/crypto binaries blocked by group policy and runs PowerShell in
ConstrainedLanguage mode; gzip-before-encrypt keeps the payload small enough to
move. The VM has the opposite constraint (full crypto, no git).
