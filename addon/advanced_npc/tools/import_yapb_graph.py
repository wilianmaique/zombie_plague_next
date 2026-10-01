#!/usr/bin/env python3
"""Import the current YaPB graph v2 into Advanced NPC's sole navigation format.

No YaPB binary, compiler, third-party Python library or runtime download is used.
ULZ decoding is a bounded Python port of yapb/crlib's MIT-licensed decoder.
See ../docs/REFERENCES.md and ../THIRD_PARTY_NOTICES.md for attribution.
"""

from __future__ import annotations

import argparse
from collections import Counter, deque
from dataclasses import dataclass, field
import json
import hashlib
import math
from pathlib import Path
import re
import struct
import sys

MAGIC = 0x59415042
GRAPH_VERSION = 2
GRAPH_OPTION = 1 << 3
EXTENSION_OPTION = 1 << 6
MAX_NODES = 4096
MAX_LINKS = 8
NODE_SIZE = 220
HEADER = struct.Struct("<6i")
LINK = struct.Struct("<3fiHh")
NODE_CROUCH, NODE_LADDER, NODE_DISABLED = 1, 2, 4
LINK_JUMP, LINK_DROP = 1, 2
YAPB_CROUCH, YAPB_LADDER = 1 << 2, 1 << 5
UNSUPPORTED = {1 << 0: "button", 1 << 1: "lift", 1 << 9: "double_jump"}


class GraphError(ValueError):
    """The input cannot safely be interpreted as the supported graph format."""


def decompress_ulz(data: bytes, expected_size: int) -> bytes:
    """Decode ULZ tokens with strict input, back-reference and output bounds."""
    if not 0 < expected_size <= MAX_NODES * NODE_SIZE:
        raise GraphError("Invalid uncompressed size")
    output = bytearray()
    cursor = 0

    def variable_length() -> int:
        nonlocal cursor
        value = 0
        # ULZ uses an additive, biased encoding; this is NOT ordinary LEB128.
        for shift in (0, 7, 14, 21):
            if cursor >= len(data):
                raise GraphError("Truncated ULZ variable length")
            byte = data[cursor]
            cursor += 1
            value += byte << shift
            if byte < 128:
                return value
        raise GraphError("ULZ variable length exceeds the supported range")

    while cursor < len(data):
        token = data[cursor]
        cursor += 1
        if token >= 32:
            run = token >> 5
            if run == 7:
                run += variable_length()
            if cursor + run > len(data) or len(output) + run > expected_size:
                raise GraphError("ULZ literal exceeds input/output bounds")
            output.extend(data[cursor:cursor + run])
            cursor += run
            if cursor == len(data):
                break
        length = (token & 15) + 4
        if length == 19:
            length += variable_length()
        if cursor + 2 > len(data):
            raise GraphError("Truncated ULZ back-reference")
        distance = ((token & 16) << 12) + struct.unpack_from("<H", data, cursor)[0]
        cursor += 2
        if distance == 0 or distance > len(output) or len(output) + length > expected_size:
            raise GraphError("Invalid ULZ back-reference/output size")
        # Byte-wise copy intentionally supports overlapping references.
        for _ in range(length):
            output.append(output[-distance])
    if len(output) != expected_size:
        raise GraphError(f"ULZ output size mismatch: {len(output)} != {expected_size}")
    return bytes(output)


@dataclass(frozen=True)
class Node:
    index: int
    feet: tuple[float, float, float]
    radius: float
    flags: int


@dataclass(frozen=True)
class Edge:
    source: int
    destination: int
    flags: int
    velocity: tuple[float, float, float]


@dataclass
class Graph:
    nodes: list[Node]
    edges: list[Edge]
    author: str = ""
    modified_by: str = ""
    bsp_size: int | None = None
    disabled_nodes: list[dict] = field(default_factory=list)
    inferred_drops: list[dict] = field(default_factory=list)
    computed_jumps: list[dict] = field(default_factory=list)


def _finite(values: tuple[float, ...], limit: float, context: str) -> None:
    if any(not math.isfinite(value) or abs(value) > limit for value in values):
        raise GraphError(f"Invalid numeric value in {context}")


def parse_graph(data: bytes) -> Graph:
    if not HEADER.size <= len(data) <= 2 * 1024 * 1024:
        raise GraphError("Graph is truncated or exceeds the input size limit")
    magic, version, options, count, compressed, uncompressed = HEADER.unpack_from(data)
    if magic != MAGIC or version != GRAPH_VERSION:
        raise GraphError("Only the current YaPB magic and graph version 2 are supported")
    if not options & GRAPH_OPTION or options & 7 or options & ~0x1F8:
        raise GraphError("Input is not a supported YaPB navigation graph")
    if not 8 <= count <= MAX_NODES or uncompressed != count * NODE_SIZE or compressed <= 0:
        raise GraphError("Invalid node count or studio-independent Path record size (expected 220)")
    extension_size = 68 if options & EXTENSION_OPTION else 0
    if len(data) != HEADER.size + compressed + extension_size:
        raise GraphError("Header sizes disagree with the actual file/extension length")
    raw = decompress_ulz(data[HEADER.size:HEADER.size + compressed], uncompressed)
    graph = Graph([], [])
    for index in range(count):
        base = index * NODE_SIZE
        number, original_flags = struct.unpack_from("<ii", raw, base)
        xyz = struct.unpack_from("<3f", raw, base + 8)
        radius = struct.unpack_from("<f", raw, base + 44)[0]
        if number != index:
            raise GraphError(f"Node number {number} disagrees with record index {index}")
        _finite(xyz, 65500.0, f"node {index}")
        _finite((radius,), 65536.0, f"node {index} radius")
        if radius < 0:
            raise GraphError(f"Negative radius at node {index}")
        flags = (NODE_CROUCH if original_flags & YAPB_CROUCH else 0) | (NODE_LADDER if original_flags & YAPB_LADDER else 0)
        reasons = [name for flag, name in UNSUPPORTED.items() if original_flags & flag]
        if reasons:
            flags |= NODE_DISABLED
            graph.disabled_nodes.append({"node": index, "reasons": reasons})
        # YaPB stores the player center. Our canonical coordinates are feet.
        feet = (xyz[0], xyz[1], xyz[2] - (18.0 if flags & NODE_CROUCH else 36.0))
        graph.nodes.append(Node(index, feet, max(8.0, min(24.0, radius)), flags))
    for source in range(count):
        destinations = set()
        for link_index in range(MAX_LINKS):
            vx, vy, vz, distance, original_flags, destination = LINK.unpack_from(raw, source * NODE_SIZE + 56 + link_index * LINK.size)
            if destination == -1:
                continue
            if not 0 <= destination < count or destination == source or destination in destinations:
                raise GraphError(f"Invalid/duplicate destination at node {source}, link {link_index}")
            destinations.add(destination)
            if original_flags & ~1 or distance < 0:
                raise GraphError(f"Invalid link flags/distance at node {source}, link {link_index}")
            flags, velocity = 0, (0.0, 0.0, 0.0)
            if original_flags & 1:
                _finite((vx, vy, vz), 1200.0, f"jump {source}->{destination}")
                if vz <= 0 or math.hypot(vx, vy) < 1:
                    graph.computed_jumps.append({"source": source, "destination": destination, "reason": "launch_requires_runtime_ballistic_solution"})
                flags, velocity = LINK_JUMP, (vx, vy, vz)
            elif not (graph.nodes[source].flags | graph.nodes[destination].flags) & NODE_LADDER:
                delta_z = graph.nodes[destination].feet[2] - graph.nodes[source].feet[2]
                if delta_z < -64.0:
                    flags = LINK_DROP
                    graph.inferred_drops.append({"source": source, "destination": destination, "height": delta_z})
            graph.edges.append(Edge(source, destination, flags, velocity))
    if extension_size:
        author, bsp_size, modified = struct.unpack_from("<32si32s", data, HEADER.size + compressed)
        graph.author = author.split(b"\0", 1)[0].decode("utf-8", errors="replace")
        graph.modified_by = modified.split(b"\0", 1)[0].decode("utf-8", errors="replace")
        if bsp_size <= 0:
            raise GraphError("Invalid BSP size in graph extension")
        graph.bsp_size = bsp_size
    return graph


def connectivity(graph: Graph) -> dict:
    """Describe weak components and dead ends; never claim global reachability."""
    active = {node.index for node in graph.nodes if not node.flags & NODE_DISABLED}
    adjacency = {node: set() for node in active}
    outgoing = Counter()
    incoming = Counter()
    for edge in graph.edges:
        if edge.source in active and edge.destination in active:
            adjacency[edge.source].add(edge.destination)
            adjacency[edge.destination].add(edge.source)
            outgoing[edge.source] += 1
            incoming[edge.destination] += 1
    remaining, components = set(active), []
    while remaining:
        start = min(remaining)
        queue, component = deque([start]), set([start])
        remaining.remove(start)
        while queue:
            for neighbor in adjacency[queue.popleft()]:
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    component.add(neighbor)
                    queue.append(neighbor)
        components.append({"size": len(component), "first_node": min(component)})
    return {
        "active_nodes": len(active),
        "weak_components": components,
        "nodes_without_outgoing_links": sorted(node for node in active if not outgoing[node]),
        "nodes_without_incoming_links": sorted(node for node in active if not incoming[node]),
        "note": "Weak connectivity does not prove directed, physical or capability-specific reachability. Test in the actual map.",
    }


def navigation_text(graph: Graph, map_name: str, bsp_size: int, bsp_hash: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_.-]{0,62}", map_name) or bsp_size <= 0:
        raise GraphError("Invalid map name or BSP size")
    if not re.fullmatch(r"[0-9a-f]{32}", bsp_hash):
        raise GraphError("Invalid BSP MD5 digest")
    if graph.bsp_size is not None and graph.bsp_size != bsp_size:
        raise GraphError(f"Graph BSP size {graph.bsp_size} does not match the supplied map {bsp_size}")
    lines = [f'ANPC_NAV 3 "{map_name}" {bsp_size} {bsp_hash}']
    for node in graph.nodes:
        x, y, z = node.feet
        lines.append(f"N {node.index} {x:.4f} {y:.4f} {z:.4f} {node.radius:.2f} {node.flags}")
    for edge in graph.edges:
        vx, vy, vz = edge.velocity
        lines.append(f"E {edge.source} {edge.destination} {edge.flags} {vx:.4f} {vy:.4f} {vz:.4f}")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("graph", type=Path, help="Local YaPB .graph (current version 2)")
    parser.add_argument("--bsp", type=Path, required=True, help="The exact map installed on the game server")
    parser.add_argument("--output", type=Path, required=True, help="Destination .nav file")
    parser.add_argument("--force", action="store_true", help="Replace an existing output and report")
    arguments = parser.parse_args(argv)
    try:
        if arguments.graph.suffix.lower() != ".graph" or arguments.bsp.suffix.lower() != ".bsp" or arguments.output.suffix.lower() != ".nav":
            raise GraphError("Expected .graph, .bsp and .nav file extensions")
        if arguments.graph.stat().st_size > 2 * 1024 * 1024:
            raise GraphError("Input graph exceeds 2 MiB")
        graph = parse_graph(arguments.graph.read_bytes())
        bsp_size = arguments.bsp.stat().st_size
        with arguments.bsp.open("rb") as bsp_file:
            if bsp_size < 124 or bsp_file.read(4) != struct.pack("<i", 30):
                raise GraphError("The supplied map is not a GoldSrc/Counter-Strike BSP version 30")
        with arguments.bsp.open("rb") as bsp_file:
            bsp_hash = hashlib.file_digest(bsp_file, "md5").hexdigest()
        output = navigation_text(graph, arguments.bsp.stem, bsp_size, bsp_hash)
        report_path = arguments.output.with_suffix(".report.json")
        if not arguments.force and (arguments.output.exists() or report_path.exists()):
            raise GraphError("Output/report already exists; choose another path or explicitly pass --force")
        report = {
            "source": arguments.graph.name, "map": arguments.bsp.stem, "bsp_size": bsp_size, "bsp_md5": bsp_hash,
            "author": graph.author, "modified_by": graph.modified_by,
            "nodes": len(graph.nodes), "edges": len(graph.edges),
            "disabled_nodes": graph.disabled_nodes,
            "inferred_drops_requiring_review": graph.inferred_drops,
            "computed_jumps_requiring_review": graph.computed_jumps,
            "connectivity": connectivity(graph),
            "limitations": ["Lifts, button actions, double jumps, swimming and scripted teleports need dedicated traversal providers.",
                            "The importer checks the file format and map size; the server checks collision and actual traversal."],
        }
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        temporary = arguments.output.with_suffix(".nav.tmp")
        temporary.write_text(output, encoding="utf-8", newline="\n")
        temporary.replace(arguments.output)
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"Imported {len(graph.nodes)} nodes / {len(graph.edges)} directed edges into {arguments.output}")
        print(f"Review {len(graph.disabled_nodes)} disabled nodes, {len(graph.computed_jumps)} computed jumps and {len(graph.inferred_drops)} inferred drops: {report_path}")
        return 0
    except (OSError, GraphError) as error:
        print(f"Import rejected: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
