# Enable all rules by default
all

# Extend line length
rule 'MD013', :line_length => 100, :code_blocks => false

# Allow two trailing space (for forcing line break)
rule 'MD009', :br_spaces => 2

# Allow multiple consecutive blank lines (specially in code blocks)
exclude_rule 'MD012'
