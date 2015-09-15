#!/bin/bash
# Change this if your clang-format executable is somewhere else
CLANG_FORMAT="$HOME/Library/Application Support/Alcatraz/Plug-ins/ClangFormat/bin/clang-format"

for DIRECTORY in LDNetDiagnoService LDNetDiagnoServiceDemo LDNetDiagnoServiceDemoTests
do
    echo "Formatting code under $DIRECTORY/"
    find "$DIRECTORY" \( -name '*.h' -or -name '*.m' -or -name '*.mm' \) -print0 | xargs -0 "$CLANG_FORMAT" -i
done
