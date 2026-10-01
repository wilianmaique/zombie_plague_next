"""Read-only BSP 30 hull check for planar navigation certificates.

Uses only the standard library. This checks static BSP geometry, not entities,
AMXX execution or player movement. No BSP is copied into the repository.
"""
from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import dataclass
import hashlib
import json
import math
from pathlib import Path
import struct

Vec = tuple[float, float, float]
SOLID = -2
EPSILON = 0.03125


@dataclass(frozen=True)
class Hit:
    fraction: float
    end: Vec
    normal: Vec
    start_solid: bool
    all_solid: bool


class Bsp:
    def __init__(self, path: Path):
        self.data = path.read_bytes()
        if struct.unpack_from('<i', self.data)[0] != 30:
            raise ValueError('Expected a GoldSrc BSP version 30')
        self.lumps = [struct.unpack_from('<ii', self.data, 4+i*8) for i in range(15)]
        for offset, size in self.lumps:
            if offset < 0 or size < 0 or offset+size > len(self.data):
                raise ValueError('Invalid BSP lump bounds')
        self.planes = self.records(1, '<4fi')
        self.nodes = self.records(5, '<i2h6h2H')
        self.clipnodes = self.records(9, '<i2h')
        self.leaves = self.records(10, '<ii6h2H4B')
        self.models = self.records(14, '<9f7i')
        self.vertices = self.records(3, '<3f')
        self.edges = self.records(12, '<2H')
        self.surfedges = self.records(13, '<i')
        self.faces = self.records(7, '<Hhihh4Bi')

    def records(self, lump: int, fmt: str):
        offset, size = self.lumps[lump]
        if size % struct.calcsize(fmt):
            raise ValueError(f'Invalid record size in lump {lump}')
        return list(struct.iter_unpack(fmt, self.data[offset:offset+size]))

    def node(self, hull: int, index: int):
        return (self.nodes if hull == 0 else self.clipnodes)[index]

    def leaf(self, hull: int, index: int):
        return self.leaves[-index-1][0] if hull == 0 else index

    def contents(self, hull: int, position: Vec) -> int:
        index = self.models[0][9+hull]
        while index >= 0:
            node = self.node(hull, index)
            plane = self.planes[node[0]]
            distance = sum(position[i]*plane[i] for i in range(3))-plane[3]
            index = node[1 if distance >= 0 else 2]
        return self.leaf(hull, index)

    def trace(self, hull: int, start: Vec, end: Vec) -> Hit:
        # Partition the ray into BSP leaf intervals; entering a solid interval
        # supplies the collision plane. This is independent of Pawn's sampler.
        delta = tuple(end[i]-start[i] for i in range(3))
        stack = [(self.models[0][9+hull], 0.0, 1.0, (0.0, 0.0, 0.0))]
        intervals = []
        while stack:
            index, low, high, entered = stack.pop()
            if index < 0:
                intervals.append((low, high, self.leaf(hull, index), entered))
                continue
            node = self.node(hull, index)
            plane = self.planes[node[0]]
            distance = sum(start[i]*plane[i] for i in range(3))-plane[3]
            speed = sum(delta[i]*plane[i] for i in range(3))
            d_low, d_high = distance+speed*low, distance+speed*high
            if d_low >= 0 and d_high >= 0:
                stack.append((node[1], low, high, entered))
            elif d_low < 0 and d_high < 0:
                stack.append((node[2], low, high, entered))
            else:
                split = max(low, min(high, -distance/speed))
                side = 0 if d_low >= 0 else 1
                normal = tuple(plane[i]*(1 if side == 0 else -1) for i in range(3))
                stack.append((node[2-side], split, high, normal))
                stack.append((node[1+side], low, split, entered))
        start_solid = self.contents(hull, start) == SOLID
        all_solid = all(row[2] == SOLID for row in intervals)
        saw_air = not start_solid
        for low, high, contents, normal in intervals:
            if high-low <= 1e-10:
                continue
            if contents != SOLID:
                saw_air = True
                continue
            if not saw_air:
                continue
            projection = abs(sum(delta[i]*normal[i] for i in range(3)))
            fraction = max(0.0, low-EPSILON/projection) if projection else low
            hit = tuple(start[i]+delta[i]*fraction for i in range(3))
            return Hit(fraction, hit, normal, start_solid, all_solid)
        return Hit(1.0, end, (0.0, 0.0, 0.0), start_solid, all_solid)

    def floor(self, feet: Vec, crouched: bool = False):
        height, hull = (18.0, 3) if crouched else (36.0, 1)
        start = (feet[0], feet[1], feet[2]+height+0.2)
        end = (feet[0], feet[1], feet[2]+height-24.0)
        trace = self.trace(hull, start, end)
        if trace.start_solid or trace.all_solid or trace.fraction >= 1 or trace.normal[2] < 0.7:
            return None
        result = (trace.end[0], trace.end[1], trace.end[2]-height)
        if abs(result[2]-feet[2]) > 1:
            return None
        return result, trace.normal

    def clear(self, a: Vec, b: Vec, crouched: bool = False) -> bool:
        height, hull = (18.0, 3) if crouched else (36.0, 1)
        trace = self.trace(hull, (a[0], a[1], a[2]+height+0.2), (b[0], b[1], b[2]+height+0.2))
        return not trace.start_solid and not trace.all_solid and trace.fraction >= 0.999

    def walkable_face_seeds(self):
        for face in self.faces:
            plane = self.planes[face[0]]
            normal = tuple(value*(-1 if face[1] else 1) for value in plane[:3])
            if normal[2] < 0.7 or face[3] < 3:
                continue
            vertices = []
            for entry in self.surfedges[face[2]:face[2]+face[3]]:
                edge = entry[0]
                vertices.append(self.vertices[self.edges[abs(edge)][0 if edge >= 0 else 1]])
            center = tuple(sum(v[i] for v in vertices)/len(vertices) for i in range(3))
            lift = (16*(abs(normal[0])+abs(normal[1]))+EPSILON)/normal[2]
            feet = (center[0], center[1], center[2]+lift)
            # BSP compilers can bevel/shift expanded hull planes. Locate the
            # hull's actual support before applying the near-feet certificate.
            initial = self.trace(1, (feet[0], feet[1], feet[2]+36+0.2), (feet[0], feet[1], feet[2]+36-64))
            if initial.start_solid or initial.all_solid or initial.fraction >= 1 or initial.normal[2] < 0.7:
                continue
            actual = (initial.end[0], initial.end[1], initial.end[2]-36)
            floor = self.floor(actual)
            if floor and self.clear(floor[0], floor[0]):
                yield floor


def plane_height(origin: Vec, normal: Vec, x: float, y: float):
    return origin[2]-((x-origin[0])*normal[0]+(y-origin[1])*normal[1])/normal[2]


def certify(bsp: Bsp, x: int, y: int, size: int, origin: Vec, normal: Vec, crouched=False):
    divisions = math.ceil(size/16)
    for row in range(divisions+1):
        py = (y+row/divisions)*size
        a = (x*size, py, plane_height(origin, normal, x*size, py))
        b = ((x+1)*size, py, plane_height(origin, normal, (x+1)*size, py))
        if not bsp.clear(a, b, crouched):
            return False, 'hull'
        for column in range(divisions+1):
            px = (x+column/divisions)*size
            point = (px, py, plane_height(origin, normal, px, py))
            floor = bsp.floor(point, crouched)
            if floor is None:
                return False, 'floor'
            if abs(floor[0][2]-point[2]) > 0.75 or sum((floor[1][i]-normal[i])**2 for i in range(3)) > 0.0001:
                return False, 'plane'
    return True, 'open'


def analyze(path: Path):
    bsp = Bsp(path)
    seeds = list(bsp.walkable_face_seeds())
    roots = {}
    for origin, normal in seeds:
        x, y = math.floor(origin[0]/256), math.floor(origin[1]/256)
        key = (x, y, round(plane_height(origin, normal, 0, 0), 1), *(round(n, 3) for n in normal))
        roots.setdefault(key, (x, y, origin, normal))
    counters = Counter()
    accepted = []

    def visit(x, y, size, origin, normal):
        counters['tested_blocks'] += 1
        for crouched in (False, True):
            valid, reason = certify(bsp, x, y, size, origin, normal, crouched)
            if valid:
                counters['areas'] += 1
                counters['crouch_areas' if crouched else 'standing_areas'] += 1
                if normal[2] < 0.999:
                    counters['ramp_areas'] += 1
                accepted.append((x, y, size, origin, normal, crouched))
                return
        counters['reject_'+reason] += 1
        if size > 32:
            for child in range(4):
                visit(x*2+child%2, y*2+child//2, size//2, origin, normal)

    for x, y, origin, normal in roots.values():
        visit(x, y, 256, origin, normal)
    counters['walkable_face_seeds'] = len(seeds)
    counters['distinct_roots'] = len(roots)
    counters['slope_seeds_rejected_by_previous_flat_rule'] = sum(normal[2] < 0.999 for _, normal in seeds)
    return {'map': path.stem, 'bsp_md5': hashlib.md5(bsp.data).hexdigest(), 'static_world_only': True, **counters}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('bsp', type=Path)
    args = parser.parse_args()
    print(json.dumps(analyze(args.bsp), indent=2))
