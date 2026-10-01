"""Pawn guard regressions with AMXX native contract doubles, without a compiler.

These evaluate only the selected predicates from the installed mapper includes.
They do not execute Pawn, engine traces or the scanner state machine. Includes
are located through LOCAL.md; machines without that local setup skip this suite.
"""
import ast
import io
from pathlib import Path
import re
import struct
import unittest


def body(source, name):
    match = re.search(r'\bstock\s+(?:bool:)?'+name+r'\s*\(', source)
    if not match:
        raise AssertionError('Missing function: '+name)
    start = source.index('{', match.end())
    depth = 1
    end = start+1
    while depth:
        depth += (source[end] == '{')-(source[end] == '}')
        end += 1
    return source[start+1:end-1]


def conditions(source):
    result = []
    for match in re.finditer(r'\bif\s*\(', source):
        start = match.end()
        depth = 1
        end = start
        while depth:
            depth += (source[end] == '(')-(source[end] == ')')
            end += 1
        result.append(source[start:end-1])
    return result


def predicate(expression, values):
    expression = expression.replace('&&', ' and ').replace('||', ' or ')
    expression = ' '.join(re.sub(r'!(?!=)', ' not ', expression).split())
    tree = ast.parse(expression, mode='eval')
    allowed = (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.UnaryOp,
               ast.Not, ast.Compare, ast.Eq, ast.NotEq, ast.Lt, ast.LtE,
               ast.Gt, ast.GtE, ast.Call, ast.Name, ast.Load, ast.Constant,
               ast.Subscript, ast.BinOp, ast.Add, ast.Sub, ast.Mult)
    if any(not isinstance(node, allowed) for node in ast.walk(tree)):
        raise AssertionError('Unsupported guard syntax: '+expression)
    return bool(eval(expression, {'__builtins__': {}}, values))


class MapperNativeContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        local = Path(__file__).resolve().parents[1]/'LOCAL.md'
        if not local.exists():
            raise unittest.SkipTest('LOCAL.md with external mapper includes unavailable')
        match = re.search(r'^\| `ANPC_INCLUDE_DIR` \| `([^`]+)`',
                          local.read_text(encoding='utf-8-sig'), re.MULTILINE)
        if not match or not Path(match[1]).is_dir():
            raise unittest.SkipTest('External mapper includes unavailable')
        include = Path(match[1])
        coverage = (include/'mapper_coverage.inc').read_text(encoding='utf-8-sig')
        world = (include/'mapper_world.inc').read_text(encoding='utf-8-sig')
        exploration = (include/'mapper_exploration.inc').read_text(encoding='utf-8-sig')
        cls.floor_checks = conditions(body(coverage, 'scan_block_floor'))
        cls.header_check = next(check for check in conditions(body(world, 'scan_read_bounds'))
                                if 'fread(' in check)
        cls.wall_check = conditions(body(exploration, 'scan_sense_wall'))[0]
        cls.world_sense_check = next(check for check in conditions(body(exploration, 'scan_sense_step'))
                                    if 'TR_pHit' in check)

    def floor_allowed(self, support=True, solid=False, hit=-1, height=0.03125):
        # Fakemeta converts a world edict (offset 0) to FM_NULLENT (-1).
        # The same sentinel on a missed trace must still fail the support test.
        values = {'anpc_ground_floor': lambda *args: support,
                  'get_tr2': lambda trace, field: {'TR_StartSolid': solid, 'TR_pHit': hit}[field],
                  'point': [739., 557.4, 0.], 'floor': [739., 557.4, height],
                  'duck': False, 'gBot': 2, 'gTrace': 1, 'gTraces': 0,
                  'TR_StartSolid': 'TR_StartSolid', 'TR_pHit': 'TR_pHit',
                  'FM_NULLENT': -1, 'floatabs': abs}
        return not any(predicate(check, values) for check in self.floor_checks)

    def header_rejected(self, data):
        version = struct.unpack_from('<i', data)[0] if len(data) >= 4 else 0
        offset, length = struct.unpack_from('<ii', data, 116) if len(data) >= 124 else (0, 0)
        file = io.BytesIO(data)

        def seek(handle, position, origin):
            handle.seek(position, origin)
            return 0

        # fread returns bytes. Use real binary reads to exercise short reads;
        # decoded cells are supplied independently for the structural checks.
        values = {'file': file, 'version': version, 'offset': offset, 'length': length,
                  'BLOCK_INT': 4, 'SEEK_SET': 0, 'gBspSize': len(data),
                  'fread': lambda handle, destination, size: len(handle.read(size)),
                  'fseek': seek}
        return predicate(self.header_check, values)

    def test_world_floor_uses_fakemeta_sentinel(self):
        self.assertTrue(self.floor_allowed())

    def test_null_hit_without_support_cannot_certify_a_floor(self):
        self.assertFalse(self.floor_allowed(support=False))

    def test_solid_start_and_entity_floor_remain_rejected(self):
        self.assertFalse(self.floor_allowed(solid=True))
        self.assertFalse(self.floor_allowed(hit=96))

    def test_another_floor_layer_remains_rejected(self):
        self.assertFalse(self.floor_allowed(height=32.))

    def test_valid_bsp_header_accepts_four_byte_native_reads(self):
        header = bytearray(124)
        struct.pack_into('<i', header, 0, 30)
        struct.pack_into('<ii', header, 116, 124, 64)
        self.assertFalse(self.header_rejected(bytes(header)+bytes(64)))

    def test_bsp_short_reads_and_invalid_model_bounds_are_rejected(self):
        self.assertTrue(self.header_rejected(b'\x1e\x00\x00'))
        header = bytearray(124)
        struct.pack_into('<i', header, 0, 30)
        struct.pack_into('<ii', header, 116, 124, 64)
        self.assertTrue(self.header_rejected(bytes(header)+bytes(63)))
        struct.pack_into('<i', header, 0, 29)
        self.assertTrue(self.header_rejected(bytes(header)+bytes(64)))

    def test_static_world_wall_can_trigger_tangent_analysis(self):
        for hit in (-1, 96):
            values = {'get_tr2': lambda trace, field: hit if field == 'TR_pHit' else False,
                      'gTrace': 1, 'TR_pHit': 'TR_pHit', 'TR_StartSolid': 'TR_StartSolid',
                      'TR_AllSolid': 'TR_AllSolid', 'FM_NULLENT': -1,
                      'clear': False, 'gSenseDistance': [64.], 'direction': 0,
                      'normal': [1., 0., 0.], 'high_normal': [1., 0., 0.],
                      'floatabs': abs, 'fraction': 0.5, 'reach': 128.}
            with self.subTest(hit=hit):
                self.assertEqual(predicate(self.world_sense_check, values), hit == -1)
                self.assertEqual(not predicate(self.wall_check, values), hit == -1)


if __name__ == '__main__':
    unittest.main()
