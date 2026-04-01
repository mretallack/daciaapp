#!/usr/bin/env python3
"""
Parse .xs files in import order and extract @symbol tokens.
Assigns IDs starting from 100000 in order of first encounter.
This replicates the NNG runtime's symbol_intern behaviour.
"""
import re
import os
import sys
from collections import OrderedDict

XS_ROOT = "/home/mark/git/daciaapp/xs_extract/data"
ENTRY = "yellowbox/src/main.xs"

# Well-known symbols (hardcoded IDs 0-13)
WELL_KNOWN = {
    "call": 0, "length": 1, "WHICH": 2, "serialize": 3, "getItem": 4,
    "splice": 5, "list": 6, "remoteConfig": 7, "iterator": 8,
    "constructor": 9, "proto": 10, "asyncIterator": 11, "dispose": 12,
    "asyncDispose": 13,
}

symbols = OrderedDict()  # name -> id
next_id = 100000
parsed_files = set()

def intern(name):
    global next_id
    if name in WELL_KNOWN:
        return WELL_KNOWN[name]
    if name not in symbols:
        symbols[name] = next_id
        next_id += 1
    return symbols[name]

def resolve_import(import_path, current_file):
    """Resolve an import path relative to current file or XS_ROOT."""
    if import_path.startswith("system://"):
        return None  # native module, skip
    if import_path.startswith("~/"):
        import_path = import_path[2:]
    if import_path.startswith("./"):
        base = os.path.dirname(current_file)
        resolved = os.path.normpath(os.path.join(base, import_path))
    elif import_path.startswith("../"):
        base = os.path.dirname(current_file)
        resolved = os.path.normpath(os.path.join(base, import_path))
    else:
        # Try xs_modules/ first, then relative
        resolved = os.path.join(XS_ROOT, "xs_modules", import_path)
        if not os.path.exists(resolved):
            resolved = os.path.join(XS_ROOT, import_path)
    return resolved

def parse_file(filepath):
    """Parse a .xs file: process imports first, then extract @symbols."""
    global next_id
    
    canon = os.path.realpath(filepath)
    if canon in parsed_files:
        return
    parsed_files.add(canon)
    
    if not os.path.exists(filepath):
        return
    
    with open(filepath, 'r', errors='replace') as f:
        content = f.read()
    
    # Process imports first (they execute before the file's own symbols)
    import_re = re.compile(r'import\s+.*?from\s+["\']([^"\']+)["\']|import\s+["\']([^"\']+)["\']')
    for m in import_re.finditer(content):
        imp = m.group(1) or m.group(2)
        if imp.endswith('.nss'):
            continue  # CSS, not script
        resolved = resolve_import(imp, filepath)
        if resolved and os.path.exists(resolved):
            parse_file(resolved)
    
    # Now extract @symbol tokens from this file
    # Match @word but not @@ or email addresses
    sym_re = re.compile(r'(?<![a-zA-Z0-9_.])@([a-zA-Z_][a-zA-Z0-9_]*)')
    for m in sym_re.finditer(content):
        name = m.group(1)
        if name in ('param', 'returns', 'type', 'override', 'deprecated'):
            # Could be JSDoc annotations — but in .xs they're real symbols
            pass
        intern(name)

# Parse from entry point
entry = os.path.join(XS_ROOT, ENTRY)
print(f"Parsing from: {entry}")
print(f"Starting ID: {next_id}")
print()

parse_file(entry)

print(f"Files parsed: {len(parsed_files)}")
print(f"Symbols found: {len(symbols)}")
print(f"ID range: 100000 - {next_id - 1}")
print()

# Print all symbols with IDs
print("=== Symbol Table ===")
for name, sid in symbols.items():
    print(f"  @{name:<30s} = {sid}")

# Print the ones we care about
print()
print("=== Key NFTP Symbols ===")
targets = ["device", "brand", "fileMapping", "freeSpace", "diskInfo",
           "ls", "name", "size", "children", "path",
           "md5", "sha1", "compact", "error", "response",
           "request", "returns", "control", "get",
           "stopStream", "pauseStream", "resumeStream",
           "getAndRemove"]
for t in targets:
    if t in symbols:
        print(f"  @{t:<30s} = {symbols[t]}")
    elif t in WELL_KNOWN:
        print(f"  @{t:<30s} = {WELL_KNOWN[t]} (well-known)")
    else:
        print(f"  @{t:<30s} = NOT FOUND")
