"""Validate NAV 4 structure/counts (and optionally BSP identity), read-only.

Does not certify collision, reachability or execution by an NPC profile.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import shlex


def number(text, integer=False):
    pattern = r'[+-]?\d+' if integer else r'[+-]?(?:\d+(?:\.\d*)?|\.\d+)'
    if not re.fullmatch(pattern, text):
        raise ValueError('Expected a finite decimal field')
    value = int(text) if integer else float(text)
    if not math.isfinite(value):
        raise ValueError('Non-finite field')
    return value


def validate_lines(lines, bsp=None):
    nodes, areas, edges = [], [], set()
    header = None
    footer = False
    phase = 0
    area_buckets = {}
    for line_number, line in enumerate(lines, 1):
        try:
            if len(line.rstrip('\r\n')) > 382:
                raise ValueError('Record exceeds the Pawn line buffer')
            line = line.strip()
            if not line or line.startswith((';', '#')):
                continue
            fields = shlex.split(line)
            if header is None:
                if len(fields) != 5 or fields[:2] != ['ANPC_NAV', '4']:
                    raise ValueError('Expected ANPC_NAV 4 header')
                if number(fields[3], True) <= 0 or not re.fullmatch('[0-9a-f]{32}', fields[4]):
                    raise ValueError('Invalid BSP identity')
                header = fields
                continue
            if footer:
                raise ValueError('Record after END')
            kind = fields[0]
            if kind == 'N' and len(fields) == 7 and phase == 0:
                index = number(fields[1], True)
                point = tuple(number(field) for field in fields[2:5])
                radius, flags = number(fields[5]), number(fields[6], True)
                if index != len(nodes) or len(nodes) == 4096 or flags < 0 or flags & ~15:
                    raise ValueError('Invalid node ID/flags/capacity')
                if any(abs(value) > 65536 for value in point) or not 8 <= radius <= 64:
                    raise ValueError('Invalid node coordinates/radius')
                nodes.append(point)
            elif kind == 'A' and len(fields) == 11 and phase <= 1:
                phase = 1
                index, flags = number(fields[1], True), number(fields[10], True)
                values = [number(field) for field in fields[2:10]]
                low = values[:2]
                high = values[2:4]
                z, normal = values[4], values[5:]
                if index != len(areas) or len(areas) == 4096 or flags not in (0, 1):
                    raise ValueError('Invalid area ID/flags/capacity')
                if any(abs(value) > 65536 for value in values[:5]) or normal[2] < 0.7:
                    raise ValueError('Invalid area plane')
                if any(abs(value) > 1 for value in normal) or abs(sum(v*v for v in normal)-1) > 0.001:
                    raise ValueError('Invalid area normal')
                if any(not 32 <= high[i]-low[i] <= 256 or
                       math.floor(low[i]/256) != math.ceil(high[i]/256)-1 for i in range(2)):
                    raise ValueError('Invalid area bounds/index cell')
                corner_z = z-((high[0]-low[0])*normal[0]+(high[1]-low[1])*normal[1])/normal[2]
                if abs(corner_z) > 65536:
                    raise ValueError('Invalid area corner height')
                bucket = tuple(math.floor(value/256) for value in low)
                for other_low, other_high, other_z, other_normal, other_flags in area_buckets.get(bucket, []):
                    plane_z = other_z-((low[0]-other_low[0])*other_normal[0]+(low[1]-other_low[1])*other_normal[1])/other_normal[2]
                    if flags == other_flags and sum((normal[i]-other_normal[i])**2 for i in range(3)) <= 0.000001 and abs(plane_z-z) <= 0.05:
                        if all(low[i] >= other_low[i] and high[i] <= other_high[i] for i in range(2)):
                            raise ValueError('Duplicate/contained area ID')
                area = (low, high, z, normal, flags)
                area_buckets.setdefault(bucket, []).append(area)
                areas.append(area)
            elif kind == 'E' and len(fields) == 7:
                phase = 2
                origin, target, flags = [number(field, True) for field in fields[1:4]]
                velocity = tuple(number(field) for field in fields[4:7])
                if not (0 <= origin < len(nodes) and 0 <= target < len(nodes)) or origin == target:
                    raise ValueError('Invalid edge endpoints')
                if (origin, target) in edges or flags not in (0, 1, 2):
                    raise ValueError('Duplicate/invalid edge')
                if any(abs(v) > 1200 for v in velocity) or flags != 1 and any(velocity):
                    raise ValueError('Invalid edge velocity')
                if flags == 2 and nodes[target][2] >= nodes[origin][2]-18:
                    raise ValueError('Invalid drop height')
                edges.add((origin, target))
            elif kind == 'END' and len(fields) == 4:
                if [number(field, True) for field in fields[1:]] != [len(nodes), len(areas), len(edges)]:
                    raise ValueError('END counts do not match records')
                footer = True
            else:
                raise ValueError('Invalid record or record order')
        except ValueError as error:
            raise ValueError(f'line {line_number}: {error}') from error
    if header is None or not footer or not (nodes or areas):
        raise ValueError('Missing header/END or empty navigation')
    if bsp is not None:
        with bsp.open('rb') as stream:
            digest = hashlib.file_digest(stream, 'md5').hexdigest()
        if (header[2], number(header[3], True), header[4]) != (bsp.stem, bsp.stat().st_size, digest):
            raise ValueError('Map/BSP size/MD5 mismatch')
    return {'version': 4, 'map': header[2], 'nodes': len(nodes), 'areas': len(areas),
            'edges': len(edges), 'bsp_verified': bsp is not None}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('nav', type=Path)
    parser.add_argument('--bsp', type=Path)
    args = parser.parse_args()
    try:
        with args.nav.open(encoding='utf-8-sig') as stream:
            print(json.dumps(validate_lines(stream, args.bsp), indent=2))
        return 0
    except (OSError, ValueError) as error:
        print(f'Navigation rejected: {error}')
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
