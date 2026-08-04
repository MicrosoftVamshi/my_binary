# Local_Search drop

Password-protected build/run drop for the SharePoint **Search Service Application**
scenario on a CloudTest VM.

## Contents

| Path | Purpose |
| --- | --- |
| `pkg/pkg_src.7z` | Full `WssTestsDllPortable` tree + scenario + scripts (published once) |
| `pkg/pkg_run.7z` | Per-iteration `src/Local_Search/*.cs` + scripts (small, published often) |
| `publish-src.ps1` | Builds and pushes `pkg_src.7z` |
| `publish.ps1` | Builds and pushes `pkg_run.7z` |

## VM workflow

Drop root on the VM is `C:\searchdrop`.

```powershell
# once
.\scripts\Refresh.ps1        # pull latest pkg_run.7z and extract

# each cycle
.\scripts\01-Baseline.ps1    # capture pre-setup farm state (do this BEFORE anything else)
.\scripts\02-Build.ps1       # build the test DLL on the VM
.\scripts\03-Run.ps1         # stage the scenario and launch tc.exe
.\scripts\04-Report.ps1      # parse the OTL for pass/fail

# when finished
.\scripts\09-Teardown.ps1            # dry run - shows what would be removed
.\scripts\09-Teardown.ps1 -Apply     # restore the VM to the captured baseline
```

`01-Baseline.ps1` must run before any provisioning, because `09-Teardown.ps1`
compares live Search state against `baseline.json` and removes only the difference.

## Restore guarantee

Two independent layers keep the VM clean:

1. The test's own `CleanUp` calls `SSASetup.RemoveCreatedArtifacts()`, which removes
   only the artifacts that setup created in that run.
2. `09-Teardown.ps1 -Apply` reconciles anything left behind (for example after a run
   was killed) against `baseline.json` and prints `RESTORED=True/False`.
