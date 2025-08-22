#!/bin/bash

# Multi-Language Codebase Analysis Script
# Creates detailed reports on file structure, summaries, and optional contents/linting.
# Supports Python, Rust, C#, JS/TS, Java, Go, etc.
# Usage: ./analyze_codebase.sh [options] <directory_path>
# Options:
#   --full: Generate full file contents report (optional).
#   --lint: Run language-specific linters and generate lint_report.txt.
#   --output=DIR: Specify output directory (defaults to timestamped).
#   --help: Show this help message.

set -e

# Parse options
FULL=0
LINT=0
OUTPUT_DIR=""
TARGET_DIR=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --full) FULL=1; shift ;;
        --lint) LINT=1; shift ;;
        --output=*) OUTPUT_DIR="${1#*=}"; shift ;;
        --help) echo "Usage: $0 [options] <directory_path>"; echo "Options: --full, --lint, --output=DIR, --help"; exit 0 ;;
        *) TARGET_DIR="$1"; shift ;;
    esac
done

# Validate target dir
if [ -z "$TARGET_DIR" ] || [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Provide a valid directory path. Usage: $0 [options] <directory_path>"
    exit 1
fi

# Set output dir
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="codebase_analysis_report_$(date +%Y%m%d_%H%M%S)"
fi
mkdir -p "$OUTPUT_DIR"

echo "Starting multi-language code analysis of: $TARGET_DIR"
echo "Reports will be in: $OUTPUT_DIR"
echo "Full contents: $( [ $FULL -eq 1 ] && echo "Yes" || echo "No" )"
echo "Linting: $( [ $LINT -eq 1 ] && echo "Yes" || echo "No" )"

# Common exclusions (expandable)
EXCLUDE_PATHS="-not -path '*/\.*' -not -path '*/__pycache__/*' -not -path '*/.pytest_cache/*' -not -path '*/.mypy_cache/*' -not -path '*/.tox/*' -not -path '*/venv/*' -not -path '*/env/*' -not -path '*/.env/*' -not -path '*/node_modules/*' -not -path '*/target/*' -not -path '*/bin/*' -not -path '*/obj/*' -not -path '*/.vs/*' -not -path '*/.idea/*' -not -path '*/.vscode/*' -not -path '*/coverage/*' -not -path '*/dist/*' -not -path '*/build/*'"

# 1. Generate file tree structure
echo "Generating file tree structure report..."
if command -v tree &> /dev/null; then
    tree -n -I "__pycache__|.git|.pytest_cache|.mypy_cache|.tox|venv|env|.env|node_modules|target|bin|obj|.vs|.idea|.vscode|coverage|dist|build" "$TARGET_DIR" > "$OUTPUT_DIR/file_structure.txt"
else
    eval "find \"$TARGET_DIR\" $EXCLUDE_PATHS -type f -o -type d 2>/dev/null | sort | sed 's/[^/]*\//|   /g;s/| *\([^| ]\)/+--- \1/g'" > "$OUTPUT_DIR/file_structure.txt"
fi

# 2. Optional: Full file contents (if --full)
if [ $FULL -eq 1 ]; then
    echo "Generating file content report..."
    CONTENT_REPORT="$OUTPUT_DIR/file_contents.txt"
    echo "MULTI-LANGUAGE FILE CONTENTS REPORT" > "$CONTENT_REPORT"
    echo "=================" >> "$CONTENT_REPORT"
    echo "Directory: $TARGET_DIR" >> "$CONTENT_REPORT"
    echo "Generated on: $(date)" >> "$CONTENT_REPORT"
    echo "=================" >> "$CONTENT_REPORT"

    # Code extensions (expanded for more langs)
    CODE_EXTENSIONS="py|pyx|pyi|ipynb|rs|cs|csproj|sln|js|jsx|ts|tsx|java|go|cpp|c|h|hpp|cc|cxx|php|rb|swift|kt|scala|clj|hs|ml|f|fs|r|sql|html|css|scss|sass|less|xml|yaml|yml|json|toml|cfg|ini|md|txt|dockerfile|makefile|cmake|gradle|pom|requirements|pipfile|pyproject|cargo|package|gemfile|composer"

    eval "find \"$TARGET_DIR\" -type f $EXCLUDE_PATHS 2>/dev/null | grep -E \"\.(${CODE_EXTENSIONS})$|requirements.*\.txt$|Pipfile$|pyproject\.toml$|Cargo\.toml$|Cargo\.lock$|package\.json$|\.csproj$|\.sln$|Gemfile$|composer\.json$|Makefile$|Dockerfile$\" | sort" | while read -r file; do
        file_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
        if [ "$file_size" -gt 1048576 ]; then
            echo "Skipping large file: $file ($file_size bytes)"
            echo "==============================================" >> "$CONTENT_REPORT"
            echo "FILE: $file (SKIPPED - Too large: $file_size bytes)" >> "$CONTENT_REPORT"
            echo "==============================================" >> "$CONTENT_REPORT"
            continue
        fi
        echo "==============================================" >> "$CONTENT_REPORT"
        echo "FILE: $file (SIZE: $file_size bytes)" >> "$CONTENT_REPORT"
        echo "==============================================" >> "$CONTENT_REPORT"
        if [ "$file_size" -eq 0 ]; then
            echo "HIGHLIGHT: EMPTY FILE" >> "$CONTENT_REPORT"
        elif [ "$file_size" -lt 100 ]; then
            echo "HIGHLIGHT: SMALL FILE" >> "$CONTENT_REPORT"
        fi
        cat "$file" >> "$CONTENT_REPORT" 2>/dev/null || echo "ERROR: Could not read file" >> "$CONTENT_REPORT"
        echo "" >> "$CONTENT_REPORT"
    done
fi

# 3. Generate summary report
echo "Generating summary report..."
SUMMARY_REPORT="$OUTPUT_DIR/summary.txt"
echo "MULTI-LANGUAGE CODE ANALYSIS SUMMARY" > "$SUMMARY_REPORT"
echo "=================" >> "$SUMMARY_REPORT"
echo "Directory: $TARGET_DIR" >> "$SUMMARY_REPORT"
echo "Generated on: $(date)" >> "$SUMMARY_REPORT"
echo "=================" >> "$SUMMARY_REPORT"

# File counts by extension
echo "File count by extension:" >> "$SUMMARY_REPORT"
eval "find \"$TARGET_DIR\" -type f $EXCLUDE_PATHS 2>/dev/null | grep -E '\.[a-zA-Z0-9]+$' | sed 's/.*\.//' | sort | uniq -c | sort -nr" >> "$SUMMARY_REPORT"

# Total/Avg size
total_files=$(eval "find \"$TARGET_DIR\" -type f $EXCLUDE_PATHS 2>/dev/null | wc -l")
total_size=$(eval "find \"$TARGET_DIR\" -type f $EXCLUDE_PATHS -exec stat -c%s {} + 2>/dev/null | awk '{sum+=\$1} END {print sum}'")
avg_size=$((total_size / total_files)) 2>/dev/null || avg_size=0
echo "Total files: $total_files | Total size: $total_size bytes | Avg size: $avg_size bytes" >> "$SUMMARY_REPORT"

# Empties/Small
echo "EMPTY AND SMALL FILES ANALYSIS" >> "$SUMMARY_REPORT"
echo "=============================" >> "$SUMMARY_REPORT"
echo "Empty files (size 0 bytes):" >> "$SUMMARY_REPORT"
eval "find \"$TARGET_DIR\" -type f -size 0 $EXCLUDE_PATHS 2>/dev/null | sort" >> "$SUMMARY_REPORT"
echo "" >> "$SUMMARY_REPORT"
echo "Small files (<100 bytes, excluding empty):" >> "$SUMMARY_REPORT"
eval "find \"$TARGET_DIR\" -type f -size -100c ! -size 0 $EXCLUDE_PATHS 2>/dev/null | sort" >> "$SUMMARY_REPORT"
echo "" >> "$SUMMARY_REPORT"

# Language-specific analysis
echo "LANGUAGE-SPECIFIC ANALYSIS" >> "$SUMMARY_REPORT"
echo "=========================" >> "$SUMMARY_REPORT"

# Python Analysis
python_files=$(eval "find \"$TARGET_DIR\" -name '*.py' $EXCLUDE_PATHS 2>/dev/null | wc -l")
if [ "$python_files" -gt 0 ]; then
    echo "" >> "$SUMMARY_REPORT"
    echo "PYTHON ANALYSIS:" >> "$SUMMARY_REPORT"
    echo "Python files count: $python_files" >> "$SUMMARY_REPORT"
    echo "Python packages count: $(eval "find \"$TARGET_DIR\" -name '__init__.py' $EXCLUDE_PATHS 2>/dev/null | wc -l")" >> "$SUMMARY_REPORT"
    echo "Test files count: $(eval "find \"$TARGET_DIR\" -name '*test*.py' -o -name 'test_*.py' $EXCLUDE_PATHS 2>/dev/null | wc -l")" >> "$SUMMARY_REPORT"
    
    echo "Python imports found:" >> "$SUMMARY_REPORT"
    grep -r -h "^[ \t]*\(from .* import\|import \)" --include="*.py" "$TARGET_DIR" 2>/dev/null | sed 's/.*import \([^ .;]*\).*/\1/' | sort | uniq -c | sort -nr | head -10 >> "$SUMMARY_REPORT"
    
    echo "Python classes found:" >> "$SUMMARY_REPORT"
    grep -r -h "^[ \t]*class " --include="*.py" "$TARGET_DIR" 2>/dev/null | sed 's/.*class \([^(:]*\).*/\1/' | sort | uniq | head -20 >> "$SUMMARY_REPORT"
fi

# Rust Analysis
rust_files=$(eval "find \"$TARGET_DIR\" -name '*.rs' $EXCLUDE_PATHS 2>/dev/null | wc -l")
if [ "$rust_files" -gt 0 ]; then
    echo "" >> "$SUMMARY_REPORT"
    echo "RUST ANALYSIS:" >> "$SUMMARY_REPORT"
    echo "Rust files count: $rust_files" >> "$SUMMARY_REPORT"
    echo "Cargo projects count: $(eval "find \"$TARGET_DIR\" -name 'Cargo.toml' $EXCLUDE_PATHS 2>/dev/null | wc -l")" >> "$SUMMARY_REPORT"
    
    echo "Rust external crates used:" >> "$SUMMARY_REPORT"
    grep -r -h "^use " --include="*.rs" "$TARGET_DIR" 2>/dev/null | sed 's/.*use \([^:;]*\).*/\1/' | grep -v "^crate\|^self\|^super" | sort | uniq -c | sort -nr | head -10 >> "$SUMMARY_REPORT"
    
    echo "Rust structs found:" >> "$SUMMARY_REPORT"
    grep -r -h "^[ \t]*struct " --include="*.rs" "$TARGET_DIR" 2>/dev/null | sed 's/.*struct \([^{<]*\).*/\1/' | sort | uniq | head -20 >> "$SUMMARY_REPORT"
    
    echo "Rust enums found:" >> "$SUMMARY_REPORT"
    grep -r -h "^[ \t]*enum " --include="*.rs" "$TARGET_DIR" 2>/dev/null | sed 's/.*enum \([^{<]*\).*/\1/' | sort | uniq | head -20 >> "$SUMMARY_REPORT"
    
    echo "Rust traits found:" >> "$SUMMARY_REPORT"
    grep -r -h "^[ \t]*trait " --include="*.rs" "$TARGET_DIR" 2>/dev/null | sed 's/.*trait \([^{<]*\).*/\1/' | sort | uniq | head -20 >> "$SUMMARY_REPORT"
fi

# C# Analysis
csharp_files=$(eval "find \"$TARGET_DIR\" -name '*.cs' $EXCLUDE_PATHS 2>/dev/null | wc -l")
if [ "$csharp_files" -gt 0 ]; then
    echo "" >> "$SUMMARY_REPORT"
    echo "C# ANALYSIS:" >> "$SUMMARY_REPORT"
    echo "C# files count: $csharp_files" >> "$SUMMARY_REPORT"
    echo "C# project files count: $(eval "find \"$TARGET_DIR\" -name '*.csproj' -o -name '*.sln' $EXCLUDE_PATHS 2>/dev/null | wc -l")" >> "$SUMMARY_REPORT"
    
    echo "C# using statements:" >> "$SUMMARY_REPORT"
    grep -r -h "^[ \t]*using " --include="*.cs" "$TARGET_DIR" 2>/dev/null | sed 's/.*using \([^;]*\).*/\1/' | sort | uniq -c | sort -nr | head -10 >> "$SUMMARY_REPORT"
    
    echo "C# classes found:" >> "$SUMMARY_REPORT"
    grep -r -h "[ \t]*class " --include="*.cs" "$TARGET_DIR" 2>/dev/null | sed 's/.*class \([^{:<]*\).*/\1/' | sort | uniq | head -20 >> "$SUMMARY_REPORT"
    
    echo "C# interfaces found:" >> "$SUMMARY_REPORT"
    grep -r -h "[ \t]*interface " --include="*.cs" "$TARGET_DIR" 2>/dev/null | sed 's/.*interface \([^{:<]*\).*/\1/' | sort | uniq | head -20 >> "$SUMMARY_REPORT"
fi

# JavaScript/TypeScript Analysis
js_files=$(eval "find \"$TARGET_DIR\" -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o -name '*.tsx' $EXCLUDE_PATHS 2>/dev/null | wc -l")
if [ "$js_files" -gt 0 ]; then
    echo "" >> "$SUMMARY_REPORT"
    echo "JAVASCRIPT/TYPESCRIPT ANALYSIS:" >> "$SUMMARY_REPORT"
    echo "JS/TS files count: $js_files" >> "$SUMMARY_REPORT"
    echo "Package.json files count: $(eval "find \"$TARGET_DIR\" -name 'package.json' $EXCLUDE_PATHS 2>/dev/null | wc -l")" >> "$SUMMARY_REPORT"
    
    echo "Import statements found:" >> "$SUMMARY_REPORT"
    grep -r -h "^[ \t]*import .* from |^[ \t]*from " --include="*.{js,jsx,ts,tsx}" "$TARGET_DIR" 2>/dev/null | sed "s/.*from ['\"]\\([^'\"]*\\).*/\\1/" | sort | uniq -c | sort -nr | head -10 >> "$SUMMARY_REPORT"
fi

# Java Analysis
java_files=$(eval "find \"$TARGET_DIR\" -name '*.java' $EXCLUDE_PATHS 2>/dev/null | wc -l")
if [ "$java_files" -gt 0 ]; then
    echo "" >> "$SUMMARY_REPORT"
    echo "JAVA ANALYSIS:" >> "$SUMMARY_REPORT"
    echo "Java files count: $java_files" >> "$SUMMARY_REPORT"
    echo "Maven/Gradle projects count: $(eval "find \"$TARGET_DIR\" -name 'pom.xml' -o -name 'build.gradle' $EXCLUDE_PATHS 2>/dev/null | wc -l")" >> "$SUMMARY_REPORT"
    
    echo "Java imports found:" >> "$SUMMARY_REPORT"
    grep -r -h "^[ \t]*import " --include="*.java" "$TARGET_DIR" 2>/dev/null | sed 's/.*import \([^;]*\).*/\1/' | sort | uniq -c | sort -nr | head -10 >> "$SUMMARY_REPORT"
    
    echo "Java classes found:" >> "$SUMMARY_REPORT"
    grep -r -h "[ \t]*class " --include="*.java" "$TARGET_DIR" 2>/dev/null | sed 's/.*class \([^{<]*\).*/\1/' | sort | uniq | head -20 >> "$SUMMARY_REPORT"
fi

# Go Analysis
go_files=$(eval "find \"$TARGET_DIR\" -name '*.go' $EXCLUDE_PATHS 2>/dev/null | wc -l")
if [ "$go_files" -gt 0 ]; then
    echo "" >> "$SUMMARY_REPORT"
    echo "GO ANALYSIS:" >> "$SUMMARY_REPORT"
    echo "Go files count: $go_files" >> "$SUMMARY_REPORT"
    echo "Go modules count: $(eval "find \"$TARGET_DIR\" -name 'go.mod' $EXCLUDE_PATHS 2>/dev/null | wc -l")" >> "$SUMMARY_REPORT"
    
    echo "Go imports found:" >> "$SUMMARY_REPORT"
    grep -r -h "^import \|^\t\"" --include="*.go" "$TARGET_DIR" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' | sort | uniq -c | sort -nr | head -10 >> "$SUMMARY_REPORT"
fi

# Programming patterns analysis
echo "" >> "$SUMMARY_REPORT"
echo "PROGRAMMING PATTERNS ANALYSIS:" >> "$SUMMARY_REPORT"
echo "- Design patterns (Observable, Factory, etc.): $(grep -ri 'interface\|abstract\|factory\|observer\|singleton\|builder\|adapter' --include='*.{py,rs,cs,java,js,ts,go}' \"$TARGET_DIR\" 2>/dev/null | wc -l)" >> "$SUMMARY_REPORT"
echo "- Error/Exception handling: $(grep -ri 'try\|catch\|except\|panic\|unwrap\|Result\|Option\|error' --include='*.{py,rs,cs,java,js,ts,go}' \"$TARGET_DIR\" 2>/dev/null | wc -l)" >> "$SUMMARY_REPORT"
echo "- Async/concurrent programming: $(grep -ri 'async\|await\|thread\|spawn\|tokio\|Task\|Promise\|goroutine\|channel' --include='*.{py,rs,cs,java,js,ts,go}' \"$TARGET_DIR\" 2>/dev/null | wc -l)" >> "$SUMMARY_REPORT"
echo "- Testing frameworks usage: $(grep -ri 'test\|assert\|mock\|junit\|pytest\|jest\|#\[test\]\|nunit\|xunit' --include='*.{py,rs,cs,java,js,ts,go}' \"$TARGET_DIR\" 2>/dev/null | wc -l)" >> "$SUMMARY_REPORT"

# Dependencies analysis
echo "" >> "$SUMMARY_REPORT"
echo "DEPENDENCIES ANALYSIS:" >> "$SUMMARY_REPORT"
if [ -f "$TARGET_DIR/requirements.txt" ]; then echo "Python requirements.txt found" >> "$SUMMARY_REPORT"; fi
if [ -f "$TARGET_DIR/Pipfile" ]; then echo "Python Pipfile found" >> "$SUMMARY_REPORT"; fi
if [ -f "$TARGET_DIR/pyproject.toml" ]; then echo "Python pyproject.toml found" >> "$SUMMARY_REPORT"; fi
if [ -f "$TARGET_DIR/Cargo.toml" ]; then echo "Rust Cargo.toml found" >> "$SUMMARY_REPORT"; fi
eval "find \"$TARGET_DIR\" -name '*.csproj' $EXCLUDE_PATHS 2>/dev/null" | while read -r csproj; do echo "C# project file found: $csproj" >> "$SUMMARY_REPORT"; done
if [ -f "$TARGET_DIR/package.json" ]; then echo "Node.js package.json found" >> "$SUMMARY_REPORT"; fi
if [ -f "$TARGET_DIR/pom.xml" ]; then echo "Java Maven pom.xml found" >> "$SUMMARY_REPORT"; fi
if [ -f "$TARGET_DIR/build.gradle" ]; then echo "Java Gradle build.gradle found" >> "$SUMMARY_REPORT"; fi
if [ -f "$TARGET_DIR/go.mod" ]; then echo "Go go.mod found" >> "$SUMMARY_REPORT"; fi

# 4. Optional: Linting
if [ $LINT -eq 1 ]; then
    LINT_REPORT="$OUTPUT_DIR/lint_report.txt"
    echo "Running linters..." > "$LINT_REPORT"
    # Python
    if command -v ruff &> /dev/null && [ "$python_files" -gt 0 ]; then
        echo "Python (Ruff):" >> "$LINT_REPORT"
        ruff check "$TARGET_DIR" >> "$LINT_REPORT" 2>&1 || true
    fi
    # Rust
    if command -v rustfmt &> /dev/null && [ "$rust_files" -gt 0 ]; then
        echo "Rust (rustfmt):" >> "$LINT_REPORT"
        rustfmt --check "$TARGET_DIR"/*.rs >> "$LINT_REPORT" 2>&1 || true
        if command -v cargo-clippy &> /dev/null; then cargo clippy -- -D warnings >> "$LINT_REPORT" 2>&1 || true; fi
    fi
    # C#
    if command -v dotnet &> /dev/null && [ "$csharp_files" -gt 0 ]; then
        echo "C# (dotnet format):" >> "$LINT_REPORT"
        dotnet format --verify-no-changes "$TARGET_DIR" >> "$LINT_REPORT" 2>&1 || true
    fi
    # JS/TS
    if command -v eslint &> /dev/null && [ "$js_files" -gt 0 ]; then
        echo "JS/TS (ESLint):" >> "$LINT_REPORT"
        eslint "$TARGET_DIR" >> "$LINT_REPORT" 2>&1 || true
    fi
    # Java
    if [ -f checkstyle.jar ] && [ "$java_files" -gt 0 ]; then
        echo "Java (Checkstyle):" >> "$LINT_REPORT"
        java -jar checkstyle.jar -c /google_checks.xml "$TARGET_DIR"/*.java >> "$LINT_REPORT" 2>&1 || true
    fi
    # Go
    if command -v gofmt &> /dev/null && [ "$go_files" -gt 0 ]; then
        echo "Go (gofmt):" >> "$LINT_REPORT"
        gofmt -l "$TARGET_DIR"/*.go >> "$LINT_REPORT" 2>&1 || true
    fi
fi

# 5. Generate multi-language guide
GUIDE_REPORT="$OUTPUT_DIR/multi_language_analysis_guide.txt"
echo "Generating multi-language analysis guide..."
cat > "$GUIDE_REPORT" << 'EOL'
MULTI-LANGUAGE CODE ANALYSIS GUIDE
=================================

This guide provides insights into various programming language codebases and common patterns.

1. PYTHON
---------
Project Structure:
- __init__.py: Package initialization
- requirements.txt: Dependencies
- setup.py: Package installation
- pyproject.toml: Modern project config

Common Patterns:
- Classes and inheritance
- Decorators (@property, @staticmethod)
- List/dict comprehensions
- Context managers (with statements)
- Exception handling (try/except)

2. RUST
-------
Project Structure:
- Cargo.toml: Project manifest
- src/main.rs: Binary crate entry
- src/lib.rs: Library crate entry
- tests/: Integration tests

Common Patterns:
- Ownership and borrowing
- Pattern matching (match)
- Error handling (Result<T, E>)
- Traits and implementations
- Modules (mod keyword)

3. C#
-----
Project Structure:
- .csproj: Project file
- .sln: Solution file
- Program.cs: Entry point
- app.config: Configuration

Common Patterns:
- Classes and interfaces
- Properties and attributes
- LINQ expressions
- Async/await
- Exception handling (try/catch)

4. JAVASCRIPT/TYPESCRIPT
-----------------------
Project Structure:
- package.json: Dependencies
- tsconfig.json: TypeScript config
- webpack.config.js: Bundler config
- .babelrc: Transpiler config

Common Patterns:
- Modules (import/export)
- Promises and async/await
- Arrow functions
- Destructuring
- Spread operator

5. JAVA
-------
Project Structure:
- pom.xml: Maven dependencies
- build.gradle: Gradle build
- src/main/java: Source code
- src/test/java: Tests

Common Patterns:
- Classes and interfaces
- Inheritance and polymorphism
- Generics
- Annotations
- Exception handling

6. GO
-----
Project Structure:
- go.mod: Module definition
- main.go: Entry point
- internal/: Private packages
- cmd/: Command applications

Common Patterns:
- Interfaces
- Goroutines and channels
- Error handling (error type)
- Defer statements
- Package organization

TESTING FRAMEWORKS BY LANGUAGE
=============================
- Python: unittest, pytest, nose
- Rust: Built-in test framework
- C#: NUnit, MSTest, xUnit
- JavaScript: Jest, Mocha, Jasmine
- Java: JUnit, TestNG
- Go: Built-in testing package

DEPENDENCY MANAGEMENT
===================
- Python: pip, pipenv, poetry
- Rust: Cargo
- C#: NuGet
- JavaScript: npm, yarn, pnpm
- Java: Maven, Gradle
- Go: Go modules

BUILD TOOLS
===========
- Python: setuptools, poetry
- Rust: Cargo
- C#: MSBuild, dotnet CLI
- JavaScript: Webpack, Vite, Rollup
- Java: Maven, Gradle, Ant
- Go: go build

DOCUMENTATION TOOLS
==================
- Python: Sphinx, mkdocs
- Rust: rustdoc
- C#: XML documentation
- JavaScript: JSDoc, TypeDoc
- Java: Javadoc
- Go: godoc

EOL

echo "Analysis complete!"
echo "- File structure: $OUTPUT_DIR/file_structure.txt"
if [ $FULL -eq 1 ]; then echo "- File contents: $OUTPUT_DIR/file_contents.txt"; fi
echo "- Summary: $OUTPUT_DIR/summary.txt"
if [ $LINT -eq 1 ]; then echo "- Lint report: $OUTPUT_DIR/lint_report.txt"; fi
echo "- Multi-language guide: $OUTPUT_DIR/multi_language_analysis_guide.txt"