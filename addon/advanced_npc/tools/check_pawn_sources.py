"""Read-only source checks; never invokes a Pawn compiler or build script.

Checks delimiters, project call arity, literal formatting, reserved parameters
and undeclared g* globals per plugin. This does not verify types or engine code.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import re

TOKENS = re.compile(r'"(?:\^.|[^"\r\n])*"|\'(?:\^.|[^\'\r\n])*\'|//[^\n]*|/\*[\s\S]*?\*/')
RESERVED = set('assert break case char const continue default defined do else enum exit for forward goto if native new operator public return sizeof sleep state static stock switch tagof while'.split())
DECL = re.compile(r'(?m)^\s*(?:stock|public|native|forward)\s+(?:\w+:)?(\w+)\s*\(')


def mask(source):
    return TOKENS.sub(lambda m: ''.join('\n' if c == '\n' else ' ' for c in m[0]), source)


def close_paren(source, start):
    depth = 1
    for pos in range(start, len(source)):
        depth += (source[pos] == '(')-(source[pos] == ')')
        if not depth:
            return pos
    raise ValueError('Unclosed parenthesis')


def arguments(source):
    if not source.strip():
        return []
    result, start, depth = [], 0, 0
    masked = mask(source)
    for pos, char in enumerate(masked):
        depth += char in '([{'
        depth -= char in ')]}'
        if char == ',' and depth == 0:
            result.append(source[start:pos].strip())
            start = pos+1
    result.append(source[start:].strip())
    return result


def check_delimiters(source):
    stack = []
    for pos, char in enumerate(mask(source)):
        if char in '([{':
            stack.append((char, pos))
        elif char in ')]}':
            if not stack or stack.pop()[0] != {')': '(', ']': '[', '}': '{'}[char]:
                return f'unmatched {char} at line {source.count(chr(10), 0, pos)+1}'
    if stack:
        char, pos = stack[-1]
        return f'unclosed {char} at line {source.count(chr(10), 0, pos)+1}'
    return None


def check_group(sources):
    errors, signatures, declarations, globals_ = [], {}, {}, set()
    for path, source in sources.items():
        clean = mask(source)
        problem = check_delimiters(source)
        if problem:
            errors.append(f'{path.name}: {problem}')
        globals_.update(re.findall(r'\bg[A-Z]\w*\b', '\n'.join(
            line for line in clean.splitlines() if line.startswith('new '))))
        declarations[path] = set()
        for match in DECL.finditer(clean):
            end = close_paren(clean, match.end())
            params = arguments(source[match.end():end])
            fixed = [p for p in params if '...' not in p]
            signatures[match[1]] = (sum('=' not in p for p in fixed),
                                    None if len(fixed) != len(params) else len(fixed))
            declarations[path].add(match.end()-1)
            for param in fixed:
                name = re.match(r'(?:const\s+)?&?(?:\w+:)?(\w+)\b', param)
                if name and name[1] in RESERVED:
                    errors.append(f'{path.name}: reserved parameter {match[1]}/{name[1]}')
    format_index = {'formatex': 2, 'format': 2, 'fprintf': 1, 'log_amx': 0,
                    'console_print': 1, 'client_print': 2}
    for path, source in sources.items():
        clean = mask(source)
        missing = set(re.findall(r'\bg[A-Z]\w*\b', clean))-globals_
        if missing:
            errors.append(f'{path.name}: undeclared globals {sorted(missing)}')
        for match in re.finditer(r'\b(\w+)\s*\(', clean):
            if match.end()-1 in declarations[path]:
                continue
            end = close_paren(clean, match.end())
            params = arguments(source[match.end():end])
            line = source.count('\n', 0, match.start())+1
            if match[1] in signatures:
                low, high = signatures[match[1]]
                if len(params) < low or high is not None and len(params) > high:
                    errors.append(f'{path.name}:{line}: {match[1]} has {len(params)} args, expected {low}..{high}')
            if match[1] in format_index:
                index = format_index[match[1]]
                if len(params) <= index or not params[index].startswith('"'):
                    continue
                fmt = params[index].replace('%%', '')
                specifiers = re.findall(r'%[-+ #0\d.*]*[A-Za-z]', fmt)
                expected = sum(2 if spec[-1] == 'L' else 1 for spec in specifiers)
                actual = len(params)-index-1
                if expected != actual:
                    errors.append(f'{path.name}:{line}: {match[1]} format expects {expected} values, has {actual}')
    return sorted(set(errors))


def include_directory(root):
    local = root/'LOCAL.md'
    match = re.search(r'^\| `ANPC_INCLUDE_DIR` \| `([^`]+)`',
                      local.read_text(encoding='utf-8-sig'), re.M)
    if not match or not Path(match[1]).is_dir():
        raise ValueError('Configure ANPC_INCLUDE_DIR in LOCAL.md')
    return Path(match[1])


def collect(path, include, sources):
    if path in sources:
        return
    source = path.read_text(encoding='utf-8-sig')
    sources[path] = source
    for name in re.findall(r'(?m)^#include "advanced_npc/([^"\n]+)"', source):
        collect(include/(name+'.inc'), include, sources)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--includes', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    include = args.includes or include_directory(root)
    errors, seen = [], set()
    for plugin in sorted(root.glob('*.sma')):
        sources = {}
        collect(plugin, include, sources)
        seen.update(sources)
        errors.extend(f'{plugin.name}: {error}' for error in check_group(sources))
    if errors:
        print('\n'.join(errors))
        return 1
    print(f'Checked {len(seen)} Pawn sources across six plugins; no compiler executed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
