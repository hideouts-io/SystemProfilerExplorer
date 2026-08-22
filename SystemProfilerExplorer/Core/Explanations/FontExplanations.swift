import Foundation

func fontExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    switch softwareField(path) {
    case "path":
        return FieldExplanation(
            title: "Font Path",
            meaning: "This is the filesystem location of the font file or font collection discovered by System Information.",
            significance: "Location helps distinguish system, shared, user-installed, application-bundled, and nonstandard font sources.",
            interpretation: "File presence does not prove that an application used the font or that every embedded typeface is enabled and valid.",
            privacy: "Font paths can expose account names, project directories, mounted shares, or proprietary asset locations. Review them before sharing."
        )
    case "type":
        return FieldExplanation(
            title: "Font File Type",
            meaning: "This identifies the container or font technology reported for the file, such as OpenType, TrueType, or a collection format.",
            significance: "The format affects supported features, compatibility, embedding behavior, and how many typefaces a file can contain.",
            interpretation: "The type label is not a quality, licensing, validity, or usage verdict.",
            privacy: nil
        )
    case "enabled":
        return softwareBooleanExplanation(
            title: path.contains("typefaces") ? "Typeface Enabled" : "Font Enabled",
            meaning: "This reports whether macOS considers the font or typeface enabled for normal selection and use.",
            significance: "Disabled fonts generally remain installed but are withheld from ordinary font menus and matching.",
            interpretation: "Enabled does not prove that an application loaded or rendered the font, and application-specific font activation can differ.",
            reportedValue: reportedValue,
            privacy: nil
        )
    case "valid":
        return softwareBooleanExplanation(
            title: path.contains("typefaces") ? "Typeface Valid" : "Font Valid",
            meaning: "This reports whether the font passed the validation checks represented by System Information.",
            significance: "Validation can identify malformed or incompatible font data that may prevent reliable use.",
            interpretation: "A valid result is not a security audit, licensing approval, or guarantee that every application can render the font correctly.",
            reportedValue: reportedValue,
            privacy: nil
        )
    case "copy_protected":
        return fontBoolean(
            title: "Copy Protected",
            meaning: "This reports font metadata indicating restrictions related to copying or embedding.",
            significance: "The flag can affect document portability and permitted redistribution workflows.",
            interpretation: "This technical flag is not legal advice and does not replace the font license terms.",
            reportedValue: reportedValue
        )
    case "duplicate":
        return fontBoolean(
            title: "Duplicate Typeface",
            meaning: "This reports whether macOS detected another installed typeface that conflicts with or duplicates this one.",
            significance: "Duplicates can cause unexpected font selection, inconsistent rendering, and document portability issues.",
            interpretation: "Duplicate status does not establish which copy is authoritative or malicious; compare paths, versions, and font metadata.",
            reportedValue: reportedValue
        )
    case "embeddable":
        return fontBoolean(
            title: "Embeddable",
            meaning: "This reports whether the font metadata permits embedding the typeface in documents or other content.",
            significance: "Embedding can preserve appearance when a document is opened on a system that does not have the font installed.",
            interpretation: "The flag describes technical metadata and does not replace applicable licensing terms or distribution restrictions.",
            reportedValue: reportedValue
        )
    case "outline":
        return fontBoolean(
            title: "Outline Typeface",
            meaning: "This reports whether the typeface uses scalable outline data rather than only fixed-size bitmap glyphs.",
            significance: "Outline fonts can generally render at many sizes and resolutions without relying on a separate bitmap for each size.",
            interpretation: "Outline status is a format characteristic, not a quality, validity, or licensing verdict.",
            reportedValue: reportedValue
        )
    case "copyright", "trademark":
        return FieldExplanation(
            title: softwareField(path) == "copyright" ? "Font Copyright" : "Font Trademark",
            meaning: "This is rights or trademark metadata embedded by the font publisher.",
            significance: "It can help identify the asserted owner and distinguish official releases from repackaged or modified font files.",
            interpretation: "Embedded text is publisher-controlled and is not independent proof of ownership, authenticity, or licensing permission.",
            privacy: nil
        )
    case "description":
        return FieldExplanation(
            title: "Typeface Description",
            meaning: "This is descriptive metadata embedded in the typeface by its publisher.",
            significance: "It may explain the design, intended use, release, or naming of the typeface.",
            interpretation: "The text is not validated authorship, licensing, or security evidence.",
            privacy: nil
        )
    case "designer", "vendor":
        return FieldExplanation(
            title: softwareField(path) == "designer" ? "Typeface Designer" : "Font Vendor",
            meaning: "This is creator or vendor metadata embedded in the font.",
            significance: "It provides provenance context and can help distinguish similarly named font releases.",
            interpretation: "The metadata is self-declared and does not authenticate the file or prove licensing rights.",
            privacy: "Custom or internal fonts can identify an individual designer or organization. Review before publishing."
        )
    case "family", "fullname", "style", "unique":
        return fontNamingExplanation(field: softwareField(path))
    case "version":
        return FieldExplanation(
            title: "Typeface Version",
            meaning: "This is the version string embedded in the typeface metadata.",
            significance: "It helps distinguish revisions that may contain different glyphs, metrics, features, or fixes.",
            interpretation: "The version is publisher-controlled and is not proof of authenticity, validity, or license status.",
            privacy: nil
        )
    default:
        return nil
    }
}

private func fontBoolean(
    title: String,
    meaning: String,
    significance: String,
    interpretation: String,
    reportedValue: String
) -> FieldExplanation {
    softwareBooleanExplanation(
        title: title,
        meaning: meaning,
        significance: significance,
        interpretation: interpretation,
        reportedValue: reportedValue,
        privacy: nil
    )
}

private func fontNamingExplanation(field: String) -> FieldExplanation {
    let title: String = switch field {
    case "family": "Font Family"
    case "fullname": "Typeface Full Name"
    case "style": "Typeface Style"
    default: "Unique Typeface Name"
    }

    return FieldExplanation(
        title: title,
        meaning: "This is naming metadata embedded in the typeface for family grouping, style selection, display, or internal identification.",
        significance: "Font systems use these names to organize related faces and select the intended weight, width, and style.",
        interpretation: "Names are publisher-controlled and can collide across different files. They do not establish authenticity, file identity, or actual document use.",
        privacy: nil
    )
}
