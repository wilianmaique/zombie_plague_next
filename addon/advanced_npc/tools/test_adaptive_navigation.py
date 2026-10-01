"""Source regression fixtures for posture, local pursuit, BSP seeds and time.

Execute selected installed Pawn functions with independent headroom/support
and binary-file doubles. These tests do not simulate HLDS or compile Pawn.
"""
import io
import math
import re
import shlex
import struct
import unittest

from pawn_test_runtime import PawnRuntime
from test_boundary_routes import PursuitFixture, common, includes


def source(name):
    return (includes()/name).read_text(encoding='utf-8-sig')


def text(value):
    if isinstance(value, str):
        return value
    return ''.join(chr(c) for c in value if c)


def write_text(out, value, limit):
    value = value[:limit]
    out[:len(value)] = [ord(c) for c in value]
    if len(value) < len(out):
        out[len(value)] = 0
    return len(value)


class PostureTests(unittest.TestCase):
    def fixture(self, scout=False):
        fixture = PursuitFixture([], (0., 0., 0.), (200., 0., 0.))
        v, runtime = fixture.values, fixture.runtime
        v.update(gStepSize=18., gTrace=1, gWorker=0, gBot=[99], gTraceLimit=96, gTraces=0,
                 gWalkDuck=[True], gNextPosture=[0.], gPostureChecks=0, gStandRestores=0)
        fixture.ceiling = 100.
        fixture.floor = True
        fixture.checks = []
        runtime.bind('anpc_ground_stride', lambda step: 12.)

        def ground(a, b, duck, step, entity, trace, traces, out):
            fixture.checks.append((bool(duck), tuple(b)))
            out[:] = b[:]
            return fixture.floor and fixture.ceiling >= (36. if duck else 72.)

        runtime.bind('anpc_ground_step', ground)
        runtime.load(source('mapper_motion.inc' if scout else 'movement.inc'),
                     ('scan_walk_posture' if scout else 'npc_walk_posture',))
        return fixture

    def test_scout_stands_again_after_leaving_low_ceiling(self):
        f = self.fixture(True)
        f.ceiling = 48.
        self.assertTrue(f.runtime.call('scan_walk_posture', f.feet, f.target, 10., True))
        f.ceiling = 100.
        self.assertTrue(f.runtime.call('scan_walk_posture', f.feet, f.target, 10.1, True))
        self.assertFalse(f.runtime.call('scan_walk_posture', f.feet, f.target, 10.2, True))
        self.assertEqual(f.values['gStandRestores'], 1)
        self.assertEqual(f.values['gPostureChecks'], 2)
        self.assertEqual(f.checks[-1], (False, (12., 0., 0.)))

    def test_scout_does_not_spend_another_scouts_trace_budget(self):
        f = self.fixture(True)
        f.values['gTraces'] = 84
        self.assertTrue(f.runtime.call('scan_walk_posture', f.feet, f.target, 10., True))
        self.assertEqual(f.checks, [])
        self.assertEqual(f.values['gNextPosture'], [0.])

    def test_both_posture_trials_fit_the_reserved_worst_case_budget(self):
        f = self.fixture(True)
        f.values['gTraces'] = 82

        def probe(a, b, duck, step, entity, trace, traces, out):
            traces.put(traces.get()+7)
            return bool(duck)

        f.runtime.bind('anpc_ground_step', probe, (6,))
        self.assertTrue(f.runtime.call('scan_walk_posture', f.feet, f.target, 10., False))
        self.assertEqual(f.values['gTraces'], 96)

    def test_npc_stands_on_local_clearance_even_when_destination_requires_duck(self):
        f = self.fixture()
        f.values['gActor'][0][f.values['ACT_CROUCHED']] = True
        self.assertFalse(f.runtime.call('npc_walk_posture', 0, f.feet, f.target, 10., True))
        self.assertEqual(f.checks, [(False, (12., 0., 0.))])

    def test_npc_rechecks_headroom_without_crouching_before_the_tunnel(self):
        f = self.fixture()
        self.assertFalse(f.runtime.call('npc_walk_posture', 0, f.feet, f.target, 10., True))
        f.ceiling = 48.
        self.assertTrue(f.runtime.call('npc_walk_posture', 0, f.feet, f.target, 10.2, False))
        f.ceiling = 100.
        self.assertFalse(f.runtime.call('npc_walk_posture', 0, f.feet, f.target, 10.4, True))

    def test_npc_without_crouch_capability_cannot_choose_a_low_passage(self):
        f = self.fixture()
        f.values['gProfile'][0][0] = 0
        f.ceiling = 48.
        self.assertFalse(f.runtime.call('npc_walk_posture', 0, f.feet, f.target, 10., False))
        self.assertEqual(len(f.checks), 1)

    def test_no_supported_stride_does_not_invent_a_posture_certificate(self):
        f = self.fixture()
        f.floor = False
        self.assertTrue(f.runtime.call('npc_walk_posture', 0, f.feet, f.target, 10., True))
        self.assertEqual([check[0] for check in f.checks], [False, True])

    def test_direct_segment_prefers_standing_even_if_actor_started_crouched(self):
        f = PursuitFixture([], (0., 0., 0.), (100., 0., 0.))
        f.values['gActor'][0][f.values['ACT_CROUCHED']] = True
        f.runtime.call('npc_chase_direct', 0, f.feet, f.target, .05, 10., False)
        self.assertEqual([p[2] for p in f.proofs], [False])
        self.assertEqual(f.moves[0][2], 0)

    def test_block_recertifies_standing_instead_of_inheriting_source_posture(self):
        fields = ('X', 'Y', 'LEVEL', 'FEET', 'NORMAL', 'NODE', 'FLAGS',
                  'PHASE', 'SAMPLE', 'CHILD', 'STATUS', 'GEOMETRY', 'SENSITIVE', 'NEXT')
        v, end = {}, 0
        for field in fields:
            span = 3 if field in ('FEET', 'NORMAL') else 1
            v['BL_'+field] = slice(end, end+span) if span > 1 else end
            end += span
        v.update(ScanBlock=end, gKnownFlags=[1, 0], ANPC_NODE_CROUCH=1, gBlock=[],
                 gBlockCount=0, gBlockHead=[-1], gBlockGeometry=1, SCAN_BLOCK_PENDING=0,
                 SCAN_BLOCK_SIZE=[256.], floatround_floor=0)
        r = PawnRuntime(v)
        common(r)
        r.bind('scan_block_hash', lambda *args: 0)

        def push(store, row):
            store.append(row[:])
            return len(store)-1

        r.bind('ArrayPushArray', push)
        r.load(source('mapper_coverage.inc'), ('scan_block_plane_height', 'scan_block_find', 'scan_block_make', 'scan_block_fresh'))
        r.call('scan_block_make', 0, 0, [40., 64., 0.], [0., 0., 1.])
        self.assertEqual(r.call('scan_block_make', 1, 0, [80., 64., 0.], [0., 0., 1.]), 0)
        self.assertEqual(v['gBlockCount'], 1)
        row = v['gBlock'][0]
        self.assertEqual(row[v['BL_FLAGS']], 0)
        row[v['BL_FLAGS']] = 1
        v['gBlockGeometry'] = 2
        r.call('scan_block_fresh', 0)
        self.assertEqual(v['gBlock'][0][v['BL_FLAGS']], 0)


class FreePursuitTests(unittest.TestCase):
    def progress_fixture(self):
        f = PursuitFixture([], (0., 0., 0.), (1400., 0., 0.))
        v, r = f.values, f.runtime
        actor = v['gActor'][0]
        v['MaxClients'] = 32
        for field in ('MOTION_VALID', 'MOTION_STALL', 'MOTION_TIME', 'PROGRESS_DISTANCE',
                      'PROGRESS_TIME', 'RECOVERIES'):
            v['ACT_'+field] = len(actor)
            actor.append(0)
        for field in ('MOTION_ORIGIN', 'PROGRESS_GOAL'):
            v['ACT_'+field] = slice(len(actor), len(actor)+3)
            actor.extend([0., 0., 0.])
        f.states = []
        r.bind('anpc_nav_area_segment', lambda *args: True)
        r.bind('anpc_is_npc', lambda entity: entity == 99)
        r.bind('npc_state', lambda slot, state: f.states.append(state))
        r.bind('npc_reject_target', lambda *args: None)
        r.load(source('movement.inc'), ('npc_progress',))
        return f

    def test_bounded_probe_keeps_slow_walkers_progress_toward_real_destination(self):
        f = self.progress_fixture()
        for tick in range(50):
            f.feet[0] += 1.5  # 30 units/s: real progress, no stationary window.
            now = 10.+tick*.05
            f.runtime.call('npc_chase_direct', 0, f.feet, f.target, .05, now, False)
            f.runtime.call('npc_progress', 0, f.feet, list(f.moves[-1][1]), now, 99)
        self.assertEqual(f.states, [])
        self.assertEqual(f.values['gActor'][0][f.values['ACT_RECOVERIES']], 0)

    def test_local_detour_without_target_approach_still_triggers_recovery(self):
        f = self.progress_fixture()
        for tick in range(100):
            angle = tick*.05*math.pi
            f.feet[:] = [40.*math.sin(angle), 40.*(1.-math.cos(angle)), 0.]
            now = 10.+tick*.05
            f.runtime.call('npc_chase_direct', 0, f.feet, f.target, .05, now, False)
            f.runtime.call('npc_progress', 0, f.feet, list(f.moves[-1][1]), now, 99)
        self.assertIn(f.values['ANPC_RECOVER'], f.states)

    def test_long_covered_destination_uses_a_provable_local_goal(self):
        f = PursuitFixture([], (0., 0., 0.), (1400., 0., 0.))
        f.runtime.bind('anpc_nav_area_segment', lambda *args: True)
        probes = []
        f.runtime.bind('anpc_nav_walkable', lambda a, b, duck, entity:
                       probes.append(tuple(b)) is None and math.dist(a, b) <= 768.)
        f.runtime.bind('npc_can_hit', lambda *args: False)
        f.runtime.bind('npc_state', lambda *args: None)
        f.runtime.bind('anpc_nav_request_to', lambda *args: self.fail('Clear certified area requested graph path'))
        f.runtime.call('npc_hunt', 0, .05, 10.)
        self.assertEqual(probes, [(192., 0., 0.)])
        self.assertEqual(f.moves[0][1], (1400., 0., 0.))
        self.assertEqual(f.cancels, [65])

    def test_local_goal_does_not_cross_a_gap_or_unknown_area(self):
        f = PursuitFixture([], (0., 0., 0.), (1400., 0., 0.))
        out = [0., 0., 0.]
        f.runtime.call('npc_walk_probe', 0, f.feet, f.target, out)
        self.assertEqual(out, f.target)
        f.runtime.bind('anpc_nav_walkable', lambda a, b, duck, entity: math.dist(a, b) <= 768.)
        self.assertFalse(f.runtime.call('npc_chase_direct', 0, f.feet, f.target, .05, 10., False))
        self.assertEqual(f.moves, [])

    def test_local_goal_preserves_ramp_height_and_handles_input_output_alias(self):
        f = PursuitFixture([], (0., 0., 0.), (1200., 0., 600.))
        f.runtime.bind('anpc_nav_area_segment', lambda *args: True)
        f.runtime.call('npc_walk_probe', 0, f.feet, f.target, f.target)
        self.assertAlmostEqual(math.dist(f.feet, f.target), 192.)
        self.assertAlmostEqual(f.target[2]/f.target[0], .5)

    def route(self):
        f = PursuitFixture([(float(x), 0., 0.) for x in (0, 100, 200, 300, 400)],
                           (60., 0., 0.), (1400., 0., 0.))
        f.values['gActor'][0][f.values['ACT_PATH_CURSOR']] = 1
        f.runtime.bind('anpc_nav_area_at', lambda *args: 0)
        f.runtime.bind('anpc_nav_area_segment', lambda *args: True)
        return f

    def test_ordinary_small_radius_nodes_do_not_force_rigid_stops_inside_area(self):
        f = self.route()
        f.runtime.call('npc_follow_route', 0, .05, 10.)
        self.assertEqual(f.values['gActor'][0][f.values['ACT_PATH_CURSOR']], 4)
        self.assertEqual(f.moves[0][1], (400., 0., 0.))

    def test_blocked_farthest_shortcut_retries_nearer_clear_corner(self):
        f = self.route()
        f.runtime.bind('anpc_nav_walkable', lambda a, b, duck, entity: b[0] <= 210.)
        f.runtime.call('npc_follow_route', 0, .05, 10.)
        self.assertEqual(f.values['gActor'][0][f.values['ACT_PATH_CURSOR']], 2)
        self.assertEqual(f.moves[0][1], (200., 0., 0.))

    def test_area_shortcut_cannot_skip_real_jump_takeoff(self):
        f = self.route()
        f.edges[2, 3] = 1
        f.runtime.call('npc_follow_route', 0, .05, 10.)
        self.assertEqual(f.values['gActor'][0][f.values['ACT_PATH_CURSOR']], 2)
        self.assertEqual(f.moves[0][1], (200., 0., 0.))

    def movement(self):
        f = self.route()
        v, r = f.values, f.runtime
        v.update(FL_FLY=1, var_velocity=2, ANPC_ANIM_RUN=1, ANPC_ANIM_IDLE=0)
        v['gActor'][0][v['ACT_JUMP_CURSOR']] = -1
        self.writes, self.jumps = [], []
        r.bind('anpc_nav_status', lambda route: 1)
        r.bind('npc_posture', lambda *args: True)
        r.bind('npc_face', lambda *args: 0.)
        r.bind('npc_animation', lambda *args: None)
        r.bind('set_entvar', lambda *args: self.writes.append(args))
        r.bind('npc_stop_ground', lambda *args: self.fail('Published path stalled for pending search'))
        r.bind('npc_jump', lambda *args: self.jumps.append(args) is None)
        r.load(source('movement.inc'), ('npc_move',))
        return f

    def test_published_jump_can_execute_while_replacement_search_is_pending(self):
        f = self.movement()
        f.runtime.call('npc_move', 0, [300., 0., 50.], 0, 1, [240., 0., 268.], .05, 10.)
        self.assertEqual(len(self.jumps), 1)
        self.assertEqual(self.jumps[0][2:4], (1, [240., 0., 268.]))

    def test_published_ladder_can_climb_while_replacement_search_is_pending(self):
        f = self.movement()
        f.runtime.bind('anpc_nav_ladder', lambda *args: 88)
        f.runtime.call('npc_move', 0, [60., 0., 100.], 2, 0, [0., 0., 0.], .05, 10.)
        self.assertEqual(f.values['gActor'][0][f.values['ACT_LADDER']], 88)
        velocity = next(args[2] for args in self.writes if args[1] == 2)
        self.assertGreater(velocity[2], 0.)


class SupportedMovementTests(unittest.TestCase):
    def fixture(self):
        v = dict(gActor=[[99, 7, False, 1, 0, 0.]], ACT_ENTITY=0, ACT_SERIAL=1,
                 ACT_CROUCHED=2, ACT_STATE=3, ACT_AVOID_SIDE=4, ACT_AVOID_UNTIL=5,
                 ANPC_ATTACK=2, FL_ONGROUND=512, FL_PARTIALGROUND=1024,
                 var_flags=0, gStepSize=18., gTrace=1, degrees=0,
                 EngFunc_WalkMove=1, WALKMOVE_NORMAL=0)
        self.flags, self.walks, self.supported, self.replace = 512, [], True, False
        r = PawnRuntime(v)
        common(r)
        r.bind('npc_live', lambda *args: True)
        r.bind('is_entity', lambda entity: True)
        r.bind('anpc_entity_feet', lambda entity, out: out.__setitem__(slice(None), [240., 64., 96.]))
        r.bind('floatcos', lambda angle, unit: math.cos(math.radians(angle)))
        r.bind('floatsin', lambda angle, unit: math.sin(math.radians(angle)))
        r.bind('get_entvar', lambda entity, field: self.flags)
        r.bind('set_entvar', lambda entity, field, value: setattr(self, 'flags', value))
        r.bind('anpc_ground_stride', lambda step: 12.)
        r.bind('anpc_ground_step', lambda a, b, duck, step, entity, trace, traces, out:
               out.__setitem__(slice(None), b[:]) is None and self.supported)
        r.bind('anpc_ground_floor', lambda *args: self.supported)

        def walk(*args):
            self.walks.append(self.flags)
            if self.replace:
                v['gActor'][0][v['ACT_SERIAL']] = 8
            return bool(self.flags & 1024)

        r.bind('engfunc', walk)
        r.load(source('movement.inc'), ('npc_walk_supported', 'npc_walk_straight', 'npc_steer_local'))
        return r, v

    def test_flat_takeoff_border_can_step_despite_stricter_monster_corner_support(self):
        r, v = self.fixture()
        self.assertTrue(r.call('npc_walk_straight', 0, 0., 8.))
        self.assertEqual(self.walks, [512, 1536])
        self.assertEqual(self.flags, 512)

    def test_no_floor_never_enables_partial_ground_or_attempts_walk(self):
        r, v = self.fixture()
        self.supported = False
        self.assertFalse(r.call('npc_walk_supported', 0, 0., 8.))
        self.assertEqual(self.walks, [])
        self.assertEqual(self.flags, 512)

    def test_entity_replacement_during_walk_does_not_restore_another_entitys_flags(self):
        r, v = self.fixture()
        self.replace = True
        self.assertTrue(r.call('npc_walk_supported', 0, 0., 8.))
        self.assertEqual(self.flags, 1536)

    def test_preexisting_partial_ground_is_not_cleared(self):
        r, v = self.fixture()
        self.flags = 1536
        self.assertTrue(r.call('npc_walk_supported', 0, 0., 8.))
        self.assertEqual(self.flags, 1536)

    def test_local_steering_tries_wider_angles_and_holds_successful_side(self):
        r, v = self.fixture()
        angles = []
        r.bind('npc_safe_sidestep', lambda slot, yaw, distance: angles.append(yaw) is None and yaw == 65.)
        self.assertTrue(r.call('npc_steer_local', 0, 0., 8., 10.))
        self.assertEqual(angles, [30., -30., 65.])
        self.assertEqual(v['gActor'][0][4:], [1, 10.45])

    def test_failed_local_candidates_do_not_change_side_or_claim_progress(self):
        r, v = self.fixture()
        angles = []
        r.bind('npc_safe_sidestep', lambda slot, yaw, distance: angles.append(yaw) is not None)
        self.assertFalse(r.call('npc_steer_local', 0, 0., 8., 10.))
        self.assertEqual(angles, [30., -30., 65., -65., 100., -100.])
        self.assertEqual(v['gActor'][0][4:], [0, 0.])


class BspFixture:
    def __init__(self, leaves=(), version=30, bounds=((-512., -256., -64.), (512., 256., 256.))):
        binary_leaves = b''.join(struct.pack('<ii6h2H4B', contents, -1, *lo, *hi, 0, 0, 0, 0, 0, 0)
                                 for contents, lo, hi in leaves)
        header = bytearray(124)
        struct.pack_into('<i', header, 0, version)
        struct.pack_into('<ii', header, 4+10*8, 124, len(binary_leaves))
        struct.pack_into('<ii', header, 4+14*8, 124+len(binary_leaves), 64)
        self.binary = bytes(header)+binary_leaves+struct.pack('<6f', *bounds[0], *bounds[1])+bytes(40)
        self.stream, self.closed = io.BytesIO(self.binary), []
        v = self.values = dict(gBspSize=len(self.binary), gBoundsMin=[0.]*3, gBoundsMax=[0.]*3,
                  gBspLeafOffset=0, gBspLeafCount=0, gSurveyLeafTotal=0, gSurveyLeafCursor=0,
                  gSurveyFile=0, gSurveyValid=False, gSurveyEnabled=True, gSurveyDone=False,
                  gSurveyTotal=0, gSurveyCursor=0, gSurveySize=[0]*3, gSurveyStep=0., gSpacing=128.,
                  gBspPath='fixture.bsp', BLOCK_INT=4, BLOCK_SHORT=2, SEEK_SET=0, SEEK_CUR=1,
                  CONTENTS_EMPTY=-1, EngFunc_PointContents=1, floatround_ceil=1,
                  gTraceLimit=96, gTraces=0, gLeafSeeds=0)
        r = self.runtime = PawnRuntime(v)
        common(r)
        r.bind('fopen', lambda *args: self.stream.seek(0) is not None)
        r.bind('fclose', lambda handle: self.closed.append(handle))
        r.bind('fseek', lambda handle, offset, origin: 0 if self.stream.seek(offset, origin) >= 0 else 1)

        def read(handle, out, size):
            data = self.stream.read(size)
            if len(data) == size:
                out.put(struct.unpack('<i' if size == 4 else '<h', data)[0])
            return len(data)

        def blocks(handle, out, count, size):
            raw = self.stream.read(count*size)
            complete = len(raw)//size
            # Pawn tags expose model Float cells as Float values; leaf cells
            # expose signed shorts as integers, as the AMXX file native does.
            fmt = 'f' if out is v['gBoundsMin'] or out is v['gBoundsMax'] else 'h'
            out[:complete] = struct.unpack('<'+str(complete)+fmt, raw[:complete*size])
            return complete

        r.bind('fread', read, (1,))
        r.bind('fread_blocks', blocks)
        r.bind('anpc_finite', lambda n, limit: math.isfinite(n) and abs(n) <= limit)
        r.bind('scan_work_available', lambda: True)
        r.load(source('mapper_world.inc'), ('scan_read_bounds', 'scan_init_survey',
                                           'scan_leaf_point', 'scan_leaf_step', 'scan_survey_step'))
        r.call('scan_read_bounds', 'fixture.bsp')
        r.call('scan_init_survey')


class BspSeedTests(unittest.TestCase):
    def test_reads_signed_leaf_coordinates_and_world_dimensions(self):
        f = BspFixture([(-1, (-400, -200, 0), (-200, -100, 128))])
        point = [0.]*3
        self.assertTrue(f.runtime.call('scan_leaf_point', 0, point))
        self.assertEqual(point, [-300., -150., 64.])
        self.assertEqual(f.values['gSurveySize'], [4, 2, 2])
        self.assertEqual(f.values['gSurveyTotal'], 16)

    def test_nonempty_leaves_are_not_navigation_candidates(self):
        for contents in (-2, -3, -4, -5, -6):
            f = BspFixture([(contents, (0, 0, 0), (128, 128, 128))])
            with self.subTest(contents=contents):
                self.assertFalse(f.runtime.call('scan_leaf_point', 0, [0.]*3))

    def test_empty_bounds_are_only_a_seed_after_point_floor_and_hull_proof(self):
        for actual_empty, support, clearance, expected in ((True, True, True, 1),
                (False, True, True, 0), (True, False, True, 0), (True, True, False, 0)):
            f = BspFixture([(-1, (0, 0, 0), (128, 128, 128))])
            seeds = []
            r = f.runtime
            r.bind('engfunc', lambda *args: -1 if actual_empty else -2)
            r.bind('scan_trace_floor', lambda a, up, down, out:
                   out.__setitem__(slice(None), [64., 64., 0.]) is None and support)
            r.bind('scan_snap_floor', lambda feet, flags: clearance, (1,))
            r.bind('scan_block_open_at', lambda *args: -1)
            r.bind('anpc_nav_find_near', lambda *args: -1)
            r.bind('scan_add_seed', lambda feet, flags: seeds.append(feet[:]) is None)
            r.call('scan_leaf_step')
            with self.subTest(empty=actual_empty, support=support, clearance=clearance):
                self.assertEqual(len(seeds), expected)
                self.assertEqual(f.values['gLeafSeeds'], expected)

    def test_leaf_pass_finishes_before_coarse_grid_is_reported_done(self):
        f = BspFixture([(-1, (0, 0, 0), (128, 128, 128))])
        f.values['gSurveyCursor'] = f.values['gSurveyTotal']
        f.runtime.bind('engfunc', lambda *args: -2)
        f.runtime.call('scan_survey_step')
        self.assertEqual(f.values['gSurveyLeafCursor'], 1)
        self.assertFalse(f.values['gSurveyDone'])
        f.runtime.call('scan_survey_step')
        self.assertTrue(f.values['gSurveyDone'])
        self.assertEqual(f.values['gSurveyFile'], 0)

    def test_bad_version_and_outside_or_reversed_leaf_bounds_are_rejected(self):
        f = BspFixture([(-1, (0, 0, 0), (128, 128, 128))], version=29)
        self.assertFalse(f.values['gSurveyValid'])
        for lo, hi in (((1000, 0, 0), (1200, 128, 128)), ((128, 0, 0), (0, 128, 128))):
            f = BspFixture([(-1, lo, hi)])
            self.assertFalse(f.runtime.call('scan_leaf_point', 0, [0.]*3))

    def test_truncated_leaf_read_cannot_emit_a_position(self):
        f = BspFixture([(-1, (0, 0, 0), (128, 128, 128))])
        f.stream = io.BytesIO(f.binary[:124+12])
        self.assertFalse(f.runtime.call('scan_leaf_point', 0, [0.]*3))

    def test_bad_leaf_lump_keeps_valid_world_bounds_and_coarse_survey(self):
        for offset, length in ((-1, 28), (124, 27), (10000, 28), (124, 10000)):
            f = BspFixture([(-1, (0, 0, 0), (128, 128, 128))])
            raw = bytearray(f.binary)
            struct.pack_into('<ii', raw, 4+10*8, offset, length)
            f.stream = io.BytesIO(raw)
            f.values['gBspLeafCount'] = f.values['gBspLeafOffset'] = 0
            f.runtime.call('scan_read_bounds', 'fixture.bsp')
            f.runtime.call('scan_init_survey')
            with self.subTest(offset=offset, length=length):
                self.assertTrue(f.values['gSurveyValid'])
                self.assertEqual(f.values['gSurveyLeafTotal'], 0)
                self.assertEqual(f.values['gSurveyTotal'], 16)
                self.assertFalse(f.values['gSurveyDone'])

    def test_large_world_keeps_leaf_candidates_when_coarse_grid_would_overflow(self):
        f = BspFixture([(-1, (0, 0, 0), (128, 128, 128))],
                       bounds=((-32768., -32768., -32768.), (32768., 32768., 32768.)))
        self.assertEqual(f.values['gSurveyTotal'], 0)
        self.assertFalse(f.values['gSurveyDone'])
        self.assertEqual(f.values['gSurveyLeafTotal'], 1)


class TimingFixture:
    def __init__(self, records=()):
        self.now, self.lines, self.logs = 100., iter(records), []
        v = self.values = dict(gElapsedBase=0., gClockStart=100., gClockRunning=True,
                gActive=True, floatround_floor=0, gLoadPhase=1, gLoadFile=1,
                gLoadNode=0, gLoadSeed=0, gKnownCount=1, gLoadSeedCount=0,
                gLoadTiming=False, gLoadElapsed=0., gSurveyCursor=12, gSurveyTotal=12,
                gSurveyLeafTotal=2, gSurveyLeafCursor=0, gSurveyDone=False,
                gMask=[0], gVisits=[0], gExploreParent=[-1], gParentClosed=[False],
                gSeedRejected=[False], gSenseNode=[-1], gWorker=0, gSeeds=[],
                gSeedHead=[-1]*4, gSeedCount=0, gSeedCursor=0, SCAN_DONE=1023,
                gMemoryLoaded=False)
        r = self.runtime = PawnRuntime(v)
        common(r)
        r.bind('get_gametime', lambda: self.now)
        r.bind('charsmax', lambda out: len(out)-1)
        r.bind('formatex', lambda out, limit, fmt, *args: write_text(out, fmt % args, limit))
        r.bind('log_amx', lambda *args: self.logs.append(args))
        r.bind('fclose', lambda *args: None)
        r.bind('equal', lambda a, b: text(a) == text(b))
        r.bind('str_to_num', lambda value: int(text(value)))
        r.bind('str_to_float', lambda value: float(text(value)))
        r.bind('anpc_number', lambda value, integer: bool(re.fullmatch(r'-?\d+' if integer
                       else r'-?\d+(?:\.\d+)?', text(value))))
        r.bind('scan_collect_seeds', lambda: None)
        r.bind('scan_init_survey', lambda: None)

        def gets(handle, out, limit):
            return write_text(out, next(self.lines, ''), limit)

        def parse(line, *args):
            fields = shlex.split(text(line))
            for i in range(0, len(args), 2):
                write_text(args[i], fields[i//2] if i//2 < len(fields) else '', args[i+1])
            return len(fields)

        r.bind('fgets', gets)
        r.bind('parse', parse)
        r.load(source('mapper_storage.inc'), ('scan_elapsed', 'scan_clock_pause', 'scan_clock_resume',
                         'scan_duration', 'scan_memory_step', 'scan_reject_memory', 'scan_save_failed'))

    def header(self, version=3):
        v, r = self.values, self.runtime
        v.update(gLoadPhase=0, gResetGraph=False, gMemoryPath='fixture.scan', gNavPath='fixture.nav',
                 gMap='fixture', gBspHash='bsp', gNavDigest='nav', gPhysicsDigest='physics',
                 gSpacing=128., gSpeed=250., gGravity=1., gServerGravity=800.,
                 gSurveyStep=256., gSurveyEnabled=True, Hash_Md5=3, ANPC_SCAN_VERSION=3)
        previous = self.lines
        self.lines = iter([f'ANPC_SCAN {version} "fixture" bsp nav 1 128.0 250.0 1.0 800.0 12 0 256.0 1 physics', *previous])
        r.bind('file_exists', lambda path: True)
        r.bind('file_size', lambda path: 512)
        r.bind('hash_file', lambda *args: True)
        r.bind('fopen', lambda *args: 1)


class ScanTimingTests(unittest.TestCase):
    def test_duration_displays_seconds_minutes_and_hours(self):
        f = TimingFixture()
        for seconds, expected in ((0., '0s'), (59.9, '59s'), (60., '1m 00s'),
                (3599., '59m 59s'), (3600., '1h 00m 00s'), (3661., '1h 01m 01s')):
            out = [0]*48
            f.runtime.call('scan_duration', seconds, out, 47)
            self.assertEqual(text(out), expected)

    def test_pause_and_finish_freeze_time_resume_counts_only_active_interval(self):
        f = TimingFixture()
        f.now = 160.
        f.runtime.call('scan_clock_pause')
        f.now = 500.
        self.assertEqual(f.runtime.call('scan_elapsed'), 60.)
        f.runtime.call('scan_clock_resume')
        f.now = 540.
        f.runtime.call('scan_clock_pause')
        f.values['gActive'] = False
        f.now = 1000.
        f.runtime.call('scan_clock_resume')
        self.assertEqual(f.runtime.call('scan_elapsed'), 100.)

    def test_valid_journal_adds_prior_time_once_and_restores_leaf_cursor(self):
        f = TimingFixture(['TIME 3601.5 1', 'N 0 1023 7 -1 1 0', 'END 1 0'])
        f.now = 110.
        self.assertFalse(f.runtime.call('scan_memory_step'))
        self.assertEqual(f.runtime.call('scan_elapsed'), 10.)
        self.assertFalse(f.values['gSurveyDone'])
        self.assertFalse(f.runtime.call('scan_memory_step'))
        self.assertTrue(f.runtime.call('scan_memory_step'))
        self.assertEqual(f.runtime.call('scan_elapsed'), 3611.5)
        self.assertEqual(f.values['gSurveyLeafCursor'], 1)
        self.assertTrue(f.runtime.call('scan_memory_step'))
        self.assertEqual(f.runtime.call('scan_elapsed'), 3611.5)

    def test_current_journal_header_requires_timing_before_nodes(self):
        f = TimingFixture(['TIME 120.0 2', 'N 0 1023 7 -1 1 0', 'END 1 0'])
        f.header()
        self.assertFalse(f.runtime.call('scan_memory_step'))
        self.assertFalse(f.values['gSurveyDone'])
        self.assertFalse(f.runtime.call('scan_memory_step'))
        self.assertTrue(f.values['gSurveyDone'])
        self.assertFalse(f.runtime.call('scan_memory_step'))
        self.assertTrue(f.runtime.call('scan_memory_step'))
        self.assertTrue(f.values['gMemoryLoaded'])
        self.assertEqual(f.values['gElapsedBase'], 120.)

    def test_superseded_journal_is_rejected_without_adding_elapsed(self):
        f = TimingFixture(['TIME 120.0 2', 'N 0 1023 7 -1 1 0', 'END 1 0'])
        f.header(version=2)
        self.assertTrue(f.runtime.call('scan_memory_step'))
        self.assertFalse(f.values['gMemoryLoaded'])
        self.assertEqual(f.values['gElapsedBase'], 0.)

    def test_exact_bsp_and_physics_are_required_for_timing_resume(self):
        for field in ('gBspHash', 'gNavDigest', 'gPhysicsDigest'):
            f = TimingFixture()
            f.header()
            f.values[field] = 'changed'
            with self.subTest(field=field):
                self.assertTrue(f.runtime.call('scan_memory_step'))
                self.assertFalse(f.values['gMemoryLoaded'])
                self.assertEqual(f.values['gElapsedBase'], 0.)

    def test_team_pause_resume_and_paused_checkpoint_preserve_clock_state(self):
        f = TimingFixture()
        v, r = f.values, f.runtime
        v.update(gSessionStage=2, gPauseRequested=False, gDriving=False, gBotCount=2,
                 gResumeStage=[3, 3], gStage=[3, 3], gCurrent=[-1, 0], gIdle=[False, False],
                 gLoadPhase=2, gParentsReady=True, ANPC_SCAN_SELECT=2, ANPC_SCAN_PAUSED=3,
                 ANPC_SCAN_SAVE=6, ANPC_SCAN_SEED=1)
        frozen = []
        r.bind('scan_freeze_team', lambda paused: frozen.append((paused, v['gClockRunning'])))
        r.bind('scan_relocate_current', lambda: None)
        r.load(source('mapper_team.inc'), ('scan_pause_team', 'scan_resume_team', 'scan_thaw_team'))
        f.now = 160.
        r.call('scan_pause_team')
        self.assertEqual(frozen, [(True, False)])
        f.now = 500.
        r.call('scan_thaw_team')
        self.assertFalse(v['gClockRunning'])
        self.assertEqual(r.call('scan_elapsed'), 60.)
        r.call('scan_resume_team')
        f.now = 540.
        self.assertEqual(r.call('scan_elapsed'), 100.)
        self.assertEqual(v['gStage'], [1, 2])

    def test_missing_duplicate_truncated_or_extra_time_never_applies_old_elapsed(self):
        records = (['N 0 1023 0 -1 1 0', 'END 1 0'],
                   ['TIME 120.0 1', 'TIME 120.0 1'],
                   ['TIME 120.0 1', 'N 0 1023 0 -1 1 0'],
                   ['TIME 120.0 1', 'N 0 1023 0 -1 1 0', 'END 1 0', 'TIME 120.0 1'])
        for lines in records:
            f = TimingFixture(lines)
            f.now = 110.
            while not f.runtime.call('scan_memory_step'):
                pass
            with self.subTest(records=lines):
                self.assertFalse(f.values['gMemoryLoaded'])
                self.assertEqual(f.runtime.call('scan_elapsed'), 10.)
                self.assertEqual(f.values['gLoadElapsed'], 0.)
                self.assertEqual(f.values['gSurveyLeafCursor'], 0)

    def test_elapsed_and_leaf_cursor_are_bounded(self):
        for value in ('TIME -1.0 0', 'TIME 31536001.0 0', 'TIME 1.0 -1', 'TIME 1.0 3'):
            f = TimingFixture([value])
            self.assertTrue(f.runtime.call('scan_memory_step'))
            self.assertFalse(f.values['gMemoryLoaded'])
            self.assertEqual(f.values['gElapsedBase'], 0.)

    def test_failed_final_commit_cannot_announce_a_complete_scan(self):
        f = TimingFixture()
        v = f.values
        v.update(gSaveFile=1, gCheckpointInterval=60., gCheckpointTime=0., gStopAfterSave=True, gCompleted=True, gSaved=True)
        finished = []
        f.runtime.bind('scan_finish', lambda *args: finished.append((v['gCompleted'], args)))
        f.runtime.call('scan_save_failed', 'memory commit')
        self.assertEqual(finished, [(False, (True, 'memory commit'))])


if __name__ == '__main__':
    unittest.main()
