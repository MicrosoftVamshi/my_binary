# my_binary

Non-confidential deployment artifacts for CloudTest SharePoint VM debugging.
See `cloudtest-sharepoint-vm-test-authoring-guide.md` — section 0 for the working
procedure, section 10 for the deployment workflow.

## Contents

| File | Purpose |
| --- | --- |
| `UsageLoggingHandoff_src.7z` | **Current** validated source for the UsageLoggingHandoff suite (password-protected) |
| `UsageLoggingHandoff.cs.gz.enc.b64` | Previous source, `ULHZ` container (superseded) |
| `UsageLoggingHandoff.cs.enc.b64` | Older source, `ULH1` container (superseded — do not build from it) |
| `UsageLoggingHandoff.scn` / `usage_logging.scn` | Generated Motif scenario |
| `MS.Internal.Test.Automation.Office.Osg.Wss.Tests.dll` | Prebuilt test DLL |
| `WssTestsDllPortable_LocalSearch_20260804.zip` | Password-protected portable build tree |
| `tools/7zip/` | Portable 7-Zip for VM-side extraction |

Passwords are **not** stored in this repository (guide section 10). Obtain them
through the approved secure channel.

## UsageLoggingHandoff — current artifact

`UsageLoggingHandoff_src.7z` (AES-256, encrypted headers).

| Property | Value |
| --- | --- |
| Plaintext SHA256 | `A72A3878A8F93483BEE99A43CBE526069DC50E1EC843B7AEE6CC116F5E3460B7` |
| Plaintext size | 108,601 bytes (2,002 lines, CRLF) |
| Build marker | `20260804-diagnostics` |
| Built DLL SHA256 | `7685A02BEB94A26FB39DD13CC2D82847E921ED81B696D213252C8FE7D0B349D7` |

Extract, then **verify the hash before building**:

```powershell
& '.\tools\7zip\7z.exe' x UsageLoggingHandoff_src.7z -o<dest> -p<password>
(Get-FileHash '<dest>\UsageLoggingHandoff.cs' -Algorithm SHA256).Hash
```

### Validation status

Verified on the CloudTest VM: `BUILD_EXIT=0`, and the `ststest/UsageLogging`
scenario completes **13/13 cases with 0 errors**, reproduced across **two
back-to-back runs** (`20260804_184628`, `20260805_040835`) with the farm returned
to its pre-run baseline each time:

```text
ERRORS=0  COMPLETED=13  DISTINCT=13
MARKER=1  OLDMARKERS=0        # the intended build loaded
BASELINE_OK=2                 # baseline verified at Setup and Teardown
LEAKS STRAY=0 TASKS=0 TMP=0 ORPHAN_DBS=0 TRACING=1
```

The rerun wrapper prints `Test failed. (exit code 2)` even on a green run — that
is a harness artifact-copy failure. `Results.otl` is authoritative.

### Superseded artifacts

`UsageLoggingHandoff.cs.enc.b64` (marker `20260804-full-automation`) aborts mid-run
and leaves stray `LOGS_Auto_*` directories on the VM. `UsageLoggingHandoff.cs.gz.enc.b64`
(marker `20260804-fresh-read`) is correct but lacks the diagnostic assertions.

Both are base64 text; the magic prefix identifies the container:

```text
ULH1 -> base64( "ULH1" || iv(16) || AES-256-CBC(plaintext)       || HMAC-SHA256(preceding) )
ULHZ -> base64( "ULHZ" || iv(16) || AES-256-CBC(gzip(plaintext)) || HMAC-SHA256(preceding) )
```

AES key = `SHA-256(password)`; HMAC key = `SHA-256("hmac:" + password)`. Verify the
HMAC before decrypting. These formats exist because the publishing workstation had
every archiver blocked by group policy at the time; 7-Zip has since been unblocked,
so new artifacts use `.7z`.
