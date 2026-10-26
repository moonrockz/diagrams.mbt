# Test-only ZenUML reference

The lock fixes the Mermaid ZenUML plugin to 1.0.1, core to 3.47.9, and ANTLR to
4.11.0. The plugin's core range is overridden. None of these dependencies enters
MoonBit library modules or generated SVG/HTML.

The npm core metadata identifies gitHead
`e3f93e0eb65d23fa3520e8691a5bca883853aa4b`. Its source package.json says 4.0.0;
the npm artifact says 3.47.9. The source archive is checked separately by SHA256.
The oracle calls its parser, participant collector and renderer statement walker.
Assignment replies are projected from the upstream Assignment context because
the older message collector omits them. Expressions are never evaluated.

Run `mise run native-mermaid-corpus:reference -- --check` to repeat both independent
reference extractions and check canonical native syntax. Run
`mise run validate:native-mermaid-corpus` to verify frozen files and portable
embeddings without JavaScript or network access.
