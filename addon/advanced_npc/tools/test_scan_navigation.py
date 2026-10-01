"""Scan regression contracts and independent NAV validation, without compiling.

Selected Pawn predicates/assignments use native doubles; no HLDS physics or
complete Pawn state machine is executed here.
"""
import math
from pathlib import Path
import re
import random
import unittest

from check_nav_file import validate_lines
from check_pawn_sources import check_group, include_directory
from import_yapb_graph import Edge, Graph, Node, navigation_text
from test_mapper_contracts import body, conditions, predicate
from test_mapper_team import assignments


class NavFileTests(unittest.TestCase):
    def navigation(self):
        nodes = [Node(i, (float(i*32), 0., 0.), 16., 0) for i in range(12)]
        edges = [Edge(0, i, 0, (0., 0., 0.)) for i in range(1, 12)]
        graph = Graph(nodes=nodes, edges=edges)
        return navigation_text(graph, 'de_fixture', 124, 'a'*32)

    def test_more_than_eight_outgoing_edges_are_valid(self):
        result = validate_lines(self.navigation().splitlines())
        self.assertEqual((result['nodes'], result['edges']), (12, 11))

    def test_truncated_record_streams_and_wrong_counts_are_rejected(self):
        lines = self.navigation().splitlines()
        for change in (lines[:-1], lines[:-2]+lines[-1:], lines[:-1]+['END 12 0 10']):
            with self.subTest(change=change[-1]):
                with self.assertRaises(ValueError):
                    validate_lines(change)

    def test_record_after_footer_and_duplicate_edge_are_rejected(self):
        lines = self.navigation().splitlines()
        for change in (lines+['N 12 0 0 0 16 0'], lines[:-1]+[lines[-2], 'END 12 0 12']):
            with self.assertRaises(ValueError):
                validate_lines(change)

    def test_only_current_format_is_accepted(self):
        with self.assertRaises(ValueError):
            validate_lines(self.navigation().replace('ANPC_NAV 4', 'ANPC_NAV 3').splitlines())

    def test_area_only_stream_and_crouched_plane(self):
        lines = ['ANPC_NAV 4 "de_fixture" 124 '+'a'*32,
                 'A 0 0 0 256 128 0 0 0 1 1', 'END 0 1 0']
        self.assertEqual(validate_lines(lines)['areas'], 1)
        for record in ('A 0 0 0 257 128 0 0 0 1 1',
                       'A 0 0 0 256 128 nan 0 0 1 1',
                       'A 0 0 0 256 128 0 0 0 0.5 1'):
            with self.assertRaises(ValueError):
                validate_lines([lines[0], record, lines[2]])


class PawnSourceCheckerTests(unittest.TestCase):
    def test_checker_finds_real_structural_mistakes(self):
        source = 'stock one(const x) { return x; }\npublic demo() { one(1,2); log_amx("%d %d",1); }'
        errors = check_group({Path('fixture.sma'): source})
        self.assertEqual(len(errors), 2)
        self.assertTrue(any('2 args' in error for error in errors))
        self.assertTrue(any('format expects 2' in error for error in errors))

    def test_comments_escapes_and_default_array_parameter_are_handled(self):
        source = 'stock one(const x, const Float:v[3] = {0.0,0.0,0.0}) { return x; }\npublic demo() { one(1); log_amx("^"text^" %d",1); } // {'
        self.assertEqual(check_group({Path('fixture.sma'): source}), [])


class ScanMotionRegressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root = Path(__file__).resolve().parents[1]
        if not (root/'LOCAL.md').exists():
            raise unittest.SkipTest('External includes unavailable')
        include = include_directory(root)
        cls.motion = (include/'mapper_motion.inc').read_text(encoding='utf-8-sig')
        cls.movement = (include/'movement.inc').read_text(encoding='utf-8-sig')
        cls.world = (include/'mapper_world.inc').read_text(encoding='utf-8-sig')
        cls.coverage = (include/'mapper_coverage.inc').read_text(encoding='utf-8-sig')
        cls.frontiers = (include/'mapper_frontiers.inc').read_text(encoding='utf-8-sig')
        cls.navigation = (root/'anpc_navigation.sma').read_text(encoding='utf-8-sig')
        cls.reached_expression = body(cls.motion, 'scan_reached').split('return ', 1)[1].strip()

    def reached(self, feet, goal):
        return predicate(self.reached_expression, {'feet': feet, 'goal': goal, 'floatabs': abs,
                         'anpc_distance_2d': lambda a, b: math.hypot(a[0]-b[0], a[1]-b[1])})

    def test_diagonal_height_offset_has_one_completion_tolerance(self):
        # The old success test accepted this, but the old 3D alignment test
        # requested a new alignment indefinitely without physical progress.
        self.assertTrue(self.reached([7., 7., 10.], [0., 0., 0.]))
        self.assertGreater(math.sqrt(7**2+7**2+10**2), 12.)
        self.assertFalse(self.reached([10., 10., 0.], [0., 0., 0.]))
        self.assertFalse(self.reached([0., 0., 13.], [0., 0., 0.]))

    def test_alignment_does_not_renew_trial_deadline(self):
        function = body(self.motion, 'scan_begin_move')
        guard = next(check for check in conditions(function) if check.strip() == '!aligning')
        expression = re.search(r'gDeadline\[gWorker\] = ([^\n]+)', function)[1]
        values = {'gWorker': 0, 'gSourceFeet': [[0., 0., 0.]], 'gGoalFeet': [[64., 0., 0.]],
                  'gSpeed': 300., 'gProgressTime': [100.], 'gDeadline': [0.],
                  'anpc_distance_2d': lambda a, b: math.hypot(a[0]-b[0], a[1]-b[1]),
                  'floatmax': max, 'floatclamp': lambda v, lo, hi: max(lo, min(hi, v))}
        for aligning, now in ((False, 100.), (True, 101.), (True, 104.), (True, 120.)):
            values['aligning'] = aligning
            values['gProgressTime'][0] = now
            if predicate(guard, values):
                values['gDeadline'][0] = eval(expression, {'__builtins__': {}}, values)
            self.assertAlmostEqual(values['gDeadline'][0], 103.+64./102.)

    def test_alignment_and_known_routes_do_not_create_ground_samples(self):
        guard = next(check for check in conditions(body(self.motion, 'scan_drive'))
                     if '!gAligning' in check and '!gAirborne' in check)
        for aligning in (False, True):
            for purpose in (0, 1, 2):
                values = {'gWorker': 0, 'gAligning': [aligning], 'gPurpose': [purpose],
                          'SCAN_TRAVEL': 2, 'gAirborne': [False], 'ground_after': True,
                          'on_ladder': False, 'gCurrent': [0]}
                self.assertEqual(predicate(guard, values), not aligning and purpose != 2)

    def test_goal_changes_cannot_reset_a_stationary_npc_window(self):
        function = body(self.movement, 'npc_progress')
        guard = next(check for check in conditions(function) if 'ACT_PROGRESS_GOAL' in check)
        values = {'stationary': True, 'slot': 0, 'ACT_PROGRESS_VALID': 'valid',
                  'ACT_PROGRESS_GOAL': 'goal', 'gActor': [{'valid': False, 'goal': [0., 0., 0.]}],
                  'goal': [1000., 0., 0.], 'anpc_distance_sq': lambda a, b: sum((x-y)**2 for x, y in zip(a, b))}
        self.assertFalse(predicate(guard, values))
        values['stationary'] = False
        self.assertTrue(predicate(guard, values))

    def test_waiting_seconds_are_capped_out_of_movement_stall_accumulation(self):
        expression = re.search(r'ACT_MOTION_STALL\] \+= ([^\n]+)', body(self.movement, 'npc_progress'))[1]
        values = {'now': 100., 'gActor': [{'time': 5.}], 'slot': 0, 'ACT_MOTION_TIME': 'time',
                  'floatclamp': lambda v, lo, hi: max(lo, min(hi, v))}
        self.assertEqual(eval(expression, {'__builtins__': {}}, values), 0.2)

    def test_new_coverage_reopens_previously_unreachable_frontiers_without_new_nodes(self):
        guard = next(check for check in conditions(body(self.frontiers, 'scan_plan_step')) if 'gUnreachable' in check)
        for change in ('scan_block_test', 'scan_blocks_changed'):
            values = {'gWorker': 0, 'node': 1, 'gCurrent': [0], 'gGraphEpoch': 77,
                      'gUnreachable': [[0, 77]], 'gSeedRejected': [False, False],
                      'gKnownFlags': [0, 0], 'ANPC_NODE_DISABLED': 4,
                      'scan_node_busy': lambda node: False}
            self.assertFalse(predicate(guard, values))
            # Execute the topology revision statement from the actual area
            # success/invalidation path, leaving node count unchanged.
            statements = re.findall(r'\bgGraphEpoch\+\+', body(self.coverage, change))
            assignments(';'.join(statements), values)
            self.assertTrue(predicate(guard, values))

    def test_editing_uses_one_cursor_encoding_and_invalidates_when_membership_returns(self):
        values = {'plugin': 4, 'gRegionsReady': True, 'pending': [32000]}
        values['nav_invalidate'] = lambda: values['pending'].clear()
        function = body(self.navigation, 'native_begin_edit')
        statements = function[function.index('gEditOwner ='):function.index('return true')]
        statements = re.sub(r'//[^\n]*', '', statements)
        assignments(';'.join(line.strip() for line in statements.splitlines() if line.strip()), values)
        self.assertFalse(values['gRegionsReady'])
        self.assertEqual(values['pending'], [])
        end_guard = next(check for check in conditions(body(self.navigation, 'native_end_edit')) if 'membership_changed' in check and 'gEditDirty' in check)
        self.assertTrue(predicate(end_guard, {'gEditDirty': False, 'membership_changed': True}))

    def test_spatial_seed_candidates_match_full_search_with_negative_cells_and_layers(self):
        # Compare the spatial candidate set against an independent all-pairs
        # oracle. Exercise more seeds than the former 512-entry queue, both
        # sides of cell boundaries, hash collisions and overlapping floors.
        hash_expression = body(self.coverage, 'scan_block_hash').split('return ', 1)[1].strip()
        near = next(check for check in conditions(body(self.world, 'scan_add_seed')) if 'SEED_FEET' in check)
        spacing, buckets = 128., 4096

        def bucket(x, y):
            return eval(hash_expression, {'__builtins__': {}},
                        {'x': x, 'y': y, 'level': 0, 'SCAN_BLOCK_BUCKETS': buckets})

        rng = random.Random(418)
        seeds = [(rng.uniform(-8192., 8192.), rng.uniform(-8192., 8192.), rng.choice((0., 96., 192.)))
                 for _ in range(800)]
        seeds += [(-128.01, -0.01, 0.), (-0.01, 0.01, 96.), (128., -128., 0.)]
        heads = {}
        for index, seed in enumerate(seeds):
            key = bucket(math.floor(seed[0]/spacing), math.floor(seed[1]/spacing))
            heads.setdefault(key, []).append(index)
        probes = seeds[:40]+[(seed[0]+0.02, seed[1]-0.02, seed[2]) for seed in seeds[-3:]]
        for feet in probes:
            x, y = math.floor(feet[0]/spacing), math.floor(feet[1]/spacing)
            candidates = {index for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                          for index in heads.get(bucket(x+dx, y+dy), ())}
            oracle = {i for i, seed in enumerate(seeds)
                      if abs(feet[2]-seed[2]) < 24. and math.dist(feet[:2], seed[:2]) < spacing}
            result = {i for i in candidates if predicate(near,
                      {'feet': feet, 'data': {'feet': seeds[i]}, 'SEED_FEET': 'feet', 'gSpacing': spacing,
                       'floatabs': abs, 'anpc_distance_2d': lambda a, b: math.dist(a[:2], b[:2])})}
            self.assertEqual(result, oracle)


if __name__ == '__main__':
    unittest.main()
