# Samples from other Macs

Each `*.sample.json` file here is an anonymized report from a real Mac. The tests in `SampleFixtureTests.swift` open every sample and check that:

- it opens and builds a search index;
- it is exactly what the app's anonymized export produces, so no personal value was added back by hand;
- every value in a field the app explains is recognized. A failure lists each new value, which needs a rule in `SystemProfilerExplorer/Core/Explanations/Values`.

## Adding a sample

1. In the app, switch to **Developer** mode, scan (the Full Report gives the most coverage), then choose **Share › Anonymized Sample…**.
2. Open the file and read it. The export keeps field names, numbers, on/off values, enumeration tokens, the Mac model, the macOS version, and the values of fields the app explains. It removes names, serial numbers, addresses, paths, and log text. If anything personal remains, don't share the file; open an issue describing the field instead.
3. Keep the file name the export suggests, such as `Sample-Mac15,3-macOS-26.0.sample.json`, and add it to this folder.
4. Run `./scripts/check-publication-boundary.sh` and the tests.

The most useful samples come from Macs unlike the ones already here: Intel Macs, Macs on macOS 13 or 14, desktops without a battery, Macs with external displays or docks, managed (MDM) Macs, and virtual machines.
