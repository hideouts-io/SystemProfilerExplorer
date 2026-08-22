## Summary

Describe the user-visible or technical change and why it is needed.

## Validation

- [ ] `./scripts/check-publication-boundary.sh`
- [ ] `xcodebuild -project SystemProfilerExplorer.xcodeproj -scheme SystemProfilerExplorer -destination 'platform=macOS' build test`
- [ ] Relevant live macOS flow checked when the change affects collection or UI behavior

## Privacy review

- [ ] No raw or full profiler report is included
- [ ] No serial number, UUID, UDID, address, user path, installed-software list, or other host fingerprint is included
- [ ] Test data is synthetic and screenshots are sanitized
- [ ] New profiler interpretations state their limitations and do not label normal output as compromise without evidence
