"""Format/security regression tests. Does not invoke the Pawn compiler or HLDS."""

import math
import hashlib
from pathlib import Path
import struct
import tempfile
import unittest

from import_yapb_graph import (
    EXTENSION_OPTION, GRAPH_OPTION, HEADER, LINK, MAGIC, NODE_SIZE,
    GraphError, connectivity, decompress_ulz, main, navigation_text, parse_graph,
)


def literal_block(data):
    """Encode only literals to construct independent, deterministic fixtures."""
    length = len(data)
    if length < 7:
        return bytes([length << 5]) + data
    value, encoded = length - 7, bytearray([224])
    while value >= 128:
        value -= 128
        encoded.append(128 + (value & 127))
        value >>= 7
    encoded.append(value)
    return bytes(encoded) + data


def fixture(node_flags=None, jump=(240.0, 0.0, 270.0), extension=True):
    raw = bytearray(8 * NODE_SIZE)
    for index in range(8):
        base = index * NODE_SIZE
        flags = node_flags.get(index, 0) if node_flags else 0
        struct.pack_into("<ii3f", raw, base, index, flags, index * 100.0, 0.0, 18.0 if flags & 4 else 36.0)
        struct.pack_into("<f", raw, base + 44, 16.0)
        for link in range(8):
            LINK.pack_into(raw, base + 56 + link * LINK.size, 0.0, 0.0, 0.0, 0, 0, -1)
        if index < 7:
            LINK.pack_into(raw, base + 56, *(jump if index == 0 else (0.0, 0.0, 0.0)), 100, 1 if index == 0 else 0, index + 1)
    compressed = literal_block(raw)
    data = HEADER.pack(MAGIC, 2, GRAPH_OPTION | (EXTENSION_OPTION if extension else 0), 8, len(compressed), len(raw)) + compressed
    if extension:
        data += struct.pack("<32si32s", b"Fixture Author", 128, b"Fixture Editor")
    return data


class ImportTests(unittest.TestCase):
    def test_current_graph_preserves_direction_and_jump(self):
        graph = parse_graph(fixture())
        self.assertEqual(len(graph.nodes), 8)
        self.assertEqual(len(graph.edges), 7)
        self.assertEqual(graph.edges[0].velocity, (240.0, 0.0, 270.0))
        self.assertEqual(graph.edges[0].flags, 1)
        self.assertFalse(any(edge.destination == 0 for edge in graph.edges))
        self.assertEqual(graph.author, "Fixture Author")

    def test_crouch_origin_is_converted_to_feet(self):
        graph = parse_graph(fixture({1: 4}))
        self.assertEqual(graph.nodes[0].feet[2], 0.0)
        self.assertEqual(graph.nodes[1].feet[2], 0.0)
        self.assertEqual(graph.nodes[1].flags, 1)

    def test_unsupported_lift_is_disabled_and_reported(self):
        graph = parse_graph(fixture({2: 2}))
        self.assertEqual(graph.nodes[2].flags, 4)
        self.assertEqual(graph.disabled_nodes, [{"node": 2, "reasons": ["lift"]}])
        self.assertEqual(len(connectivity(graph)["weak_components"]), 2)

    def test_unknown_version_and_record_size_are_rejected(self):
        for offset, value in ((4, 3), (20, 8 * 224), (12, 4097)):
            data = bytearray(fixture())
            struct.pack_into("<i", data, offset, value)
            with self.subTest(offset=offset), self.assertRaises(GraphError):
                parse_graph(bytes(data))

    def test_truncated_and_extra_input_is_rejected(self):
        for data in (fixture()[:-1], fixture() + b"junk", b"", fixture()[:24]):
            with self.subTest(size=len(data)), self.assertRaises(GraphError):
                parse_graph(data)

    def test_nonfinite_or_computed_jumps(self):
        with self.assertRaises(GraphError):
            parse_graph(fixture(jump=(math.nan, 0.0, 270.0)))
        computed = parse_graph(fixture(jump=(0.0, 0.0, 0.0)))
        self.assertEqual(len(computed.computed_jumps), 1)
        self.assertEqual(len(computed.edges), 7)
        graph = parse_graph(fixture(jump=(100.0, 0.0, 0.0)))
        self.assertEqual(len(graph.computed_jumps), 1)
        self.assertEqual(len(graph.edges), 7)
        self.assertEqual(graph.edges[0].velocity, (100.0, 0.0, 0.0))

    def test_overlapping_ulz_reference(self):
        self.assertEqual(decompress_ulz(bytes([35, ord("x"), 1, 0]), 8), b"xxxxxxxx")

    def test_biased_ulz_extended_literal(self):
        for length in (7, 134, 135, 1760, 32768):
            data = b"z" * length
            self.assertEqual(decompress_ulz(literal_block(data), length), data)

    def test_invalid_back_reference_and_output_bound(self):
        for data, expected in ((bytes([0, 1, 0]), 8), (bytes([32, 65, 0, 0, 0]), 5), (literal_block(b"12345678"), 7), (bytes([224, 128]), 32)):
            with self.subTest(data=data), self.assertRaises(GraphError):
                decompress_ulz(data, expected)

    def test_map_mismatch_is_rejected(self):
        graph = parse_graph(fixture())
        with self.assertRaises(GraphError):
            navigation_text(graph, "de_fixture", 129, "0" * 32)
        with self.assertRaises(GraphError):
            navigation_text(graph, "../de_fixture", 128, "0" * 32)

    def test_cli_emits_current_format_and_does_not_overwrite_by_default(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, bsp, output = root / "de_fixture.graph", root / "de_fixture.bsp", root / "de_fixture.nav"
            source.write_bytes(fixture())
            bsp.write_bytes(struct.pack("<i", 30) + b"\0" * 124)
            arguments = [str(source), "--bsp", str(bsp), "--output", str(output)]
            self.assertEqual(main(arguments), 0)
            text = output.read_text()
            digest = hashlib.md5(bsp.read_bytes()).hexdigest()
            self.assertEqual(text.splitlines()[0], f'ANPC_NAV 2 "de_fixture" 128 {digest}')
            self.assertEqual(len(text.splitlines()[1].split()), 7)
            self.assertEqual(main(arguments), 1)
            self.assertEqual(output.read_text(), text)
            self.assertTrue(output.with_suffix(".report.json").is_file())


if __name__ == "__main__":
    unittest.main()
